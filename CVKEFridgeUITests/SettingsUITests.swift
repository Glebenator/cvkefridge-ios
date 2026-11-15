import XCTest

/// The settings: the reminders and About. The port of `ReminderDeviceTest.kt` and `SettingsDeviceTest.kt` of the
/// Android app, for the parts that do not need the system. The app gets a fixed notification permission
/// (`CVKE_NOTIFICATIONS`), so no question of iOS comes, and no notification goes to the system.
final class SettingsUITests: FridgeUITestCase {
    /// Opens the Settings tab.
    private func openSettings() {
        expect(tab("Settings"), "The tab bar has no Settings").tap()
        expect(app.navigationBars["Settings"], "Settings did not open")
    }

    private var reminderSwitch: XCUIElement {
        app.switches["reminders_switch"]
    }

    /// Changes the switch. A tap on the middle of the row does not change a switch of a form, so the tap is on the
    /// switch itself.
    private func toggleReminders() {
        let control = reminderSwitch.switches.firstMatch
        (control.exists ? control : reminderSwitch).tap()
    }

    /// The label of the element, with normal spaces. The time format of iOS has a narrow space before "AM".
    private func text(_ element: XCUIElement) -> String {
        element.label.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// Waits until the label of the element, with normal spaces, contains the text.
    private func waitFor(_ element: XCUIElement, labelContaining text: String, _ message: String) {
        let matches = NSPredicate { object, _ in
            ((object as? XCUIElement)?.label.replacingOccurrences(of: "\u{202F}", with: " ").contains(text)) ?? false
        }
        let expectation = XCTNSPredicateExpectation(predicate: matches, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 10), .completed, "\(message): \(element.label)")
    }

