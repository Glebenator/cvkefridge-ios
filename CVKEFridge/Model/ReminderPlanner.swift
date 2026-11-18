import CVKEFridgeFeatures
import Foundation
import Observation

/// The reminder settings, the notification access, and the plan of the reminders. `FridgeModel` owns one planner and
/// gives it the inventory after each change. The screens read the values through the model.
///
/// The planner has its own queue, separate from the queue of the inventory. The reads and the changes of the settings
/// and the plans run in it one at a time, in the order of the calls. So a change of a setting does not wait for a load
/// of the inventory, and a write of the inventory does not wait for the notification center.
///
/// A plan is "latest wins": many changes of the inventory in a short time give one plan, with the newest inventory.
/// A plan that runs stops before it changes the notifications when a newer change came: the next plan in the queue
/// does the work. The plan after the last change always runs.
///
/// With reminders off, a plan does not use the notification center when the last plan already removed all reminders.
@Observable
@MainActor
final class ReminderPlanner {
    /// The reminder settings.
    private(set) var reminders: ReminderState = .loading

    /// If iOS shows the reminders, or nil before the first answer of the system.
    private(set) var notificationAccess: NotificationAccess?

    /// Shows a message of the settings, for example when the file cannot be written. The model sets it.
    @ObservationIgnored var onMessage: (@MainActor (NoticeMessage) -> Void)?

    @ObservationIgnored private let service: any ReminderService
    @ObservationIgnored private let store: JSONFileStore<ReminderSettings>
    @ObservationIgnored private let clock: DayClock

    /// The newest inventory, or nil before the first load.
    @ObservationIgnored private var inventory: Inventory?
    /// The last operation of the queue. See `enqueue`.
    @ObservationIgnored private var queue: Task<Void, Never>?
    @ObservationIgnored private var started = false
    /// True while a plan waits in the queue and did not start. A new request then needs no other plan.
    @ObservationIgnored private var planWaits = false
    /// The number of plan requests. A plan that runs stops when this number changes: a newer plan follows it.
    @ObservationIgnored private var planRequests = 0
    /// True when the last plan had reminders off and removed all reminders and the reminder of today. A plan with
    /// reminders off then has nothing to do with the notification center.
    @ObservationIgnored private var nothingPlanned = false

    init(service: any ReminderService, store: JSONFileStore<ReminderSettings>, clock: DayClock) {
        self.service = service
        self.store = store
        self.clock = clock
    }

    /// Reads the notification access and the settings. The model calls it one time, at its start. A second call
    /// does nothing.
    func start() {
        if started {
            return
        }
        started = true
        enqueue {
            do {
                self.reminders = .ready(try await self.store.read())
            } catch {
                self.reminders = .unreadable
            }
            self.notificationAccess = await self.service.access()
        }
    }

    /// One value for each tap of the person on a reminder. See `ReminderService.taps()`.
    func taps() -> AsyncStream<Void> {
        service.taps()
    }

    // MARK: - The plan

    /// The inventory changed. The planner plans the reminders again, after the operations that wait in its queue.
    func inventoryChanged(_ inventory: Inventory) {
        self.inventory = inventory
        requestPlan()
    }

    /// Plans the reminders again: after a change of the day, the clock, or the time zone.
    func requestPlan() {
        planRequests += 1
        if planWaits {
            // The plan in the queue reads the newest values when it starts.
            return
        }
        planWaits = true
        enqueue {
            self.planWaits = false
            await self.plan()
        }
    }

    /// Plans the reminders of the next days again, for the newest inventory and settings.
    ///
    /// Settings that are not read change nothing: the reminders that are planned stay. The Android app reads such
    /// settings as "off" and removes its alarm.
    ///
    /// The reminder of a date comes one time only, also when the person then selects a later time. Only a reminder
    /// that iOS showed makes its date the last date (`ReminderPlan.lastDate`): a time of the settings that passed is
    /// not evidence, because the person can change the time after the plan.
    private func plan() async {
        guard var settings = reminders.settings, let inventory else {
            return
        }
        if !settings.enabled, nothingPlanned, settings.nextDate == nil {
            // Reminders are off, and the system has no reminder of the app.
            return
        }
        let request = planRequests
        let before = settings
        let now = clock.now()
        let zone = clock.timeZone()
        let today = ReminderSchedule.dateOf(now, timeZone: zone)
        let shown = await service.shownDates()
        if planRequests != request {
            // A newer change came while the system answered. The plan after it is in the queue.
            return
        }
        settings.lastDate = ReminderPlan.lastDate(settings, shown: shown, now: now, timeZone: zone)?.text
        let planned = ReminderPlan.reminders(inventory: inventory, settings: settings, now: now, timeZone: zone)
        settings.nextDate = planned.first?.date.text
        let foods = settings.enabled ? ReminderRules.foods(inventory, today: today, leadDays: settings.leadDays) : []
        await service.update(planned: planned, todayFoods: foods, timeZone: zone)
        nothingPlanned = !settings.enabled && planned.isEmpty && foods.isEmpty
        if settings != before {
            // A file that cannot be written leaves the old dates. The next plan calculates them again.
            try? await store.write(settings)
            reminders = .ready(settings)
        }
    }

    // MARK: - The settings

    /// Changes the settings, writes them, and plans the reminders again. Then `then` runs. A file that cannot be
    /// written gives the message `settingsNotSaved`, the settings stay as they were, and `then` does not run. When the
    /// file of the settings could not be read, the change starts from the default settings: the person then selects
    /// the values again.
    func update(
        _ change: @escaping @MainActor (inout ReminderSettings) -> Void,
        then: (@MainActor () -> Void)? = nil
    ) {
        enqueue {
            var settings = self.reminders.settings ?? .defaults
            let before = settings
            change(&settings)
            if settings != before || self.reminders.settings == nil {
                do {
                    try await self.store.write(settings)
                } catch {
                    self.onMessage?(.settingsNotSaved)
                    return
                }
                self.reminders = .ready(settings)
                self.requestPlan()
            }
            then?()
        }
    }

    // MARK: - The notification access

    /// Asks iOS for the notification permission, and records that the app asked. iOS shows its question only the
    /// first time. The result is the access after the answer.
    func requestAccess() async -> NotificationAccess {
        let access = await service.requestAccess()
        notificationAccess = access
        update { $0.permissionAsked = true }
        return access
    }

    /// Reads again if iOS shows the reminders.
    func refreshAccess() {
        Task {
            notificationAccess = await service.access()
        }
    }

    // MARK: - The queue

    /// Runs the operations one at a time, in the order of the calls.
    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = queue
        queue = Task {
            await previous?.value
            await operation()
        }
    }
}
