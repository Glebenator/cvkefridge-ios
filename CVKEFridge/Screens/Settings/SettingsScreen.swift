import CVKEFridgeFeatures
import SwiftUI

/// Settings, the fourth tab. PLACEHOLDER: this file has the switch of the reminders and the version. The Settings
/// agent replaces the body. The signature `SettingsScreen()` stays.
///
/// Contract:
/// - The screen is the first screen of the navigation stack of the Settings tab. It sets its navigation title, and it
///   does not make a `NavigationStack`.
/// - The reminder settings are `model.reminders`: `.loading`, `.unreadable` (the file cannot be read: say so, and
///   change nothing until the person changes a setting), or `.ready(ReminderSettings)`.
/// - `model.notificationAccess` says if iOS shows the reminders (`.allowed`, `.ask`, `.blocked`, `.alertsOff`).
///   Explain the notifications before `await model.requestNotificationAccess()`. When access is `.blocked` or
///   `.alertsOff`, offer the Settings app. `RootView` reads the access again when the app comes back.
/// - Changes: `model.setRemindersOn(_:)`, `model.setReminderTime(minuteOfDay:)`, `model.setReminderLeadDays(_:)`.
///   The choices of the lead time are `ReminderRules.leadDayChoices`. Words: `Wording.reminderLead(days:)` and
///   `Wording.time(_:)`. `ReminderSettings.next` is the date of the next reminder, or nil when no food needs one.
/// - iOS has no wallpaper colours, so the screen has no "Appearance" group.
/// - About: the version is `AppVersion.current.label`.
struct SettingsScreen: View {
    @Environment(FridgeModel.self) private var model

    var body: some View {
        List {
            Section("Reminders") {
                switch model.reminders {
                case .loading:
                    LoadingView(style: .plain)
                case .unreadable:
                    Text("The reminder settings can't be read.")
                    Button("Turn on") { turnOn() }
                case .ready(let settings):
                    Toggle("Expiry reminders", isOn: Binding(
                        get: { settings.enabled },
                        set: { on in on ? turnOn() : model.setRemindersOn(false) }
                    ))
                    .accessibilityIdentifier("reminders_switch")
                    LabeledContent("Time", value: Wording.time(settings.time))
                    LabeledContent("Remind me", value: Wording.reminderLead(days: settings.leadDays))
                }
            }
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(verbatim: AppVersion.current.label)
                        .foregroundStyle(Palette.onSurfaceVariant)
                        .accessibilityIdentifier("about_version")
                }
            }
        }
        .navigationTitle("Settings")
        .accessibilityIdentifier("settings_screen")
    }

    private func turnOn() {
        Task {
            if model.notificationAccess != .allowed {
                _ = await model.requestNotificationAccess()
            }
            model.setRemindersOn(true)
        }
    }
}
