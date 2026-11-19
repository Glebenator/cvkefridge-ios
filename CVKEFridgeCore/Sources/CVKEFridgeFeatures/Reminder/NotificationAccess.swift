import Foundation

// If the system shows the reminders of the app. The Android file
// `app/src/main/java/com/cvke/fridge/reminder/NotificationAccess.kt` in cvkefridge-android makes the same decision from
// what Android says. Here the decision uses what iOS says (`UNNotificationSettings`).
//
// iOS asks for the permission one time only. A person who did not allow notifications can turn them on only in the
// Settings app. So iOS has no state "denied, and the app can ask again" (`DENIED` of Android): a refusal is `blocked`.

/// What iOS says about the notification permission of the app (`UNAuthorizationStatus`).
public enum NotificationAuthorization: Hashable, Sendable, CaseIterable {
    /// The app did not ask yet.
    case notDetermined
    /// The person did not allow notifications, or turned them off in the Settings app.
    case denied
    case authorized
    /// The system shows the notifications quietly, in the Notification Center only.
    case provisional
    /// An App Clip can show notifications for a short time.
    case ephemeral
}

/// If iOS shows the reminders of the app, and what the person can do when it does not.
public enum NotificationAccess: Hashable, Sendable, CaseIterable {
    /// iOS shows the reminders.
    case allowed
    /// The app did not ask for the notification permission yet. The app explains it, then asks.
    case ask
    /// The notifications of the app are off, and only the Settings app can turn them on.
    case blocked
    /// The app has the permission, but the person turned off each place that shows a notification: the lock screen,
    /// the Notification Center, and the banners. This is the `CHANNEL_OFF` of Android.
    case alertsOff

    /// The access from what iOS says.
    ///
    /// - Parameters:
    ///   - authorization: The `authorizationStatus` of the notification settings.
    ///   - shownSomewhere: True when the lock screen, the Notification Center, or the banners show the notifications of
    ///     the app (`lockScreenSetting`, `notificationCenterSetting`, `alertSetting` is `.enabled`).
    public static func of(authorization: NotificationAuthorization, shownSomewhere: Bool) -> NotificationAccess {
        switch authorization {
        case .notDetermined:
            return .ask
        case .denied:
            return .blocked
        case .authorized, .provisional, .ephemeral:
            return shownSomewhere ? .allowed : .alertsOff
        }
    }
}