    private func waitFor(_ element: XCUIElement, value: String, _ message: String) {
        let matches = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: matches, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 10), .completed, message)
    }

    func test1TheSwitchExplainsTheNotificationsBeforeItAsks() throws {
        launch(notifications: "ask")
        openSettings()
        expect(reminderSwitch, "Settings has no switch for the reminders")
        XCTAssertEqual(reminderSwitch.value as? String, "0", "Reminders are on at the start")
        XCTAssertFalse(app.alerts.firstMatch.exists, "Something asks at the start")

        // "Not now" closes the explanation, and reminders stay off.
        toggleReminders()
        let explanation = expect(app.alerts["Allow notifications"], "No explanation before iOS asks")
        XCTAssertTrue(explanation.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Next, iOS asks")).firstMatch.exists)
        capture("settings-explanation")
        explanation.buttons["Not now"].tap()
        waitFor(reminderSwitch, value: "0", "Reminders went on with no permission")

        // "Continue" asks. The fixed permission says yes, and reminders go on.
        toggleReminders()
        expect(app.alerts["Allow notifications"], "No explanation the second time").buttons["Continue"].tap()
        waitFor(reminderSwitch, value: "1", "Reminders did not go on after the permission")
        expect(app.datePickers["reminders_time"], "No time after reminders went on")
        // With the largest text, the rows below the time are below the screen.
        scrollTo(app.buttons["reminders_lead"], "No lead time after reminders went on")
        // The clock of the test is at 12:00, so the reminder at 9:00 of today has passed.
        let next = scrollTo(app.staticTexts["reminders_next"], "No next reminder")
        XCTAssertEqual(text(next), "Next reminder: tomorrow at 9:00 AM.")
        XCTAssertFalse(app.staticTexts["notification_access_problem"].exists, "A problem shows with notifications allowed")
        capture("settings-reminders-on")

        // Off removes the settings of the reminder.
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        toggleReminders()
        waitFor(reminderSwitch, value: "0", "Reminders did not go off")
        XCTAssertFalse(app.datePickers["reminders_time"].exists, "The time stays with reminders off")
    }

    func test2TheTimeAndTheLeadTimeStayAfterARestart() throws {
        launch(notifications: "allowed")
        openSettings()
        // With notifications allowed, the switch turns reminders on with no question.
        toggleReminders()
        waitFor(reminderSwitch, value: "1", "Reminders did not go on")
        XCTAssertFalse(app.alerts.firstMatch.exists, "An explanation came with notifications allowed")

        // The lead time, in the menu of the picker.
        let lead = scrollTo(app.buttons["reminders_lead"], "No lead time")
        lead.tap()
        expect(app.buttons["1 day before the expiry date"], "The menu has no lead time of one day").tap()
        waitFor(lead, labelContaining: "1 day before the expiry date", "The lead time did not change")

        // The time, in the compact time picker.
        let time = scrollTo(app.datePickers["reminders_time"], "No time")
        time.tap()
        let wheels = app.pickerWheels
        expect(wheels.firstMatch, "The time picker has no wheels")
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "7")
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: "30")
        capture("settings-time-picker")
        // A tap outside the picker closes it.
        app.navigationBars["Settings"].firstMatch.tap()
        let next = scrollTo(app.staticTexts["reminders_next"], "No next reminder")
        waitFor(next, labelContaining: "Next reminder: tomorrow at 7:30 AM.", "The next reminder does not have the new time")

        // A new start reads the same settings from the file.
        app.terminate()
        launch(notifications: "allowed", keepsStore: true)
        openSettings()
        waitFor(reminderSwitch, value: "1", "Reminders are not on after a restart")
        waitFor(scrollTo(app.buttons["reminders_lead"], "No lead time after a restart"), labelContaining: "1 day before the expiry date", "The lead time is not kept")
        XCTAssertEqual(text(scrollTo(app.staticTexts["reminders_next"], "No next reminder after a restart")), "Next reminder: tomorrow at 7:30 AM.")
    }

    func test3SettingsSaysWhenIOSDoesNotShowTheReminders() throws {
        launch(notifications: "allowed")
        openSettings()
        toggleReminders()
        waitFor(reminderSwitch, value: "1", "Reminders did not go on")

        // The person turns off the banners, the Notification Center, and the Lock Screen in the Settings app.
        app.terminate()
        launch(notifications: "alertsOff", keepsStore: true)
        openSettings()
        waitFor(reminderSwitch, value: "1", "Reminders are not on after a restart")
        let problem = expect(app.staticTexts["notification_access_problem"], "No problem with the banners off")
        XCTAssertTrue(problem.label.contains("Notification Center"), "The problem does not say what is off: \(problem.label)")
        XCTAssertEqual(app.buttons["notification_access_fix"].label, "Open settings")
        XCTAssertFalse(app.staticTexts["reminders_next"].exists, "A next reminder shows that iOS does not show")
        capture("settings-alerts-off")

        // The person turns off the notifications of the app.
        app.terminate()
        launch(notifications: "blocked", keepsStore: true)
        openSettings()
        let blocked = expect(app.staticTexts["notification_access_problem"], "No problem with notifications off")
        XCTAssertEqual(blocked.label, "Notifications for CVKE Fridge are off in the settings of iOS, so reminders cannot show.")
        XCTAssertEqual(app.buttons["notification_access_fix"].label, "Open settings")

        // Off and on again: iOS does not ask again, so the switch offers the Settings app.
        toggleReminders()
        waitFor(reminderSwitch, value: "0", "Reminders did not go off")
        toggleReminders()
        let off = expect(app.alerts["Notifications are off"], "The switch does not say that notifications are off")
        XCTAssertTrue(off.buttons["Open settings"].exists)
        off.buttons["Cancel"].tap()
        waitFor(reminderSwitch, value: "0", "Reminders went on with notifications off")
    }

    func test4AboutHasTheVersionTheMakerAndWhatLeavesThePhone() throws {
        launch()
        openSettings()
        let version = scrollTo(app.staticTexts["about_version"], "Settings does not show the version")
        XCTAssertEqual(version.label, "0.1.0 (1)")
        let lookup = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Open Food Facts")).firstMatch
        XCTAssertTrue(lookup.exists, "About does not name Open Food Facts")
        let privacy = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "only the barcode number")).firstMatch
        scrollTo(privacy, "About does not say what leaves the phone")
        XCTAssertFalse(app.staticTexts["Wallpaper colours"].exists, "iOS has no wallpaper colours")
        capture("settings-about")
    }
}
