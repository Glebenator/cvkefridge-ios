import CVKEFridgeFeatures
import Foundation
import UIKit
@testable import CVKEFridge

/// A `FridgeModel` with its files in a new temporary folder and services that use no system feature. The test then
/// controls the photo service.
@MainActor
struct ModelFixture {
    let folder: URL
    let photos = RecordingPhotoService()
    let model: FridgeModel

    /// - Parameters:
    ///   - changes: The change log at the start.
    ///   - reminders: The reminder service, or nil for a service that does nothing.
    ///   - reminderSettings: The reminder settings at the start, or nil for no file.
    init(changes: [Change], reminders: (any ReminderService)? = nil, reminderSettings: ReminderSettings? = nil) throws {
        try self.init(
            changeLogText: changes.map { ChangeCodec.encode($0) + "\n" }.joined(),
            reminders: reminders,
            reminderSettings: reminderSettings
        )
    }

    /// - Parameter changeLogText: The text of the change log at the start, or nil for no file.
    init(
        changeLogText: String? = nil,
        reminders: (any ReminderService)? = nil,
        reminderSettings: ReminderSettings? = nil
    ) throws {
        folder = FileManager.default.temporaryDirectory.appending(path: "model-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let log = folder.appending(path: "changes.jsonl")
        if let changeLogText {
            try Data(changeLogText.utf8).write(to: log)
        }
        if let reminderSettings {
            try reminderSettings.encode().write(to: folder.appending(path: "reminders.json"))
        }
        model = FridgeModel(
            FridgeModel.Dependencies(
                changeLog: ChangeLogStore(file: log),
                phoneId: PhoneId(file: folder.appending(path: "phone-id")),
                readFoods: { FoodTable(foods: []) },
                readStorageHints: { StorageHints(afterOpening: [], tags: [:]) },
                clock: DayClock(fixed: CalendarDate(year: 2026, month: 5, day: 1)!),
                lookup: NoLookup(),
                reminders: reminders ?? SilentReminders(),
                reminderSettings: JSONFileStore(
                    file: folder.appending(path: "reminders.json"),
                    defaultValue: .defaults,
                    decode: { data in try ReminderSettings.decode(data) },
                    encode: { settings in settings.encode() }
                ),
                recentSettings: JSONFileStore(
                    file: folder.appending(path: "recent.json"),
                    defaultValue: RecentSettings(),
                    decode: { data in try RecentSettings.decode(data) },
                    encode: { settings in try settings.encoded() }
                ),
                photos: photos,
                camera: NoCamera()
            )
        )
    }

    func removeFolder() {
        try? FileManager.default.removeItem(at: folder)
    }
}

/// Waits until the condition is true, for not more than 5 seconds. The result is the last value of the condition.
@MainActor
func eventually(_ condition: @MainActor () async -> Bool) async -> Bool {
    for _ in 0..<500 {
        if await condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
}

/// A photo service that records the calls. `prepare` waits until the test calls `finishPrepare`. After
/// `holdDiscards()`, each `discard` waits until the test calls `releaseDiscards()`.
actor RecordingPhotoService: PhotoService {
    private(set) var cleanCalls: [Set<String>] = []
    private(set) var discarded: [PreparedPhoto] = []
    /// The prepared photos that a product got, by the identifier of the product.
    private(set) var adopted: [String: PreparedPhoto] = [:]
    /// The number of `adopt` calls that failed.
    private(set) var failedAdopts = 0
    /// The number of the next `adopt` calls that fail.
    private var adoptFailures = 0
    private var waiting: [CheckedContinuation<PreparedPhoto, any Error>] = []
    private var prepared = 0
    private var holdsDiscards = false
    private var heldDiscards: [CheckedContinuation<Void, Never>] = []

    /// The number of `prepare` calls that wait.
    var waitingPrepares: Int { waiting.count }
    /// The number of `discard` calls that wait.
    var waitingDiscards: Int { heldDiscards.count }

    /// The next `count` calls of `adopt` fail, as when the photo cannot be written.
    func failAdopts(_ count: Int) {
        adoptFailures = count
    }

    func holdDiscards() {
        holdsDiscards = true
    }

    func releaseDiscards() {
        holdsDiscards = false
        let held = heldDiscards
        heldDiscards = []
        for continuation in held {
            continuation.resume()
        }
    }

    /// Ends the oldest `prepare` that waits, with a new prepared photo.
    @discardableResult
    func finishPrepare() -> PreparedPhoto? {
        guard !waiting.isEmpty else {
            return nil
        }
        prepared += 1
        let photo = PreparedPhoto(fileName: "prepared-\(prepared).jpg")
        waiting.removeFirst().resume(returning: photo)
        return photo
    }

    func start() async -> [String: ProductPhoto] { [:] }

    func setPhoto(productId: String, picture: PictureSource) async throws -> PhotoChange {
        throw CocoaError(.fileWriteUnknown)
    }

    func undo(_ change: PhotoChange, productId: String) async -> ProductPhoto? { nil }

    func removePhoto(productId: String) async throws -> RemovedPhoto? { nil }

    func restore(_ removed: RemovedPhoto) async -> ProductPhoto? { nil }

    func release(_ removed: RemovedPhoto) async {}

    func release(_ change: PhotoChange) async {}

    func prepare(picture: PictureSource) async throws -> PreparedPhoto {
        try await withCheckedThrowingContinuation { continuation in
            waiting.append(continuation)
        }
    }

    func url(of prepared: PreparedPhoto) async -> URL? {
        URL(filePath: "/tmp/\(prepared.fileName)")
    }

    func adopt(productId: String, prepared: PreparedPhoto) async throws -> ProductPhoto {
        if adoptFailures > 0 {
            adoptFailures -= 1
            failedAdopts += 1
            throw CocoaError(.fileWriteOutOfSpace)
        }
        adopted[productId] = prepared
        return ProductPhoto(url: URL(filePath: "/tmp/\(productId).jpg"))
    }

    func discard(_ prepared: PreparedPhoto) async {
        if holdsDiscards {
            await withCheckedContinuation { heldDiscards.append($0) }
        }
        discarded.append(prepared)
    }

    func clean(productIds: Set<String>) async {
        cleanCalls.append(productIds)
    }

    nonisolated func cachedImage(at url: URL, pixelSize: Int) -> UIImage? { nil }

    func image(at url: URL, pixelSize: Int) async -> UIImage? { nil }
}

/// A reminder service that records the plans. After `holdUpdates()`, each `update` waits until the test calls
/// `releaseUpdates()`.
actor RecordingReminders: ReminderService {
    /// The reminders of each `update`, in the order of the calls.
    private(set) var updates: [[PlannedReminder]] = []
    /// The number of `shownDates` calls.
    private(set) var shownCalls = 0
    private var access: NotificationAccess
    private var holdsUpdates = false
    private var heldUpdates: [CheckedContinuation<Void, Never>] = []

    /// The number of `update` calls that wait.
    var waitingUpdates: Int { heldUpdates.count }

    init(access: NotificationAccess = .allowed) {
        self.access = access
    }

    func holdUpdates() {
        holdsUpdates = true
    }

    func releaseUpdates() {
        holdsUpdates = false
        let held = heldUpdates
        heldUpdates = []
        for continuation in held {
            continuation.resume()
        }
    }

    func access() async -> NotificationAccess { access }
    func requestAccess() async -> NotificationAccess { access }

    func shownDates() async -> Set<CalendarDate> {
        shownCalls += 1
        return []
    }

    func update(planned: [PlannedReminder], todayFoods: [ReminderFood], timeZone: TimeZone) async {
        if holdsUpdates {
            await withCheckedContinuation { heldUpdates.append($0) }
        }
        updates.append(planned)
    }

    nonisolated func taps() -> AsyncStream<Void> { AsyncStream { _ in } }
}

private struct NoLookup: ProductLookupService {
    func find(_ barcodes: [String]) async throws(CancellationError) -> ProductLookupAnswer {
        throw CancellationError()
    }
}

private struct SilentReminders: ReminderService {
    func access() async -> NotificationAccess { .ask }
    func requestAccess() async -> NotificationAccess { .ask }
    func update(planned: [PlannedReminder], todayFoods: [ReminderFood], timeZone: TimeZone) async {}
    func taps() -> AsyncStream<Void> { AsyncStream { _ in } }
}

private struct NoCamera: CameraAvailability {
    func access() -> CameraAccess { .noCamera }
    func requestAccess() async -> CameraAccess { .noCamera }
}
