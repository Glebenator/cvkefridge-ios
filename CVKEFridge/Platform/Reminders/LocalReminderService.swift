import CVKEFridgeFeatures
import Foundation
import Synchronization
import UserNotifications

/// The reminders as local notifications of iOS, with calendar triggers. The Android app sets an alarm, and its code
/// reads the inventory at the time of the alarm. iOS does not start the code of the app at a time, so each reminder
/// is planned ahead with its text (`ReminderPlan`).
///
/// - Planned reminders: one notification request for each `PlannedReminder`, with the identifier of its date
///   (`reminder-2026-11-14`) and a calendar trigger at the full date and time of `triggerComponents(timeZone:calendar:)`.
///   The trigger has no time zone, so after a travel with the app closed the reminder comes at its time on the new
///   clock. Each update replaces the requests that changed, and removes the requests that are not in the plan.
/// - Shown reminders: iOS cannot run the code of the app when a reminder comes, so the update also cleans the
///   Notification Center. It keeps only the reminder of today. When the food of today changed, for example because the
///   person used a food after the reminder came, the reminder gets the new text with no sound. When no food needs
///   attention, the reminder goes. So an older reminder stays in the Notification Center only until the app opens.
/// - The content: the title "3 items need attention", and the text "Chicken thighs, Baby spinach and 1 more" with one
///   line for each food below it. On a locked screen with hidden previews, iOS shows only the number of foods
///   (`hiddenPreviewsBodyPlaceholder` of the category of each number). The notification has no actions and no badge:
///   a badge stays on the icon after the food changed, until the app opens.
/// - A tap on a reminder opens the app, and `taps()` gives the tap to the model. The tap that starts the app also
///   arrives, because the service connects to the notification center before the app completes its start.
///
/// The notification has no data that leaves the phone: the system shows it on this device. The service writes no
/// names of food to a log.
final class LocalReminderService: NSObject, ReminderService, UNUserNotificationCenterDelegate, @unchecked Sendable {
    // The stored values are constants, and each is safe to use from more than one thread.

    /// The thread of all reminders. The Notification Center shows them in one stack.
    private static let thread = "expiry-reminders"
    /// The start of the identifier of the category of a reminder. The rest is the number of foods.
    private static let categoryPrefix = "expiry-reminder-"
    /// The key in `userInfo` of a reminder that gets a new text: iOS shows it with no banner and no sound.
    private static let quietKey = "quiet"
    /// The identifier of the test reminder of the debug build.
    static let testIdentifier = "test-reminder"

    private let center: UNUserNotificationCenter
    private let tapStream: AsyncStream<Void>
    private let tapContinuation: AsyncStream<Void>.Continuation
    /// The dates of the reminders that came or that the person selected while the app ran.
    private let seen = Mutex<Set<CalendarDate>>([])

    /// Makes the service and connects it to the notification center. Make it before the app completes its start, so
    /// that the tap that started the app arrives.
    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        (tapStream, tapContinuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        super.init()
        center.delegate = self
    }

    // MARK: Access

    func access() async -> NotificationAccess {
        let settings = await center.notificationSettings()
        let authorization: NotificationAuthorization
        switch settings.authorizationStatus {
        case .notDetermined: authorization = .notDetermined
        case .denied: authorization = .denied
        case .authorized: authorization = .authorized
        case .provisional: authorization = .provisional
        case .ephemeral: authorization = .ephemeral
        @unknown default: authorization = .denied
        }
        let shown = [settings.lockScreenSetting, settings.notificationCenterSetting, settings.alertSetting]
            .contains(.enabled)
        return NotificationAccess.of(authorization: authorization, shownSomewhere: shown)
    }

    /// Asks for alerts and sounds. The app does not ask for a badge, and it does not use the provisional permission:
    /// the person decides one time, after the explanation of the app.
    func requestAccess() async -> NotificationAccess {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        return await access()
    }

    // MARK: The plan

    func update(planned: [PlannedReminder], todayFoods: [ReminderFood], timeZone: TimeZone) async {
        await replacePending(with: planned, timeZone: timeZone)
        await cleanDelivered(todayFoods: todayFoods, today: ReminderSchedule.dateOf(Date(), timeZone: timeZone))
        await Self.registerCategories(center)
    }

