import CVKEFridgeFeatures
import SwiftUI
import UIKit

/// The offer of reminders on Home. It takes the place of `ReminderOffer` in `ui/ReminderParts.kt` and of the offer
/// part of `ui/ReminderAccess.kt` of the Android app.
///
/// Home shows the offer when the inventory has food with an expiry date, and the person did not turn reminders on
/// and did not close the offer. The app never asks for the notification permission at the first start.
///
/// - "Turn on" explains the notifications before iOS asks for the permission. With the permission, reminders are
///   on, and a message says so. With no permission, the offer closes for good, as "Not now" does.
/// - When the notifications of the app are off in the Settings app, "Turn on" says so and opens the Settings app.
///   When the person comes back with the notifications on, reminders are on.
/// - "Not now" closes the offer for good. A message says where the switch is. The Settings tab always has it.
struct ReminderOffer: View {
    let overview: InventoryContent

    @Environment(FridgeModel.self) private var model
    @Environment(\.openURL) private var openURL

    /// What "Turn on" shows before reminders are on.
    private enum Step: Identifiable {
        /// The explanation before the question of iOS.
        case explain
        /// The notifications are off in the Settings app.
        case openSettings(NotificationAccess)

        var id: Int {
            switch self {
            case .explain: 0
            case .openSettings: 1
            }
        }
    }

    @State private var step: Step?
    /// True after the person opened the Settings app to turn the notifications on.
    @State private var inSettings = false
    /// True while the question of iOS is on the screen. A second tap then does nothing.
    @State private var asking = false

    /// The settings of the offer, or nil when Home does not offer reminders.
    private var offered: ReminderSettings? {
        guard let settings = model.reminders.settings, !model.remindersSwitchOn, !settings.offerDismissed,
              overview.foods.contains(where: { $0.expiry != nil })
        else {
            return nil
        }
        return settings
    }

    var body: some View {
        let offered = offered
        VStack(spacing: 0) {
            if let offered {
                card(offered)
                    .padding(.top, Space.s4)
                    .transition(.scaleFade(0.96, anchor: .top))
            }
        }
        .motion(Motion.exit, value: offered == nil)
        .onChange(of: model.notificationAccess) { _, access in
            // The person came back from the Settings app with the notifications on.
            if inSettings, access == .allowed {
                inSettings = false
                model.setRemindersOn(true, fromOffer: true)
            }
        }
        .alert("Allow notifications", isPresented: isShown(0)) {
            Button("Continue") { ask() }
                .accessibilityIdentifier("notifications_continue")
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Reminders are notifications. Next, iOS asks if CVKE Fridge can send notifications. The app sends not more than one a day, and only when food needs attention. The app makes the reminder on your phone. No data leaves your phone.")
        }
        .alert("Notifications are off", isPresented: isShown(1)) {
            Button("Open settings") { openSettings() }
                .accessibilityIdentifier("notifications_open_settings")
            Button("Cancel", role: .cancel) {}
        } message: {
            if case .openSettings(.alertsOff) = step {
                Text("CVKE Fridge can send notifications, but the Lock Screen, the Notification Center, and the banners are off for it. To get reminders, open the settings and turn one of them on.")
            } else {
                Text("Notifications for CVKE Fridge are off. To get reminders, open the settings and turn them on.")
            }
        }
    }

    private func card(_ settings: ReminderSettings) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Space.s2) {
                HStack(alignment: .top, spacing: Space.s3) {
                    IconTile(.bell, tone: .accent)
                    VStack(alignment: .leading, spacing: Space.s1) {
                        Text("Get a reminder before food expires")
                            .font(Typography.cardTitle)
                            .accessibilityAddTraits(.isHeader)
                        Text("One notification a day at \(Wording.time(settings.time)) names the food that expires soon. You can change the time in Settings.")
                            .font(Typography.secondary)
                            .foregroundStyle(Palette.onSurfaceVariant)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                FlowLayout(alignment: .trailing, spacing: Space.s3) {
                    Button("Not now") {
                        model.dismissReminderOffer()
                    }
                    .buttonStyle(.quiet)
                    .accessibilityHint(Text("Closes this offer. You can turn on reminders in Settings."))
                    .accessibilityIdentifier("reminder_offer_dismiss")
                    Button("Turn on") {
                        turnOn()
                    }
                    .buttonStyle(.secondary(.compact))
                    // The button waits until the app knows the notification access.
                    .disabled(model.notificationAccess == nil)
                    .accessibilityHint(Text("Turns on the reminder of each day."))
                    .accessibilityIdentifier("reminder_offer_turn_on")
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reminder_offer")
    }

    /// True while the step with the identifier `id` is on the screen.
    private func isShown(_ id: Int) -> Binding<Bool> {
        Binding(
            get: { step?.id == id },
            set: { shown in
                if !shown, step?.id == id {
                    step = nil
                }
            }
        )
    }

    private func turnOn() {
        switch model.notificationAccess {
        case .allowed:
            model.setRemindersOn(true, fromOffer: true)
        case .ask, nil:
            step = .explain
        case .blocked:
            step = .openSettings(.blocked)
        case .alertsOff:
            step = .openSettings(.alertsOff)
        }
    }

    /// Asks iOS for the permission, after the explanation.
    private func ask() {
        guard !asking else {
            return
        }
        asking = true
        Task {
            let access = await model.requestNotificationAccess()
            asking = false
            if access == .allowed {
                model.setRemindersOn(true, fromOffer: true)
            } else {
                // The person said no to the notifications. Home does not offer reminders again.
                model.dismissReminderOffer()
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else {
            return
        }
        inSettings = true
        openURL(url)
    }
}
