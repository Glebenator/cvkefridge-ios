import CVKEFridgeFeatures
import Foundation
import UserNotifications

/// The reminders as local notifications of iOS, with calendar triggers. The Android app sets an alarm, and its code
/// reads the inventory at the time of the alarm. iOS does not start the code of the app at a time, so each reminder
/// is planned ahead with its text (`ReminderPlan`).
///
/// One notification is planned for each date that has food. Its identifier has the date, so a new plan replaces the
/// notification of the same date. A tap on a reminder opens the app, and `taps()` gives the tap to the model.
///
/// The notification has the number of foods as its title, and one line for each food as its text. It has no data
/// that leaves the phone: the system shows it on this device.
final class LocalReminderService: NSObject, ReminderService, UNUserNotificationCenterDelegate, @unchecked Sendable {
    // The stored values are constants, and each is safe to use from more than one thread.

    /// The start of the identifier of each reminder. The rest is the date: `reminder-2026-11-14`.
    private static let identifierPrefix = "reminder-"
    private static let thread = "expiry-reminders"

    private let center: UNUserNotificationCenter
    private let tapStream: AsyncStream<Void>
    private let tapContinuation: AsyncStream<Void>.Continuation

    /// Makes the service and connects it to the notification center. Make it before the app completes its start, so
    /// that the tap that started the app arrives.
    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        (tapStream, tapContinuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        super.init()
        center.delegate = self
    }

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

    func requestAccess() async -> NotificationAccess {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        return await access()
    }

    func update(planned: [PlannedReminder], todayFoods: [ReminderFood], timeZone: TimeZone) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter(Self.isReminder)
        center.removePendingNotificationRequests(withIdentifiers: pending)
        for reminder in planned {
            let message = reminder.message
            let content = UNMutableNotificationContent()
            content.title = Wording.reminderTitle(message)
            content.body = Wording.reminderLines(message).joined(separator: "\n")
            content.sound = .default
            content.threadIdentifier = Self.thread
            var date = DateComponents()
            date.calendar = Calendar(identifier: .gregorian)
            date.timeZone = timeZone
            date.year = reminder.date.year
            date.month = reminder.date.month
            date.day = reminder.date.day
            date.hour = reminder.time.hour
            date.minute = reminder.time.minute
            let request = UNNotificationRequest(
                identifier: Self.identifierPrefix + reminder.date.text,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: false)
            )
            // A request that iOS refuses, for example with no permission, gives no reminder. The settings screen
            // says when iOS does not show the reminders.
            try? await center.add(request)
        }
        if todayFoods.isEmpty {
            // No food needs attention now, so a reminder in the Notification Center is old.
            let delivered = await center.deliveredNotifications().map(\.request.identifier).filter(Self.isReminder)
            center.removeDeliveredNotifications(withIdentifiers: delivered)
        }
    }

    func taps() -> AsyncStream<Void> {
        tapStream
    }

    private static func isReminder(_ identifier: String) -> Bool {
        identifier.hasPrefix(identifierPrefix)
    }

    // MARK: UNUserNotificationCenterDelegate

    /// A reminder that comes while the app is open shows as a banner, and it goes to the Notification Center.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// The person selected a notification.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if Self.isReminder(response.notification.request.identifier),
           response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            tapContinuation.yield()
        }
    }
}
