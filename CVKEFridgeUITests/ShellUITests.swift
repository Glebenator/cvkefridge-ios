import XCTest

/// The shell of the app on a simulator, with the sample inventory: the tabs, the add button at the tab bar, a sheet,
/// and a message with "Undo". The captures are attachments, so CI can show the real screens.
final class ShellUITests: FridgeUITestCase {
    /// The sample has 12 foods with a batch.
    private static let sampleFoods = "12"

    func test1TabsAndTotals() throws {
        launch(inventory: .sample)

        // Home is the first tab, and it shows the totals of the sample.
        expect(app.staticTexts["hero_total"], "Home does not show the number of foods")
        XCTAssertEqual(app.staticTexts["hero_total"].label, Self.sampleFoods)
        XCTAssertTrue(app.staticTexts["sample_note"].exists, "The sample is not marked as a sample")
        for name in ["Home", "My Fridge", "History", "Settings", "Add food"] {
            XCTAssertTrue(tab(name).exists, "The tab bar has no \(name)")
        }
        XCTAssertTrue(tab("Home").isSelected)
        capture("shell-home")

        tab("My Fridge").tap()
        expect(app.navigationBars["My Fridge"], "My Fridge did not open")
        XCTAssertTrue(tab("My Fridge").isSelected)
        capture("shell-my-fridge")

        tab("History").tap()
        expect(app.navigationBars["History"], "History did not open")

        tab("Settings").tap()
        expect(app.navigationBars["Settings"], "Settings did not open")
        let version = scrollTo(app.staticTexts["about_version"], "Settings does not show the version")
        XCTAssertEqual(version.label, "0.1.0 (1)")
    }

    func test2AddButtonOpensTheFormAndTheMessageHasUndo() throws {
        launch(inventory: .sample)
        expect(app.staticTexts["hero_total"], "Home does not show the number of foods")

        // The add button opens the form as a sheet. It does not become the selected tab.
        tab("Add food").tap()
        let name = expect(app.textFields["field_name"], "The add form did not open")
        XCTAssertTrue(tab("Home").isSelected || !tab("Home").isHittable, "The add button changed the selected tab")
        name.tap()
        name.typeText("Kiwi")
        capture("shell-add-food")
        app.buttons["save"].tap()

        // The form closes, and the message with "Undo" shows above the tab bar.
        expect(app.staticTexts["Kiwi added"], "The message of the add did not show")
        let undo = expect(app.buttons["Undo"], "The message has no Undo")
        XCTAssertFalse(app.textFields["field_name"].exists, "The form did not close")
        XCTAssertEqual(app.staticTexts["hero_total"].label, "13")
        capture("shell-notice-undo")

        undo.tap()
        let total = app.staticTexts["hero_total"]
        let back = NSPredicate(format: "label == %@", Self.sampleFoods)
        wait(for: [expectation(for: back, evaluatedWith: total)], timeout: 10)
        XCTAssertFalse(app.staticTexts["Kiwi added"].exists, "The message did not close after Undo")
        XCTAssertTrue(tab("Home").isSelected)
    }

    func test3ALineThatIsNotAChangeDoesNotStopTheApp() throws {
        // One change that the app can read, and one line that is not a change.
        let log = """
        {"id":"c-1","at":1,"origin":"phone-1","body":{"type":"productSaved","product":{"id":"p-1","name":"Butter","category":"dairy","unit":"g","barcode":null,"foodId":null}}}
        this line is not a change
        {"id":"c-2","at":2,"origin":"phone-1","body":{"type":"batchAdded","batch":{"id":"b-1","productId":"p-1","quantity":250000,"storageAreaId":"fridge","dateAdded":"2026-11-10","expiryDate":null,"expirySource":null}}}

        """
        launch(inventory: .changeLog(log))

        expect(app.staticTexts["hero_total"], "The inventory did not load")
        XCTAssertEqual(app.staticTexts["hero_total"].label, "1")
        let message = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "1 change in the inventory file")).firstMatch
        expect(message, "The app did not say that it did not read a line")
    }

    func test4MyFridgeStartsAgainAndTheStackGoesBack() throws {
        launch(inventory: .sample)

        // A count of Home opens My Fridge with all storage areas.
        expect(app.buttons["metric_expired"], "Home does not show the expired food").tap()
        expect(app.navigationBars["My Fridge"], "My Fridge did not open")
        XCTAssertTrue(areaTab("All").isSelected, "The count of Home did not show all storage areas")

        // A tap on the selected tab starts My Fridge again: the Fridge, with no filter.
        tab("My Fridge").tap()
        wait(for: areaTab("Fridge"), toBeSelected: true)

        // A food opens in the stack of the tab, and a tap on the tab goes back to the first screen.
        scrollTo(app.buttons["food_sample-cheddar/fridge"], "My Fridge does not show the food").tap()
        expect(app.staticTexts["food_name"], "The food did not open")
        capture("shell-food")
        tab("My Fridge").tap()
        expect(areaTab("Fridge"), "The tab did not go back to its first screen")
    }

    func test5TheMessageShowsAboveASheetAndAChangedFormAsksBeforeItCloses() throws {
        launch(inventory: .sample)
        expect(app.staticTexts["hero_total"], "Home does not show the number of foods")
        tab("Add food").tap()
        let name = expect(app.textFields["field_name"], "The add form did not open")
        name.tap()
        name.typeText("Kiwi")
        app.buttons["save_another"].tap()

        // The form stays open for the next food, and the message shows above its buttons.
        expect(app.staticTexts["Kiwi added"], "The message did not show above the form")
        XCTAssertTrue(name.exists, "The form closed after Save and add another")
        capture("shell-notice-above-sheet")

        // An empty form closes with no question. A changed form asks first.
        name.tap()
        name.typeText("Plum")
        app.buttons["form_close"].tap()
        expect(app.buttons["Discard changes"], "The changed form did not ask before it closed")
        capture("shell-discard")
        app.buttons["Discard changes"].tap()
        expect(app.staticTexts["hero_total"], "The form did not close")
        XCTAssertEqual(app.staticTexts["hero_total"].label, "13")
    }

    func test6TheScannerCoversTheWindowAndSaveClosesTheFormAndTheScanner() throws {
        launch(inventory: .sample)
        expect(app.staticTexts["hero_total"], "Home does not show the number of foods")
        tab("My Fridge").tap()
        expect(app.buttons["my_fridge_menu"], "My Fridge has no menu").tap()
        expect(app.buttons["menu_scan"], "The menu has no scanner").tap()

        // The add form opens above the scanner. "Save" closes the two.
        expect(app.buttons["scan_add_by_hand"], "The scanner did not open").tap()
        let name = expect(app.textFields["field_name"], "The add form did not open above the scanner")
        name.tap()
        name.typeText("Pear")
        app.buttons["save"].tap()
        expect(app.staticTexts["Pear added"], "The message of the add did not show")
        expect(areaTab("Fridge"), "The form and the scanner did not close")
        XCTAssertFalse(app.buttons["scan_add_by_hand"].exists, "The scanner stayed open after Save")
    }
}