    /// Replaces the planned requests with the requests of the `planned` reminders. A request that has the same
    /// identifier, text, and trigger stays, so a plan that did not change gives no work to the system.
    private func replacePending(with planned: [PlannedReminder], timeZone: TimeZone) async {
        let requests = planned.map { reminder in
            UNNotificationRequest(
                identifier: reminder.identifier,
                content: Self.content(reminder.message, quiet: false),
                // The trigger has no time zone: iOS reads it on the clock of the device at each moment.
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: reminder.triggerComponents(timeZone: timeZone, calendar: .current),
                    repeats: false
                )
            )
        }
        let pending = await center.pendingNotificationRequests().filter {
            PlannedReminder.date(ofIdentifier: $0.identifier) != nil
        }
        var kept = Set<String>()
        var removed: [String] = []
        for request in pending {
            if let next = requests.first(where: { $0.identifier == request.identifier }), Self.same(request, next) {
                kept.insert(request.identifier)
            } else {
                removed.append(request.identifier)
            }
        }
        center.removePendingNotificationRequests(withIdentifiers: removed)
        for request in requests where !kept.contains(request.identifier) {
            // A request that iOS refuses, for example with no permission, gives no reminder. The settings screen
            // says when iOS does not show the reminders.
            try? await center.add(request)
        }
    }

    /// Keeps only the reminder of today in the Notification Center, with the text of the `todayFoods`. The person
    /// opened the app, which shows the same food, so the reminders of earlier dates go.
    private func cleanDelivered(todayFoods: [ReminderFood], today: CalendarDate) async {
        let message = ReminderText.message(todayFoods)
        var removed: [String] = []
        for notification in await center.deliveredNotifications() {
            let request = notification.request
            let date = PlannedReminder.date(ofIdentifier: request.identifier)
            guard date != nil || request.identifier == Self.testIdentifier else {
                continue
            }
            guard let message, date == today || request.identifier == Self.testIdentifier else {
                removed.append(request.identifier)
                continue
            }
            let content = Self.content(message, quiet: true)
            if request.content.title != content.title || request.content.body != content.body {
                // A request with the identifier of a shown notification replaces that notification. With no trigger,
                // it comes at once, and the passive level and `willPresent` keep it quiet.
                try? await center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: nil))
            }
        }
        center.removeDeliveredNotifications(withIdentifiers: removed)
    }

    func taps() -> AsyncStream<Void> {
        tapStream
    }

    /// The dates of the reminders in the Notification Center, and of the reminders that came or that the person
    /// selected while the app ran. When the person removed a reminder from the Notification Center while the app did
    /// not run, iOS gives no evidence of it.
    func shownDates() async -> Set<CalendarDate> {
        let delivered = await center.deliveredNotifications().compactMap {
            PlannedReminder.date(ofIdentifier: $0.request.identifier)
        }
        return seen.withLock { $0 }.union(delivered)
    }

    /// Records that the reminder of the notification came.
    private func record(_ notification: UNNotification) {
        if let date = PlannedReminder.date(ofIdentifier: notification.request.identifier) {
            seen.withLock { _ = $0.insert(date) }
        }
    }

    // MARK: The content

    /// The content of the notification of a reminder.
    ///
    /// - Parameter quiet: True for a new text of a reminder that iOS already showed: no sound, no banner, and the
    ///   passive level, which does not turn on the screen.
    private static func content(_ message: ReminderMessage, quiet: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = Wording.reminderTitle(message)
        content.body = body(message)
        content.threadIdentifier = thread
        content.categoryIdentifier = categoryPrefix + String(message.count)
        content.interruptionLevel = quiet ? .passive : .active
        content.sound = quiet ? nil : .default
        if quiet {
            content.userInfo = [quietKey: true]
        }
        return content
    }

    /// The text of a reminder: the short text, then one line for each food. A banner shows the first lines, and the
    /// expanded notification shows all of them.
    static func body(_ message: ReminderMessage) -> String {
        ([Wording.reminderNames(message)] + Wording.reminderLines(message)).joined(separator: "\n")
    }

    /// True when the two requests show the same text at the same instant.
    private static func same(_ old: UNNotificationRequest, _ new: UNNotificationRequest) -> Bool {
        old.content.title == new.content.title
            && old.content.body == new.content.body
            && old.content.categoryIdentifier == new.content.categoryIdentifier
            && (old.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                == (new.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
    }

    /// Gives iOS the category of each number of foods that a planned or a shown reminder has. With hidden previews,
    /// the category shows only the number of foods: "3 items need attention". The words are in the language of now.
    private static func registerCategories(_ center: UNUserNotificationCenter) async {
        let pending = await center.pendingNotificationRequests().map(\.content.categoryIdentifier)
        let delivered = await center.deliveredNotifications().map(\.request.content.categoryIdentifier)
        let counts = Set((pending + delivered).compactMap(count(ofCategory:)))
        let others = await center.notificationCategories().filter { !$0.identifier.hasPrefix(categoryPrefix) }
        center.setNotificationCategories(others.union(counts.map(category(count:))))
    }

    private static func count(ofCategory identifier: String) -> Int? {
        guard identifier.hasPrefix(categoryPrefix) else {
            return nil
        }
        return Int(identifier.dropFirst(categoryPrefix.count))
    }

    private static func category(count: Int) -> UNNotificationCategory {
        let title = Wording.reminderTitle(ReminderMessage(count: count, names: [], moreNames: 0, lines: [], moreLines: 0))
        return UNNotificationCategory(
            identifier: categoryPrefix + String(count),
            actions: [],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: title,
            options: []
        )
    }

    private static func isReminder(_ identifier: String) -> Bool {
        PlannedReminder.date(ofIdentifier: identifier) != nil || identifier == testIdentifier
    }

    // MARK: UNUserNotificationCenterDelegate

    // The two functions have the completion handler of the system, and they are not `async`. UIKit must get the call
    // of the handler on the main thread: after a tap, the handler makes the snapshot of the app. Swift runs an `async`
    // function of this class on a thread of its pool, and calls the handler there. UIKit then stops the app
    // (`-[UIApplication _performBlockAfterCATransactionCommitSynchronizes:]`).

    /// A reminder that comes while the app is open shows as a banner with its sound, and it goes to the Notification
    /// Center. A new text of a reminder that iOS already showed goes only to the Notification Center.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        record(notification)
        let quiet = notification.request.content.userInfo[Self.quietKey] as? Bool == true
        let options: UNNotificationPresentationOptions = quiet ? [.list] : [.banner, .list, .sound]
        Self.onMainThread { completionHandler(options) }
    }

    /// The person selected a reminder: the app shows My Fridge with the food that needs attention.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        record(response.notification)
        if Self.isReminder(response.notification.request.identifier),
           response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            tapContinuation.yield()
        }
        Self.onMainThread(completionHandler)
    }

    /// Runs the completion handler of the system on the main thread. The system calls the delegate on the main
    /// thread, and the handler then runs before the delegate function returns. From a different thread, the handler
    /// goes to the main queue.
    private static func onMainThread(_ handler: @escaping () -> Void) {
        if Thread.isMainThread {
            handler()
        } else {
            // The handler of the system is not `Sendable` for the compiler. It is safe to give it to the main queue,
            // because nothing else has it.
            nonisolated(unsafe) let handler = handler
            DispatchQueue.main.async { handler() }
        }
    }
}

#if DEBUG
extension LocalReminderService {
    /// The result of `sendTest`.
    enum TestResult {
        case sent
        /// No food needs a reminder today.
        case nothing
        /// iOS does not show the notifications of the app.
        case notAllowed
    }

    /// Debug build only: shows the reminder of today in about 5 seconds, with its real content. It does not change
    /// the plan. The person can lock the iPhone or go to the Home Screen before it comes.
    static func sendTest(_ foods: [ReminderFood], center: UNUserNotificationCenter = .current()) async -> TestResult {
        guard let message = ReminderText.message(foods) else {
            return .nothing
        }
        let request = UNNotificationRequest(
            identifier: testIdentifier,
            content: content(message, quiet: false),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        )
        do {
            try await center.add(request)
        } catch {
            return .notAllowed
        }
        await registerCategories(center)
        return .sent
    }
}
#endif
