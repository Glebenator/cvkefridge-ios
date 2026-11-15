import XCTest

/// A tap on a reminder, with the notifications of iOS. The other tests give the app a fixed notification permission,
/// and no notification goes to the system. This test starts the app with `CVKE_NOTIFICATIONS=system`: the app then
/// asks iOS for the permission, the debug button "Send a test reminder" of Settings sends the reminder of today, and
/// the test selects the reminder on the screen of the system.
///
/// The system calls the app on the main thread when the person selects a notification, and it must get the answer
/// of the app on the main thread. An app that answers on a different thread stops there. So the test selects a
/// reminder in each state of the app: open, in the background, and not started.
final class ReminderTapUITests: FridgeUITestCase {
    private lazy var springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    /// The reminder on the screen of the system: a banner, or a notification in the Notification Center. Its title
    /// is "4 items need attention" or "1 item needs attention".
    private var reminder: XCUIElement {
        springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "need attention", "needs attention"))
            .firstMatch
    }

    private func openSettings() {
        expect(tab("Settings"), "The tab bar has no Settings").tap()
        expect(app.navigationBars["Settings"], "Settings did not open")
    }

    /// Turns on the reminders in Settings. The first time on a simulator, the app explains the notifications, and
    /// iOS asks for the permission.
    private func turnOnReminders() {
        openSettings()
        let row = expect(app.switches["reminders_switch"], "Settings has no switch for the reminders")
        // A tap on the middle of the row does not change a switch of a form, so the tap is on the switch itself.
        let control = row.switches.firstMatch
        (control.exists ? control : row).tap()
        let explanation = app.alerts["Allow notifications"]
        if explanation.waitForExistence(timeout: 5) {
            explanation.buttons["Continue"].tap()
            expect(springboard.alerts.buttons["Allow"], "iOS did not ask for the notification permission").tap()
        }
        wait(for: row, toHaveValue: "1")
    }

    /// Selects the debug button that sends the reminder of today in about 5 seconds.
    private func sendTestReminder() {
        openSettings()
        scrollTo(app.buttons["send_test_reminder"], "Settings has no button for a test reminder").tap()
        expect(app.staticTexts["Test reminder sent"], "The app did not send the test reminder")
    }

    /// Selects the reminder when it comes. When the banner went away before the test found it, the reminder is in
    /// the Notification Center.
    private func selectReminder() {
        if !reminder.waitForExistence(timeout: 20) {
            let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0))
            top.press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.8)))
        }
        expect(reminder, "The reminder did not come").tap()
    }

    /// The app shows My Fridge with the food that is expiring or expired, in all storage areas.
    private func expectFoodThatNeedsAttention(_ state: String) {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20), "\(state): the app is not on the screen after the tap")
        expect(app.navigationBars["My Fridge"], "\(state): the tap did not open My Fridge")
        wait(for: areaTab("All"), toBeSelected: true)
        wait(for: app.switches["filter_expiring"], toHaveValue: "1")
        wait(for: app.switches["filter_expired"], toHaveValue: "1")
    }

    func testATapOnAReminderOpensMyFridgeWithTheFoodThatNeedsAttention() throws {
        launch(inventory: .sample, notifications: "system")
        expect(app.staticTexts["hero_total"], "Home does not show the number of foods")
        turnOnReminders()

        // The app is open: the reminder comes as a banner above the app.
        sendTestReminder()
        selectReminder()
        expectFoodThatNeedsAttention("With the app open")
        // The list shows the expired and the expiring food of the sample, and no fresh food.
        expect(card("sample-chicken", area: "fridge"), "My Fridge does not show the expired food")
        XCTAssertFalse(card("sample-cheddar", area: "fridge").exists, "My Fridge shows fresh food after the tap")
        // With large text, the second card is below the screen.
        scrollTo(card("sample-spinach", area: "fridge"), "My Fridge does not show the expiring food")
        capture("reminder-tap-open")

        // The app is in the background.
        sendTestReminder()
        XCUIDevice.shared.press(.home)
        selectReminder()
        expectFoodThatNeedsAttention("With the app in the background")

        // The app does not run: the tap starts it. iOS starts it with no launch arguments, so it shows the
        // inventory of the app on this simulator, and not the sample of the test.
        sendTestReminder()
        app.terminate()
        selectReminder()
        expectFoodThatNeedsAttention("With the app not started")
        capture("reminder-tap-cold-start")
    }
}
