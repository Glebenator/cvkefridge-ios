import CVKEFridgeFeatures
import SwiftUI
import UIKit

/// Settings, the fourth tab: the reminders and About. It takes the place of `ui/SettingsScreen.kt` and
/// `ui/ReminderAccess.kt` of the Android app, as a grouped form of iOS.
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
///
/// The switch turns reminders on in the way that iOS needs. iOS asks for the permission one time only:
/// - Notifications are allowed: reminders go on at once.
/// - The app did not ask yet: an alert explains the reminders first. "Continue" shows the question of iOS. Reminders go
///   on when the person allows notifications.
/// - iOS does not show the notifications of the app: an alert says so, and "Open settings" opens the notification
///   settings of the app. When the person comes back with notifications on, reminders go on.
///
/// While reminders are on and iOS does not show them, a card says so each time, with the action that fixes it.
struct SettingsScreen: View {
    @Environment(FridgeModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    /// The alert of the switch, or nil.
    @State private var dialog: AccessDialog?
    /// True while the person is in the Settings app to turn on notifications for the switch.
    @State private var turnOnOnReturn = false
    /// Changes each time reminders go on, for the haptic signal.
    @State private var turnedOn = 0

    var body: some View {
        Form {
            // The rows have the surface colours of the app, as the rows of each form.
            Group {
                remindersSection
                #if DEBUG
                if let settings = model.reminders.settings, settings.enabled {
                    testSection(settings)
                }
                #endif
                aboutSection
            }
            .listRowBackground(Palette.surfaceContainer)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.surface.ignoresSafeArea())
        .navigationTitle("Settings")
        .accessibilityIdentifier("settings_screen")
        .haptic(.success, trigger: turnedOn)
        .alert(
            dialog?.title ?? "",
            isPresented: Binding(get: { dialog != nil }, set: { if !$0 { dialog = nil } }),
            presenting: dialog
        ) { dialog in
            switch dialog {
            case .explain:
                Button("Not now", role: .cancel) {}
                Button("Continue") { askForAccess() }
            case .openSettings:
                Button("Cancel", role: .cancel) {}
                Button("Open settings") {
                    turnOnOnReturn = true
                    openNotificationSettings()
                }
            }
        } message: { dialog in
            Text(dialog.message)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && turnOnOnReturn {
                turnOnOnReturn = false
                Task {
                    // iOS does not ask again, so this call only reads the access after the Settings app.
                    if await model.requestNotificationAccess() == .allowed {
                        enable()
                    }
                }
            }
        }
    }

    // MARK: Reminders

    @ViewBuilder private var remindersSection: some View {
        switch model.reminders {
        case .loading:
            Section("Reminders") {
                LoadingView(style: .plain)
            }
        case .unreadable:
            Section {
                reminderSwitch(isOn: false)
                Label("Couldn't read the reminder settings. The planned reminders stay. A change here saves new settings.", systemImage: AppIcon.alert.symbol)
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .accessibilityIdentifier("reminders_unreadable")
            } header: {
                Text("Reminders")
            }
        case .ready(let settings):
            Section {
                reminderSwitch(isOn: settings.enabled)
                if settings.enabled {
                    if let access = model.notificationAccess, access != .allowed {
                        AccessProblem(access: access) { fix(access) }
                    }
                    ReminderTimePicker(minuteOfDay: settings.time.minuteOfDay) { minuteOfDay in
                        model.setReminderTime(minuteOfDay: minuteOfDay)
                    }
                    Picker("Remind me", selection: leadBinding(settings)) {
                        ForEach(Array(ReminderRules.leadDayChoices), id: \.self) { days in
                            Text(Wording.reminderLead(days: days)).tag(days)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("reminders_lead")
                    if model.notificationAccess == .allowed {
                        Text(nextReminder(settings))
                            .accessibilityIdentifier("reminders_next")
                    }
                }
            } header: {
                Text("Reminders")
            } footer: {
                if settings.enabled {
                    Text("The reminder comes only when food needs attention. iOS sends it at this time, but a Focus or the Scheduled Summary can hold it until later.")
                }
            }
        }
    }

    /// The switch with its description. A change of the switch gives the haptic signal of the system.
    private func reminderSwitch(isOn: Bool) -> some View {
        Toggle(isOn: Binding(get: { isOn }, set: { on in on ? turnOn() : model.setRemindersOn(false) })) {
            Text("Expiry reminders")
            Text("One notification a day names the food that expires soon or expired yesterday.")
        }
        .accessibilityIdentifier("reminders_switch")
    }

    private func leadBinding(_ settings: ReminderSettings) -> Binding<Int> {
        Binding(get: { settings.leadDays }, set: { model.setReminderLeadDays($0) })
    }

    /// "Next reminder: tomorrow at 9:00 AM." from the plan of the model.
    private func nextReminder(_ settings: ReminderSettings) -> String {
        guard let next = settings.next else {
            return String(localized: "No reminder is planned, because no food needs attention.")
        }
        let time = Wording.time(settings.time)
        let today = model.today
        if next == today {
            return String(localized: "Next reminder: today at \(time).")
        }
        if next == today.plusDays(1) {
            return String(localized: "Next reminder: tomorrow at \(time).")
        }
        var format = Date.FormatStyle.dateTime.weekday(.wide).month(.wide).day()
        format.timeZone = .gmt
        let date = Wording.instant(of: next).formatted(format)
        return String(localized: "Next reminder: \(date) at \(time).", comment: "The values are a date and a time.")
    }

    // MARK: The permission

    /// The person turned the switch on.
    private func turnOn() {
        switch model.notificationAccess {
        case .allowed:
            enable()
        case .ask, nil:
            dialog = .explain
        case .blocked:
            dialog = .openSettings(.blocked)
        case .alertsOff:
            dialog = .openSettings(.alertsOff)
        }
    }

    /// The action of the card of an access problem.
    private func fix(_ access: NotificationAccess) {
        switch access {
        case .ask:
            dialog = .explain
        case .blocked, .alertsOff:
            openNotificationSettings()
        case .allowed:
            break
        }
    }

    /// Shows the question of iOS after the explanation. Reminders go on when the person allows notifications.
    private func askForAccess() {
        Task {
            if await model.requestNotificationAccess() == .allowed {
                enable()
            }
        }
    }

    private func enable() {
        guard model.reminders.settings?.enabled != true else {
            return
        }
        model.setRemindersOn(true)
        turnedOn += 1
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            openURL(url)
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section {
            HStack(spacing: Space.s3) {
                BrandTile(size: 48)
                VStack(alignment: .leading, spacing: Space.s1) {
                    Text(verbatim: "CVKE Fridge")
                        .font(Typography.cardTitle)
                    Text("Made by cvke")
                        .font(Typography.secondary)
                        .foregroundStyle(Palette.onSurfaceVariant)
                }
            }
            .accessibilityElement(children: .combine)
            HStack {
                Text("Version")
                Spacer()
                Text(verbatim: AppVersion.current.label)
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .accessibilityIdentifier("about_version")
            }
            LabeledContent("Product lookup", value: "Open Food Facts")
            LabeledContent("Expiry estimates", value: "USDA FoodKeeper")
        } header: {
            Text("About")
        } footer: {
            Text("Your inventory stays on this iPhone. When you scan or type a barcode, only the barcode number goes to Open Food Facts. The expiry estimates use the FoodKeeper data of the USDA FSIS (CC0 1.0).")
        }
    }

    // MARK: Debug

    #if DEBUG
    /// Debug build only: the reminder of today now, with no wait for its time. The release build has no such control.
    private func testSection(_ settings: ReminderSettings) -> some View {
        Section {
            Button {
                sendTest(settings)
            } label: {
                Text(verbatim: "Send a test reminder")
            }
            .accessibilityIdentifier("send_test_reminder")
        } footer: {
            Text(verbatim: "Debug build only. The reminder of today comes in about 5 seconds.")
        }
    }

    private func sendTest(_ settings: ReminderSettings) {
        guard let inventory = model.content?.inventory else {
            return
        }
        let foods = ReminderRules.foods(inventory, today: model.today, leadDays: settings.leadDays)
        Task {
            let text = switch await LocalReminderService.sendTest(foods) {
            case .sent: "Test reminder sent"
            case .nothing: "No food needs a reminder today, so there is no test reminder."
            case .notAllowed: "iOS does not allow notifications for the app."
            }
            model.showNotice(text, kind: .information)
        }
    }
    #endif
}

/// The alert of the switch.
private enum AccessDialog: Identifiable {
    /// The explanation before iOS asks for the permission.
    case explain
    /// iOS does not show the notifications, and only the Settings app can change it.
    case openSettings(NotificationAccess)

    var id: String {
        switch self {
        case .explain: "explain"
        case .openSettings: "openSettings"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .explain: "Allow notifications"
        case .openSettings: "Notifications are off"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .explain:
            "Reminders are notifications. Next, iOS asks if CVKE Fridge can send notifications. The app sends not more than one a day, and only when food needs attention. The app makes the reminder on your iPhone. No data leaves your iPhone."
        case .openSettings(.alertsOff):
            "iOS does not show the notifications of CVKE Fridge on the Lock Screen, in Notification Center, or as banners. To get reminders, open the settings and turn them on."
        case .openSettings:
            "Notifications for CVKE Fridge are off. To get reminders, open the settings and turn them on."
        }
    }
}

/// The time of the reminder: the compact time picker of iOS, with the 12-hour or the 24-hour clock of the device.
///
/// The picker changes its own value while the person turns the wheels. The time goes to the settings when the wheels
/// stop for a short time. So a turn of a wheel writes the settings one time, and a new value from the model does not
/// move a wheel that the person turns. When the screen closes before that time, the time goes to the settings at
/// once.
private struct ReminderTimePicker: View {
    /// The time of the settings.
    let minuteOfDay: Int
    let onChange: (Int) -> Void

    @State private var selection: Date?
    /// The wait before the time of the wheels goes to the settings. Each new value of the wheels starts it again.
    @State private var pending: Task<Void, Never>?

    /// The time that the wheels stop before the time goes to the settings.
    private static let settle = Duration.milliseconds(600)

    var body: some View {
        DatePicker(
            "Time",
            selection: Binding(get: { selection ?? Self.instant(minuteOfDay) }, set: { select($0) }),
            displayedComponents: .hourAndMinute
        )
        // The instant is a time in UTC, so that each time of the day exists on the picker.
        .environment(\.timeZone, .gmt)
        .accessibilityIdentifier("reminders_time")
        .onDisappear(perform: commit)
        .onChange(of: minuteOfDay) {
            // A change that the model saved, or that came from an other place, replaces the draft.
            if let selection, Self.minuteOfDay(selection) == minuteOfDay {
                self.selection = nil
            }
        }
    }

    /// Keeps a new value of the wheels, and starts the wait again. The wheels can give some values in one frame, so
    /// the wait gets the value itself and does not read the state of the view.
    private func select(_ instant: Date) {
        selection = instant
        pending?.cancel()
        let selected = Self.minuteOfDay(instant)
        let onChange = onChange
        pending = Task {
            try? await Task.sleep(for: Self.settle)
            if !Task.isCancelled {
                // The model writes nothing when the time is the time of the settings.
                onChange(selected)
            }
        }
    }

    /// Gives the time of the wheels to the settings now, when the wait did not end.
    private func commit() {
        guard let pending else {
            return
        }
        pending.cancel()
        self.pending = nil
        if let selection, Self.minuteOfDay(selection) != minuteOfDay {
            onChange(Self.minuteOfDay(selection))
        }
    }

    /// The instant of a time of the day on the picker: 1 January 2001 in UTC.
    private static func instant(_ minuteOfDay: Int) -> Date {
        var components = DateComponents()
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = minuteOfDay / 60
        components.minute = minuteOfDay % 60
        return Wording.utcCalendar.date(from: components) ?? .distantPast
    }

    private static func minuteOfDay(_ instant: Date) -> Int {
        let components = Wording.utcCalendar.dateComponents([.hour, .minute], from: instant)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

/// Why iOS does not show the reminders, with the action that fixes it. It has the error colours, so that it is easy
/// to see, and neutral words.
private struct AccessProblem: View {
    let access: NotificationAccess
    let fix: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Label {
                Text(status)
            } icon: {
                Image(icon: .bellOff)
            }
            .foregroundStyle(Palette.onErrorContainer)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("notification_access_problem")
            Button(action: fix) {
                Text(actionTitle)
                    .foregroundStyle(Palette.onError)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.error)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityIdentifier("notification_access_fix")
        }
        .padding(.vertical, Space.s1)
        .listRowBackground(Palette.errorContainer)
    }

    private var status: LocalizedStringKey {
        switch access {
        case .ask:
            "Notifications for CVKE Fridge are not allowed, so reminders cannot show."
        case .alertsOff:
            "iOS does not show the notifications of CVKE Fridge on the Lock Screen, in Notification Center, or as banners, so reminders cannot show."
        case .blocked, .allowed:
            "Notifications for CVKE Fridge are off in the settings of iOS, so reminders cannot show."
        }
    }

    private var actionTitle: LocalizedStringKey {
        access == .ask ? "Allow notifications" : "Open settings"
    }
}
