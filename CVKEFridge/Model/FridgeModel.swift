import CVKEFridgeFeatures
import Foundation
import Observation
import UIKit

/// Reads the change log, gives the screens their content, and writes the changes of each action of the person. It is
/// the port of `ui/FridgeViewModel.kt` of the Android app.
///
/// The data goes one way. A screen reads the values of the model and calls a function of the model for each action of
/// the person. A write adds changes to the change log, and then the screens get the replay of the new log. The screens
/// never show a result that is not in the log. No screen keeps a copy of the inventory.
///
/// One model lives as long as the app. It owns each task that it starts: a load, a write, a lookup, and the work on a
/// photo continue when the screen that started them closes. `cancelLookup()` stops a lookup.
///
/// The loads, the writes, the work of the message buttons, and the cleanup of the photos run one at a time, in the
/// order of the calls (`enqueue`). The replay, the content of the screens, and all work with files run off the main
/// actor.
///
/// The model also does the product lookup of the scanner and keeps the photos of the products. Its `ReminderPlanner`
/// keeps the reminder settings and plans the reminders, in a queue of its own: a write of the inventory does not wait
/// for the notification center. The parts that need the system are behind the protocols of `Services.swift`.
@Observable
@MainActor
final class FridgeModel {
    /// The objects that the model uses. A test gives its own.
    struct Dependencies {
        var changeLog: ChangeLogStore
        var phoneId: PhoneId
        /// Reads the table of foods.
        var readFoods: @Sendable () async throws -> FoodTable
        /// Reads the table for the storage hint of a looked-up product.
        var readStorageHints: @Sendable () async throws -> StorageHints
        var clock: DayClock
        var lookup: any ProductLookupService
        var reminders: any ReminderService
        var reminderSettings: JSONFileStore<ReminderSettings>
        var recentSettings: JSONFileStore<RecentSettings>
        var photos: any PhotoService
        var camera: any CameraAvailability
        /// Makes a random identifier for a product, a batch, a storage area, or a change.
        var newId: @Sendable () -> String = NewIdentifier.make
    }

    // MARK: - What the screens read

    /// What the screens show: loading, a failed load, or the inventory.
    private(set) var state: FridgeState = .loading

    /// The message that `NoticeHost` shows, or nil.
    private(set) var notice: Notice?

    /// The state of the write of each form that saves now or has a result that the form did not read, by the token of
    /// the form. Read it with `formWrite(_:)`.
    private(set) var formWrites: [String: FormWrite] = [:]

    /// The state of the product lookup of the scanner.
    private(set) var lookup: LookupState = .idle

    /// The reminder settings.
    var reminders: ReminderState {
        reminderPlanner.reminders
    }

    /// The value that the switch of the reminders shows: the value that the person selected last, also while its
    /// change waits to be written, or else the value of the settings.
    var remindersSwitchOn: Bool {
        reminderPlanner.requestedEnabled ?? reminders.settings?.enabled ?? false
    }

    /// If iOS shows the reminders, or nil before the first answer of the system. `refreshNotificationAccess()` reads
    /// it again, for example when the person comes back from the Settings app. The model knows the access before it
    /// knows the settings: while `reminders` is `.loading`, the access can be nil.
    var notificationAccess: NotificationAccess? {
        reminderPlanner.notificationAccess
    }

    /// The request of a tap on a reminder, or nil.
    private(set) var showRequest: ShowRequest?

    /// The photo of each product that has one, by the identifier of the product.
    private(set) var photos: [String: ProductPhoto] = [:]

    /// The products that get a new photo now. The screen of the food says "Adding the photo…".
    private(set) var photoImports: Set<String> = []

    /// The photo of each add form that has one, by the token of the form.
    private(set) var formPhotos: [String: FormPhoto] = [:]

    /// The products that the person removed from the recent foods of the add form.
    private(set) var recentSettings = RecentSettings()

    /// If the app can use the camera, for the scanner and for "Take a photo".
    @ObservationIgnored let camera: any CameraAvailability

    /// The content of the screens, or nil while the inventory is not loaded.
    var content: FridgeContent? {
        if case .ready(let content) = state {
            return content
        }
        return nil
    }

    /// The date of the device. It changes at midnight and with the time zone, also while the app is open.
    var today: CalendarDate {
        clock.today
    }

    /// The recent foods that an empty name field of the add form shows: not more than five, and not a product that
    /// the person removed from the list.
    var shownRecent: [Product] {
        AddAgain.shown(content?.recent ?? [], settings: recentSettings)
    }

    // MARK: - Private state

    /// What the last read or write gave.
    private struct Loaded {
        var changes: [Change]
        var inventory: Inventory
        var foods: FoodTable
        var foodsAvailable: Bool
        var origin: String
        var skippedChanges: Int
    }

