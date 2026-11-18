import CVKEFridgeFeatures
import SwiftUI

/// The offer of reminders on Home. It takes the place of `ReminderOffer` in `ui/ReminderParts.kt` and of the offer
/// part of `ui/ReminderAccess.kt` of the Android app.
///
/// Home shows the offer when the inventory has food with an expiry date, and the person did not turn reminders on
/// and did not close the offer. The app never asks for the notification permission at the first start.
///
/// - "Turn on" uses the steps of `ReminderAccessFlow`, as the switch of Settings does. With the permission, reminders
///   are on, and a message says so. When the person does not allow notifications in the question of iOS, the offer
///   closes for good, as "Not now" does.
/// - "Not now" closes the offer for good. A message says where the switch is. The Settings tab always has it.
struct ReminderOffer: View {
    let overview: InventoryContent

    @Environment(FridgeModel.self) private var model

    /// The steps that turn reminders on with the notification permission.
    @State private var access = ReminderAccessFlow()

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
        .reminderAccess($access) {
            model.setRemindersOn(true, fromOffer: true)
        } onDeclined: {
            // The person said no to the notifications. Home does not offer reminders again.
            model.dismissReminderOffer()
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

    private func turnOn() {
        if access.turnOn(access: model.notificationAccess) == .turnOn {
            model.setRemindersOn(true, fromOffer: true)
        }
    }
}
