import CVKEFridgeFeatures
import SwiftUI
import UIKit

/// The steps that turn reminders on with the notification permission of iOS. The switch of Settings and the offer on
/// Home use the same steps and the same words. It takes the place of `ui/ReminderAccess.kt` of the Android app.
///
/// iOS asks for the permission one time only:
/// - Notifications are allowed: reminders go on at once.
/// - The app did not ask yet: an alert explains the reminders first. "Continue" shows the question of iOS. Reminders go
///   on when the person allows notifications.
/// - iOS does not show the notifications of the app: an alert says so, and "Open settings" opens the notification
///   settings of the app. When the person comes back with notifications on, reminders go on. When the person comes
///   back with notifications still off, nothing occurs, and the flow forgets the visit.
///
/// The value has no side effects. Each step gives the `Effect` that the screen must do. `reminderAccess(_:onTurnOn:onDeclined:)`
/// shows the alerts and does the effects.
struct ReminderAccessFlow: Equatable {
    /// The alert on the screen.
    enum Dialog: Equatable {
        /// The explanation before the question of iOS.
        case explain
        /// iOS does not show the notifications, and only the Settings app can change it. The value is `.blocked` or
        /// `.alertsOff`.
        case openSettings(NotificationAccess)
    }

    /// What the screen must do after a step.
    enum Effect: Equatable {
        case none
        /// Turn reminders on.
        case turnOn
        /// Show the question of iOS, and give the answer to `systemAnswered(_:)`.
        case askSystem
        /// Open the notification settings of the app in the Settings app.
        case openSettings
        /// The person did not allow notifications in the question of iOS.
        case declined
    }

    /// The alert on the screen, or nil.
    private(set) var dialog: Dialog?
    /// True while the question of iOS is on the screen. A second "Continue" then does nothing.
    private(set) var asking = false
    /// True from "Open settings" until the app is active again.
    private(set) var inSettings = false

    /// The person wants reminders on.
    ///
    /// - Parameter access: The notification access, or nil while the app does not know it. With nil, nothing occurs:
    ///   the control is off until the access is known.
    mutating func turnOn(access: NotificationAccess?) -> Effect {
        switch access {
        case .allowed:
            return .turnOn
        case .ask:
            dialog = .explain
        case .blocked, .alertsOff:
            dialog = access.map { .openSettings($0) }
        case nil:
            break
        }
        return .none
    }

    /// The action of the card that says why iOS does not show the reminders: the explanation for `.ask`, and the
    /// Settings app for `.blocked` and `.alertsOff`.
    mutating func fix(_ access: NotificationAccess) -> Effect {
        switch access {
        case .ask:
            dialog = .explain
            return .none
        case .blocked, .alertsOff:
            inSettings = true
            return .openSettings
        case .allowed:
            return .none
        }
    }

    /// "Continue" in the explanation.
    mutating func continueToSystem() -> Effect {
        dialog = nil
        if asking {
            return .none
        }
        asking = true
        return .askSystem
    }

    /// The answer of the question of iOS.
    mutating func systemAnswered(_ access: NotificationAccess) -> Effect {
        asking = false
        return access == .allowed ? .turnOn : .declined
    }

    /// "Open settings" in the alert.
    mutating func openSettings() -> Effect {
        dialog = nil
        inSettings = true
        return .openSettings
    }

    /// "Not now" or "Cancel": the alert closes, and nothing changes.
    mutating func dismiss() {
        dialog = nil
    }

    /// The app is active again, and `access` is the notification access now. After a visit to the Settings app,
    /// reminders go on when notifications are on. The flow forgets the visit in each case, so a later change of the
    /// access does not turn reminders on.
    mutating func returned(access: NotificationAccess) -> Effect {
        guard inSettings else {
            return .none
        }
        inSettings = false
        return access == .allowed ? .turnOn : .none
    }
}

extension View {
    /// Shows the alerts of the `flow` and does its effects. `onTurnOn` turns reminders on. `onDeclined` runs when the
    /// person did not allow notifications in the question of iOS.
    func reminderAccess(
        _ flow: Binding<ReminderAccessFlow>,
        onTurnOn: @escaping @MainActor () -> Void,
        onDeclined: @escaping @MainActor () -> Void = {}
    ) -> some View {
        modifier(ReminderAccessDialogs(flow: flow, onTurnOn: onTurnOn, onDeclined: onDeclined))
    }
}

/// The alerts of a `ReminderAccessFlow`, with one set of words for the switch of Settings and the offer on Home. The
/// words follow the Android app.
private struct ReminderAccessDialogs: ViewModifier {
    @Binding var flow: ReminderAccessFlow
    let onTurnOn: @MainActor () -> Void
    let onDeclined: @MainActor () -> Void

    @Environment(FridgeModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            // The buttons of the alerts have no identifier: the UI tests find the parts of the system by their words,
            // and an identifier on a button of an alert gives two elements with it.
            .alert(
                title(flow.dialog),
                isPresented: Binding(get: { flow.dialog != nil }, set: { if !$0 { flow.dismiss() } }),
                presenting: flow.dialog
            ) { dialog in
                switch dialog {
                case .explain:
                    Button("Not now", role: .cancel) { flow.dismiss() }
                    Button("Continue") { perform(flow.continueToSystem()) }
                case .openSettings:
                    Button("Cancel", role: .cancel) { flow.dismiss() }
                    Button("Open settings") { perform(flow.openSettings()) }
                }
            } message: { dialog in
                Text(message(dialog))
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, flow.inSettings else {
                    return
                }
                Task {
                    let access = await model.readNotificationAccess()
                    perform(flow.returned(access: access))
                }
            }
    }

    private func title(_ dialog: ReminderAccessFlow.Dialog?) -> LocalizedStringKey {
        switch dialog {
        case .explain, nil: "Allow notifications"
        case .openSettings: "Notifications are off"
        }
    }

    private func message(_ dialog: ReminderAccessFlow.Dialog) -> LocalizedStringKey {
        switch dialog {
        case .explain:
            "Reminders are notifications. Next, iOS asks if CVKE Fridge can send notifications. The app sends not more than one a day, and only when food needs attention. The app makes the reminder on your phone. No data leaves your phone."
        case .openSettings(.alertsOff):
            "iOS does not show the notifications of CVKE Fridge on the Lock Screen, in Notification Center, or as banners. To get reminders, open the settings and turn one of them on."
        case .openSettings:
            "Notifications for CVKE Fridge are off. To get reminders, open the settings and turn them on."
        }
    }

    private func perform(_ effect: ReminderAccessFlow.Effect) {
        switch effect {
        case .none:
            break
        case .turnOn:
            onTurnOn()
        case .declined:
            onDeclined()
        case .askSystem:
            Task {
                let access = await model.requestNotificationAccess()
                perform(flow.systemAnswered(access))
            }
        case .openSettings:
            openNotificationSettings(openURL)
        }
    }
}

/// Opens the notification settings of the app in the Settings app.
@MainActor
func openNotificationSettings(_ openURL: OpenURLAction) {
    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
        openURL(url)
    }
}