    /// What a write gave.
    private enum WriteResult {
        /// The changes are in the log. `productId` is the product of an `addFood`, also when the action made it.
        /// `removedProducts` has the products that the changes deleted.
        case done(changeIds: [String], message: NoticeMessage?, undoable: Bool, productId: String?, removedProducts: Set<String>)
        case refused(RejectionReason)
        /// The change log could not be written.
        case failed
    }

    /// The work of the button of a message.
    private enum NoticeOperation {
        case undo(changeIds: [String])
        case retry(InventoryAction)
        /// Brings back a removed photo.
        case restorePhoto(RemovedPhoto)
        /// Brings back the photo that a product had before a change of its photo.
        case undoPhotoChange(PhotoChange, productId: String)
        /// Gives the product the prepared photo of the add form again, after it could not get it.
        case retryPhoto(PreparedPhoto, productId: String, name: String)
        case custom(@MainActor () -> Void)
    }

    /// The photo files that the "Undo" of one message needs. They stay until that message closes.
    private enum PhotoProtection {
        /// The photos of the products that the action of the message deleted.
        case products(Set<String>)
        /// The photo that the action of the message removed.
        case removed(RemovedPhoto)
        /// The earlier photo of a product whose photo the action of the message changed.
        case changed(PhotoChange)
        /// The prepared photo of an add form that the saved product could not get. "Try again" needs it.
        case prepared(PreparedPhoto)

        /// True when the protection keeps this prepared photo.
        func protects(_ photo: PreparedPhoto) -> Bool {
            if case .prepared(let protected) = self {
                return protected == photo
            }
            return false
        }
    }

    @ObservationIgnored private let changeLog: ChangeLogStore
    @ObservationIgnored private let phoneId: PhoneId
    @ObservationIgnored private let readFoods: @Sendable () async throws -> FoodTable
    @ObservationIgnored private let readStorageHints: @Sendable () async throws -> StorageHints
    @ObservationIgnored private let clock: DayClock
    @ObservationIgnored private let lookupService: any ProductLookupService
    /// The reminder settings and the plan of the reminders.
    @ObservationIgnored let reminderPlanner: ReminderPlanner
    @ObservationIgnored private let recentStore: JSONFileStore<RecentSettings>
    @ObservationIgnored private let photoService: any PhotoService
    @ObservationIgnored private let newId: @Sendable () -> String

    @ObservationIgnored private var loaded: Loaded?
    /// The table of foods, after the first read that worked.
    @ObservationIgnored private var foods: FoodTable?
    /// The table for the storage hint, after the first read.
    @ObservationIgnored private var storageHints: StorageHints?
    /// The last operation of the queue. See `enqueue`.
    @ObservationIgnored private var queue: Task<Void, Never>?
    @ObservationIgnored private var lookupTask: Task<Void, Never>?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var noticeCount = 0
    @ObservationIgnored private var lookupCount = 0
    @ObservationIgnored private var showCount = 0
    @ObservationIgnored private var noticeOperations: [Int: NoticeOperation] = [:]
    @ObservationIgnored private var photoProtections: [Int: PhotoProtection] = [:]
    /// The number of lines that the model said it did not read. The message comes one time for each number.
    @ObservationIgnored private var announcedSkippedChanges = 0
    /// The photo import that runs for an add form, by the token of the form.
    @ObservationIgnored private var formPhotoImports: [String: FormPhotoImport] = [:]
    /// The number of the newest photo import of an add form.
    @ObservationIgnored private var formPhotoGeneration = 0
    /// The prepared photos of the add forms that a save owns, from the call of `perform` to the end of the save. The
    /// form does not delete them.
    @ObservationIgnored private var photosInSave: Set<PreparedPhoto> = []

    /// A photo import of an add form that did not end.
    private struct FormPhotoImport {
        /// The number of the import. Only the import with the number in `formPhotoImports` can change the form.
        let generation: Int
        /// The work that makes the photo, or nil while the picture loads (`startFormPhoto(token:)`).
        let task: Task<Void, Never>?
        /// The photo that the form had before the import, or nil.
        let earlier: FormPhoto?
    }

    init(_ dependencies: Dependencies) {
        changeLog = dependencies.changeLog
        phoneId = dependencies.phoneId
        readFoods = dependencies.readFoods
        readStorageHints = dependencies.readStorageHints
        clock = dependencies.clock
        lookupService = dependencies.lookup
        reminderPlanner = ReminderPlanner(
            service: dependencies.reminders,
            store: dependencies.reminderSettings,
            clock: dependencies.clock
        )
        recentStore = dependencies.recentSettings
        photoService = dependencies.photos
        camera = dependencies.camera
        newId = dependencies.newId
        reminderPlanner.onMessage = { [weak self] message in
            self?.post(.message(message))
        }
    }

    /// Starts the model: reads the photos, the change log, and the settings, and plans the reminders. The app calls
    /// it one time. A second call does nothing.
    func start() {
        if started {
            return
        }
        started = true
        clock.onChange = { [weak self] in self?.refreshToday() }
        Task {
            photos = await photoService.start()
        }
        Task {
            // A file that cannot be read gives no removed foods. The next remove writes a new file.
            recentSettings = (try? await recentStore.read()) ?? RecentSettings()
        }
        // The model lives as long as the app, and this task with it.
        Task {
            for await _ in reminderPlanner.taps() {
                showAttention()
            }
        }
        reminderPlanner.start()
        load()
    }

    // MARK: - The queue

    /// Runs the operations one at a time, in the order of the calls. An operation can wait for a file or for a
    /// calculation off the main actor, and the next operation then waits for it. So a write always starts from the
    /// result of the write before it.
    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = queue
        queue = Task {
            await previous?.value
            await operation()
        }
    }

    // MARK: - Load

    /// Reads the change log again. The content on the screen stays until the new content replaces it.
    func load() {
        if state == .failed {
            state = .loading
        }
        enqueue { await self.readChangeLog() }
    }

    private func readChangeLog() async {
        do {
            let origin = try await phoneId.get()
            let contents = try await changeLog.read()
            let inventory = await InventoryWork.replay(contents.changes)
            var next = Loaded(
                changes: contents.changes,
                inventory: inventory,
                foods: foods ?? FoodTable(foods: []),
                foodsAvailable: true,
                origin: origin,
                skippedChanges: contents.skippedLines
            )
            if foods == nil {
                // The inventory does not wait for the table of foods. The screens show it first, with an empty table.
                loaded = next
                state = .ready(await content(of: next))
                // A table that cannot be read does not hide the inventory. Only the estimates are missing, and the
                // next load reads the table again.
                foods = try? await readFoods()
                next.foods = foods ?? FoodTable(foods: [])
                next.foodsAvailable = foods != nil
            }
            loaded = next
            state = .ready(await content(of: next))
            reminderPlanner.inventoryChanged(inventory)
            // No message with "Undo" can bring back a product of an earlier log.
            await cleanPhotos()
            if contents.skippedLines != announcedSkippedChanges {
                announcedSkippedChanges = contents.skippedLines
                if contents.skippedLines > 0 {
                    post(.changesNotRead(count: contents.skippedLines))
                }
            }
        } catch {
            // A write must not start from a log that the app could not read.
            loaded = nil
            state = .failed
        }
    }

    /// Calculates the days left again for the date of now, and plans the reminders again. The clock calls it when the
    /// day, the clock, or the time zone changes. The app calls it when its scene becomes active.
    func refreshToday() {
        clock.refresh()
        enqueue {
            if let loaded = self.loaded, self.content?.today != self.clock.today {
                self.state = .ready(await self.content(of: loaded))
            }
        }
        reminderPlanner.requestPlan()
    }

    private func content(of loaded: Loaded) async -> FridgeContent {
        await InventoryWork.content(
            changes: loaded.changes,
            inventory: loaded.inventory,
            foods: loaded.foods,
            foodsAvailable: loaded.foodsAvailable,
            origin: loaded.origin,
            skippedChanges: loaded.skippedChanges,
            today: clock.today
        )
    }

    // MARK: - Actions

    /// Does an action of the person: makes its changes, adds them to the change log, and gives the screens the new
    /// inventory. The write continues when the screen that started it closes.
    ///
    /// A form gives its `formToken`. The result of its write is then in `formWrite(_:)`, and a failed write shows on
    /// the form, not as a message. One token saves one time: while the write of a token runs, and until the form
    /// read its result with `formWriteRead(_:)`, a second call with the token does nothing and returns false. So two
    /// fast taps on "Save" add one batch.
    ///
    /// The result of an action with no token is a message (`notice`): the message of the action with "Undo", or a
    /// failed write with "Try again".
    ///
    /// An edit of a product, of a batch, or of a storage area that changes nothing writes nothing, and it has no
    /// message. An edit that changes a value has a message with "Undo", also when a form saved it.
    ///
    /// - Parameters:
    ///   - formToken: A text that names one form, for example a UUID that the form makes when it opens.
    ///   - photo: The photo of the add form. The product gets it after the write. From this call, the save owns the
    ///     photo file: `discardFormPhoto(token:)` does not delete it while the write runs. When the write fails, the
    ///     form gets the photo back, or the file goes when the form does not show it now.
    /// - Returns: False when the call did nothing, because the form already saves.
    @discardableResult
    func perform(_ action: InventoryAction, formToken: String? = nil, photo: PreparedPhoto? = nil) -> Bool {
        if let formToken {
            switch formWrites[formToken] {
            case .saving, .saved:
                return false
            case .failed, nil:
                formWrites[formToken] = .saving
            }
        }
        if let photo {
            photosInSave.insert(photo)
        }
        enqueue {
            await self.run(action, formToken: formToken, photo: photo)
        }
        return true
    }

    /// Records all of one batch as used or as thrown away: the swipe on a food card, for the batch to use first that
    /// the card shows. The quantity is the quantity of the batch when the write runs.
    ///
    /// A batch that ended before the write runs gets nothing, and there is no message. So two swipes that wait in the
    /// queue end the batch one time, and the second swipe does not take from the next batch.
    func takeWholeBatch(productId: String, batchId: String, outcome: Outcome) {
        enqueue {
            guard let batch = self.loaded?.inventory.batches.first(where: { $0.id == batchId }),
                  batch.productId == productId, batch.isActive
            else {
                return
            }
            let take = InventoryAction.Take(productId: productId, batchIds: [batchId], quantity: batch.quantity, outcome: outcome)
            await self.run(.take(take), formToken: nil, photo: nil)
        }
    }

    /// Writes the action and gives its result: the state of the form, or a message. It runs in the queue.
    private func run(_ action: InventoryAction, formToken: String?, photo: PreparedPhoto?) async {
        let result = await write(action)
        switch result {
        case .done(let changeIds, let message, let undoable, let productId, let removedProducts):
            // A product that is not saved gets no photo.
            var photoAdded = true
            if let photo {
                if let productId {
                    photoAdded = await adopt(photo, productId: productId, formToken: formToken)
                } else {
                    await endSave(of: photo, formToken: formToken)
                }
            }
            if let formToken {
                formWrites[formToken] = .saved
            }
            if let photo, let productId, !photoAdded {
                // The food is in the inventory, and its photo is not. The message says so, and the prepared photo
                // stays for "Try again" until the message closes. It is not replaced by the message of the add.
                let name = loaded?.inventory.products.first(where: { $0.id == productId })?.name ?? ""
                post(
                    .photoNotAdded(name: name),
                    action: .tryAgain,
                    operation: .retryPhoto(photo, productId: productId, name: name),
                    protection: .prepared(photo)
                )
            } else if let message {
                // "Undo" can bring back a product that the action deleted. Its photo stays until then.
                post(
                    .message(message),
                    action: undoable ? .undo : nil,
                    operation: undoable ? .undo(changeIds: changeIds) : nil,
                    protection: undoable && !removedProducts.isEmpty ? .products(removedProducts) : nil
                )
            }
        case .refused(let reason):
            if let photo {
                await endSave(of: photo, formToken: formToken)
            }
            if let formToken {
                formWrites[formToken] = .failed(reason)
            } else {
                post(.message(.refused(reason)))
            }
        case .failed:
            if let photo {
                await endSave(of: photo, formToken: formToken)
            }
            if let formToken {
                formWrites[formToken] = .failed(nil)
            } else {
                post(.message(.saveFailed), action: .tryAgain, operation: .retry(action))
            }
        }
    }

    /// The state of the write of the form with the `token`, or nil when the form does not save and has no result.
    func formWrite(_ token: String) -> FormWrite? {
        formWrites[token]
    }

    /// The form read the result of its write. The token can save again after this call: "Save and add another" uses
    /// one token for each food.
    func formWriteRead(_ token: String) {
        if formWrites[token] != .saving {
            formWrites[token] = nil
        }
    }

    private func write(_ action: InventoryAction) async -> WriteResult {
        guard let current = loaded else {
            return .failed
        }
        if Self.changesNothing(action, in: current.inventory) || !Self.isLater(action, in: current.inventory, today: clock.today) {
            return .done(changeIds: [], message: nil, undoable: false, productId: nil, removedProducts: [])
        }
        let planned: Planned.Changes
        switch InventoryActions.plan(action, inventory: current.inventory, today: clock.today, newId: newId) {
        case .refused(let reason):
            return .refused(reason)
        case .changes(let changes):
            planned = changes
        }
        let added = NewChanges.stamp(
            planned.bodies,
            log: current.changes,
            now: clock.nowMillis(),
            origin: current.origin,
            newId: newId
        )
        let changes = current.changes + added
        // The replay runs before the write. A change that the core rejects does not go into the change log.
        let inventory = await InventoryWork.replay(changes)
        if let reason = NewChanges.rejection(previous: current.inventory, next: inventory) {
            return .refused(reason)
        }
        do {
            try await changeLog.append(added)
        } catch {
            return .failed
        }
        var next = current
        next.changes = changes
        next.inventory = inventory
        loaded = next
        state = .ready(await content(of: next))
        // The plan runs in the queue of the planner. The result of the write does not wait for it.
        reminderPlanner.inventoryChanged(inventory)

        var productId: String?
        if case .addFood(let add) = action {
            productId = add.productId
            for body in planned.bodies where productId == nil {
                if case .productSaved(let product) = body {
                    productId = product.id
                }
            }
        }
        let before = Set(current.inventory.products.map(\.id))
        let removed = before.subtracting(inventory.products.map(\.id))
        return .done(
            changeIds: added.map(\.id),
            message: planned.message,
            undoable: planned.undoable,
            productId: productId,
            removedProducts: removed
        )
    }

    /// True when the action is an edit that gives the values that the inventory already has.
    private static func changesNothing(_ action: InventoryAction, in inventory: Inventory) -> Bool {
        switch action {
        case .saveProduct(let save):
            return inventory.products.contains(save.product)
        case .editBatch(let edit):
            return inventory.batches.contains { batch in
                batch.id == edit.batchId && batch.quantity == edit.quantity && batch.storageAreaId == edit.storageAreaId
                    && batch.dateAdded == edit.dateAdded && batch.expiry == edit.expiry
            }
        case .saveStorageArea(let save):
            return inventory.storageAreas.contains { $0.id == save.id && $0.name == save.name && $0.kind == save.kind }
        default:
            return false
        }
    }

    /// False when the action gives a batch an expiry date that is not later: not after its expiry date, or not
    /// after today. The check uses the date of today when the action runs, so a date that "Still good?" calculated
    /// before midnight is not accepted when it is today after midnight. Such an action changes nothing. Each other
    /// action gives true.
    private static func isLater(_ action: InventoryAction, in inventory: Inventory, today: CalendarDate) -> Bool {
        guard case .moveExpiry(let batchId, let date) = action,
              let batch = inventory.batches.first(where: { $0.id == batchId })
        else {
            return true
        }
        return LaterExpiry.isLater(date, expiry: batch.expiry?.date, today: today)
    }

    // MARK: - Messages

    /// Shows a message that a screen made. `text` is already in the language of the person.
    ///
    /// - Parameters:
    ///   - action: The button of the message, or nil.
    ///   - onAction: The work of the button.
    func showNotice(_ text: String, kind: NoticeKind, action: NoticeAction? = nil, onAction: (@MainActor () -> Void)? = nil) {
        post(.custom(text, kind), action: onAction == nil ? nil : action, operation: onAction.map { .custom($0) })
    }

    /// The person selected the button of the message: "Undo" or "Try again". `NoticeHost` then closes the message
    /// with `noticeShown(_:)`.
    func noticeAction(_ notice: Notice) {
        guard let operation = noticeOperations.removeValue(forKey: notice.id) else {
            return
        }
        switch operation {
        case .undo(let changeIds):
            perform(.undo(changeIds: changeIds))
        case .retry(let action):
            perform(action)
        case .restorePhoto(let removed):
            enqueue {
                self.photos[removed.productId] = await self.photoService.restore(removed)
            }
        case .undoPhotoChange(let change, let productId):
            enqueue {
                self.photos[productId] = await self.photoService.undo(change, productId: productId)
            }
        case .retryPhoto(let photo, let productId, let name):
            // This runs before the close of the message, which is in the queue after it.
            enqueue {
                do {
                    self.photos[productId] = try await self.photoService.adopt(productId: productId, prepared: photo)
                } catch {
                    // The new message keeps the prepared photo for its own "Try again".
                    self.post(
                        .photoNotAdded(name: name),
                        action: .tryAgain,
                        operation: .retryPhoto(photo, productId: productId, name: name),
                        protection: .prepared(photo)
                    )
                }
            }
        case .custom(let work):
            work()
        }
    }

    /// `NoticeHost` closed the message. After that, its "Undo" cannot bring back a deleted product or a removed
    /// photo, so the photo files that no product and no other message needs go.
    func noticeShown(_ id: Int) {
        if notice?.id == id {
            notice = nil
        }
        close(id)
    }

    /// True when the message has work for its button. A message that a newer message replaced has none.
    func canPerformAction(of notice: Notice) -> Bool {
        noticeOperations[notice.id] != nil
    }

    private func post(
        _ text: NoticeText,
        action: NoticeAction? = nil,
        operation: NoticeOperation? = nil,
        protection: PhotoProtection? = nil
    ) {
        // A new message replaces the message on the screen. The button of that message is then gone.
        if let old = notice {
            close(old.id)
        }
        noticeCount += 1
        let id = noticeCount
        if let operation {
            noticeOperations[id] = operation
        }
        if let protection {
            photoProtections[id] = protection
        }
        notice = Notice(id: id, text: text, action: operation == nil ? nil : action)
    }

    /// Ends the "Undo" of the message, and deletes the photo files that nothing needs now. The work is in the queue,
    /// so the work of the button of the message runs first. Only the photo files of this message lose their
    /// protection: the files of a message that is still on the screen stay.
    private func close(_ id: Int) {
        noticeOperations[id] = nil
        enqueue {
            guard let protection = self.photoProtections.removeValue(forKey: id) else {
                return
            }
            switch protection {
            case .products:
                break
            case .removed(let removed):
                await self.photoService.release(removed)
            case .changed(let change):
                await self.photoService.release(change)
            case .prepared(let photo):
                // A newer message for the same photo still needs it. After a "Try again" that worked, the file of the
                // prepared photo is already gone, and the delete does nothing.
                if !self.photoProtections.values.contains(where: { $0.protects(photo) }) {
                    await self.photoService.discard(photo)
                }
            }
            await self.cleanPhotos()
        }
    }

    // MARK: - Photos

    /// Makes the photo of the product from the picture, off the main actor, and replaces the photo that the product
    /// had. A picture that cannot be read gives a message, and the photo of the product stays. A change of a photo
    /// gives a message with "Undo", which brings the earlier photo back.
    func setPhoto(productId: String, picture: PictureSource) {
        photoImports.insert(productId)
        Task {
            do {
                let change = try await photoService.setPhoto(productId: productId, picture: picture)
                photos[productId] = change.photo
                if change.earlier != nil {
                    // The Android app has no "Undo" for "Change photo".
                    post(
                        .message(.photoChanged),
                        action: .undo,
                        operation: .undoPhotoChange(change, productId: productId),
                        protection: .changed(change)
                    )
                }
            } catch {
                post(.message(.photoFailed))
            }
            photoImports.remove(productId)
        }
    }

    /// Removes the photo of the product. The message has "Undo".
    func removePhoto(productId: String) {
        Task {
            do {
                guard let removed = try await photoService.removePhoto(productId: productId) else {
                    return
                }
                photos[productId] = nil
                post(
                    .message(.photoRemoved),
                    action: .undo,
                    operation: .restorePhoto(removed),
                    protection: .removed(removed)
                )
            } catch {
                post(.message(.photoNotRemoved))
            }
        }
    }

    /// Makes the photo of the add form with the `token` from the picture, off the main actor. The product does not
    /// exist yet: give `formPhoto(_:)` to `perform`, and the product gets the photo after the save. A picture that
    /// cannot be read gives a message, and the form keeps the photo that it had.
    ///
    /// Each call starts a new import for the token. An import that a newer call or `discardFormPhoto(token:)`
    /// replaced does not change the form when it ends: it deletes its prepared file, and it shows no message.
    func makeFormPhoto(token: String, picture: PictureSource) {
        makeFormPhoto(token: token, load: startFormPhoto(token: token), picture: picture)
    }

    /// The person selected or took a picture for the add form with the `token`, and its bytes load now, for example
    /// from iCloud. From this call, the photo of the form is `making`: "Save" is off, and the form says why. Give the
    /// result to `makeFormPhoto(token:load:picture:)` when the bytes are there.
    ///
    /// A newer call, a newer import, or `discardFormPhoto(token:)` replaces the load. For example, "Save and add
    /// another" discards the photo of the saved food. The picture of a replaced load then does nothing, so it never
    /// goes to the next food of the form.
    func startFormPhoto(token: String) -> FormPhotoLoad {
        // The photo that the form shows when this import fails. A newer import keeps the photo of the import before
        // it, because the photo of the form while an import runs is `making`.
        let earlier: FormPhoto?
        if let running = formPhotoImports.removeValue(forKey: token) {
            running.task?.cancel()
            earlier = running.earlier
        } else {
            earlier = formPhotos[token]
        }
        formPhotoGeneration += 1
        formPhotos[token] = .making
        formPhotoImports[token] = FormPhotoImport(generation: formPhotoGeneration, task: nil, earlier: earlier)
        return FormPhotoLoad(generation: formPhotoGeneration)
    }

    /// Makes the photo of the add form from the picture of a load that `startFormPhoto(token:)` started. The picture
    /// of a load that was replaced does nothing.
    func makeFormPhoto(token: String, load: FormPhotoLoad, picture: PictureSource) {
        guard let running = formPhotoImports[token], running.generation == load.generation, running.task == nil else {
            return
        }
        let generation = load.generation
        let earlier = running.earlier
        let task = Task {
            let prepared: PreparedPhoto
            do {
                prepared = try await photoService.prepare(picture: picture)
            } catch {
                guard formPhotoImports[token]?.generation == generation else {
                    return
                }
                formPhotoImports[token] = nil
                formPhotos[token] = earlier
                post(.message(.photoFailed))
                return
            }
            let url = await photoService.url(of: prepared)
            guard formPhotoImports[token]?.generation == generation else {
                // The form discarded this import, or a newer import replaced it. No form shows this file.
                await photoService.discard(prepared)
                return
            }
            // The form shows the new photo before the earlier photo goes. There is no wait between the check above
            // and this change, so a form that closes while the earlier photo goes finds the new photo and deletes it.
            formPhotoImports[token] = nil
            formPhotos[token] = .ready(prepared, url: url)
            // A save that owns the earlier photo decides about its file.
            if case .ready(let old, _) = earlier, !photosInSave.contains(old) {
                await photoService.discard(old)
            }
        }
        formPhotoImports[token] = FormPhotoImport(generation: generation, task: task, earlier: earlier)
    }

    /// The photo of the add form with the `token` that is ready, or nil.
    func formPhoto(_ token: String) -> PreparedPhoto? {
        if case .ready(let photo, _) = formPhotos[token] {
            return photo
        }
        return nil
    }

    /// Deletes the photo of the add form with the `token`: the person removed it, or the form closed with no save.
    ///
    /// An import that runs for the form stops. When it ends, it deletes its prepared file. A picture that loads for
    /// the form does nothing when it arrives. The photo of a save that runs stays: the save owns its file.
    func discardFormPhoto(token: String) {
        var discarded: [PreparedPhoto] = []
        if let running = formPhotoImports.removeValue(forKey: token) {
            running.task?.cancel()
            // The photo before the import is not on the form now, and no later import gets it.
            if case .ready(let photo, _) = running.earlier {
                discarded.append(photo)
            }
        }
        if case .ready(let photo, _) = formPhotos.removeValue(forKey: token) {
            discarded.append(photo)
        }
        discarded.removeAll { photosInSave.contains($0) }
        guard !discarded.isEmpty else {
            return
        }
        Task {
            for photo in discarded {
                await photoService.discard(photo)
            }
        }
    }

    /// The picture of a photo file that is ready in memory for a box of `pixelSize` pixels, or nil.
    func cachedImage(of photo: ProductPhoto, pixelSize: Int) -> UIImage? {
        photoService.cachedImage(at: photo.url, pixelSize: pixelSize)
    }

    /// Decodes the picture of a photo file for a box of `pixelSize` pixels, off the main actor. Nil when the file
    /// cannot be decoded.
    func image(of photo: ProductPhoto, pixelSize: Int) async -> UIImage? {
        await photoService.image(at: photo.url, pixelSize: pixelSize)
    }

    /// Gives the photo of the add form to the product that the form saved. After the call, the form does not show
    /// the photo. The result is false when the product could not get the photo: the prepared file then stays, and the
    /// caller keeps it for "Try again".
    private func adopt(_ photo: PreparedPhoto, productId: String, formToken: String?) async -> Bool {
        var adopted = true
        do {
            photos[productId] = try await photoService.adopt(productId: productId, prepared: photo)
        } catch {
            adopted = false
        }
        photosInSave.remove(photo)
        if let formToken, formPhoto(formToken) == photo {
            formPhotos[formToken] = nil
        }
        return adopted
    }

    /// The save of a photo ended, and no product got the photo. The form keeps the photo for its next "Save". When
    /// the form does not have the photo now (it closed, or it got a different photo), the file goes.
    private func endSave(of photo: PreparedPhoto, formToken: String?) async {
        photosInSave.remove(photo)
        if let formToken, formHas(photo, token: formToken) {
            return
        }
        await photoService.discard(photo)
    }

    /// True when the add form shows the photo, or shows it again when the import that runs fails.
    private func formHas(_ photo: PreparedPhoto, token: String) -> Bool {
        if formPhoto(token) == photo {
            return true
        }
        if case .ready(let earlier, _) = formPhotoImports[token]?.earlier {
            return earlier == photo
        }
        return false
    }

    /// Deletes the photos of the products that are not in the inventory, and the files that no photo needs. The
    /// photos of the products that the "Undo" of a message on the screen can bring back stay: the cleanup reads the
    /// protections when it runs. The photo service keeps the removed and the changed photos until their release.
    ///
    /// When the model did not read some lines of the change log, the cleanup deletes nothing. A line that the app did
    /// not read can have a product, and a later version of the app can read the line. The photo of that product
    /// must stay until then.
    private func cleanPhotos() async {
        guard let loaded, loaded.skippedChanges == 0 else {
            return
        }
        let inventory = loaded.inventory
        var productIds = Set(inventory.products.map(\.id))
        for case .products(let deleted) in photoProtections.values {
            productIds.formUnion(deleted)
        }
        await photoService.clean(productIds: productIds)
        photos = photos.filter { productIds.contains($0.key) }
    }

    // MARK: - Recent foods

    /// Removes the product from the recent foods of the add form, until the person adds, uses, or throws away some of
    /// it again. The settings keep the identifier of the newest change of the food, not a time, so a change of the
    /// clock has no effect.
    func hideRecent(productId: String) {
        guard let food = content?.recent.first(where: { $0.product.id == productId }) else {
            return
        }
        let settings = recentSettings.hiding(food, now: clock.nowMillis())
        recentSettings = settings
        Task {
            do {
                try await recentStore.write(settings)
            } catch {
                post(.message(.settingsNotSaved))
            }
        }
    }

    // MARK: - The product lookup

    /// Finds the product of a scanned or typed barcode, in the form of `Barcodes`. A product in the inventory with
    /// the barcode comes first, with no network. Then the product lookup: the cache on the phone, and then Open Food
    /// Facts. A new lookup replaces a lookup that runs.
    ///
    /// - Parameter otherForms: The other barcodes that a typed text can be (`Barcodes.typedCandidates`, without its
    ///   first value). The inventory and the cache are tried with each of them before the network gets the `barcode`.
    func lookUp(_ barcode: String, otherForms: [String] = []) {
        lookupTask?.cancel()
        lookupCount += 1
        let id = lookupCount
        lookup = .looking(barcode: barcode)
        lookupTask = Task {
            let forms = [barcode] + otherForms.filter { $0 != barcode }
            let products = content?.inventory.products ?? []
            for form in forms {
                if let known = ScannedFoods.productWithBarcode(products, barcode: form) {
                    // The storage text of the product gives the storage hint, as for a scan that the lookup found.
                    var kind: StorageKind?
                    if let text = known.storageText {
                        kind = await hints().kindOfStorageText(text)
                    }
                    finishLookup(id, .done(
                        id: id,
                        scanned: Scanned(barcode: form, source: .inInventory, storageKind: kind),
                        productId: known.id
                    ))
                    return
                }
            }
            guard let answer = try? await lookupService.find(forms) else {
                // The task was cancelled. A newer lookup or `cancelLookup()` set the state.
                return
            }
            switch answer.result {
            case .found(let product):
                // The table of foods of the newest state, for the expiry estimate.
                let foods = content?.foods ?? FoodTable(foods: [])
                let scanned = await InventoryWork.scanned(
                    barcode: answer.barcode,
                    product: product,
                    foods: foods,
                    hints: await hints()
                )
                finishLookup(id, .done(id: id, scanned: scanned, productId: nil))
            case .notFound:
                finishLookup(id, .done(id: id, scanned: Scanned(barcode: answer.barcode, source: .notFound), productId: nil))
            case .failed(let failure):
                finishLookup(id, .failed(barcode: barcode, failure: failure))
            }
        }
    }

    /// Stops the lookup that runs, and forgets its result. The scanner calls it when it closes.
    func cancelLookup() {
        lookupTask?.cancel()
        lookupTask = nil
        lookupCount += 1
        lookup = .idle
    }

    /// The scanner opened the add form for the result `id`.
    func lookupShown(_ id: Int) {
        if case .done(id, _, _) = lookup {
            lookup = .idle
        }
    }

    /// Sets the result of the lookup `id`, when no newer lookup started and nothing cancelled it.
    private func finishLookup(_ id: Int, _ result: LookupState) {
        if id == lookupCount, !Task.isCancelled {
            lookup = result
        }
    }

    /// The table for the storage hint. The storage hint is not necessary for the add form: when the table cannot be
    /// read, the scan has no storage hint.
    private func hints() async -> StorageHints {
        if let storageHints {
            return storageHints
        }
        let table = (try? await readStorageHints()) ?? StorageHints(afterOpening: [], tags: [:])
        storageHints = table
        return table
    }

    // MARK: - Reminders

    /// Turns reminders on or off. `fromOffer` is true for the offer on Home, which then says that reminders are on.
    /// Before the first "on", explain the notifications to the person and call `requestNotificationAccess()`.
    func setRemindersOn(_ on: Bool, fromOffer: Bool = false) {
        reminderPlanner.setEnabled(on) {
            if on && fromOffer {
                self.post(.message(.remindersOn))
            }
        }
    }

    /// Changes the time of the reminder, in minutes after midnight on the clock of the device, from 0 to 1439.
    func setReminderTime(minuteOfDay: Int) {
        guard (0..<ReminderSettings.minutesInDay).contains(minuteOfDay) else {
            return
        }
        reminderPlanner.update { $0.minuteOfDay = minuteOfDay }
    }

    /// Changes the lead time: the days before the expiry date from which a batch is in the reminder.
    func setReminderLeadDays(_ days: Int) {
        guard ReminderRules.leadDayChoices.contains(days) else {
            return
        }
        reminderPlanner.update { $0.leadDays = days }
    }

    /// Home does not offer reminders again, and a message says where the switch is.
    func dismissReminderOffer() {
        reminderPlanner.update { $0.offerDismissed = true } then: {
            self.post(.message(.remindersInSettings))
        }
    }

    /// Asks iOS for the notification permission, and records that the app asked. iOS shows its question only the
    /// first time. Explain the reminders to the person before this call. The result is the access after the answer.
    func requestNotificationAccess() async -> NotificationAccess {
        await reminderPlanner.requestAccess()
    }

    /// Reads again if iOS shows the reminders. Call it when the person comes back from the Settings app.
    func refreshNotificationAccess() {
        reminderPlanner.refreshAccess()
    }

    /// Reads again if iOS shows the reminders, and gives the access. iOS does not ask the person.
    func readNotificationAccess() async -> NotificationAccess {
        await reminderPlanner.readAccess()
    }

    /// A tap on the reminder: My Fridge with the food that is expiring or expired.
    func showAttention() {
        showCount += 1
        showRequest = ShowRequest(id: showCount, freshness: [.expiring, .expired])
    }

    /// `RootView` showed the request with this identifier.
    func showRequestDone(_ id: Int) {
        if showRequest?.id == id {
            showRequest = nil
        }
    }
}
