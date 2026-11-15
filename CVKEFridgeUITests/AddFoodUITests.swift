import XCTest

/// The form that adds food, on a simulator. Each test does what a person does, and then reads the screen. The tests
/// port the cases of `InventoryChangesDeviceTest.kt` of the Android app that add food, and add the cases of the
/// corrections of the iOS app (`docs/android-parity-plan.md`, section 7: 1, 7, 14, 15, and 18).
///
/// A UI test cannot read the change log, so each test reads the result on the screens. `scan(_:)`,
/// `openMyFridge(area:)`, and `quantityOnMyFridge(of:)` have the identifiers of the scanner and of My Fridge. Change
/// them there when those screens change.
final class AddFoodUITests: FridgeUITestCase {
    /// The answer of Open Food Facts for a jar with a quantity, a category, and a storage text.
    private static let jar = "3017620422003"
    private static let jarAnswer = """
    {"status":1,"product":{"product_name":"Hazelnut spread","brands":"Ferrero","quantity":"400 g",\
    "categories_tags":["en:spreads","en:sweet-spreads"],"conservation_conditions":"Store in a cool, dry place."}}
    """

    // MARK: - The way to the form

    /// Opens the add form with the add button at the tab bar. The result is the name field.
    @discardableResult
    private func openAddForm() -> XCUIElement {
        expect(app.staticTexts["hero_total"], "Home does not show the number of foods")
        tab("Add food").tap()
        return expect(app.textFields["field_name"], "The add form did not open")
    }

    private func openMyFridge(area: String? = nil) {
        tab("My Fridge").tap()
        expect(app.navigationBars["My Fridge"], "My Fridge did not open")
        if let area {
            app.buttons["area_picker"].tap()
            expect(app.buttons[area], "The storage area \(area) is not in the list").tap()
        }
    }

    /// Opens the scanner from My Fridge and gives it a barcode, as a person who types the digits.
    private func scan(_ barcode: String) {
        if !app.textFields["field_barcode"].exists {
            expect(app.buttons["my_fridge_menu"], "My Fridge has no menu").tap()
            expect(app.buttons["menu_scan"], "The menu has no scanner").tap()
        }
        let field = expect(app.textFields["field_barcode"], "The scanner did not open")
        field.tap()
        field.typeText(barcode)
        app.buttons["look_up"].tap()
    }

    // MARK: - Parts of the form

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Replaces the text of a text field. The tap is at the end of the field, so that the cursor is after the text.
    private func replaceText(of field: XCUIElement, with text: String) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.995, dy: 0.5)).tap()
        let old = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + text)
    }

    /// Closes a question of the system with no answer: a tap out of it. The system shows no "Keep editing" button
    /// on an iPhone.
    private func closeQuestion() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.45)).tap()
    }

    /// Closes the keyboard with its "Done" button. A swipe from the centre of the screen then scrolls the form: with
    /// the keyboard open, the centre of the screen is the bar with the buttons.
    private func hideKeyboard() {
        let done = app.toolbars.buttons["Done"]
        if done.exists {
            done.tap()
        }
    }

    /// Selects a value of a menu of the form.
    private func select(_ option: String, in field: String) {
        hideKeyboard()
        scrollTo(element(field), "The form has no \(field)").tap()
        expect(app.buttons[option], "The menu has no \(option)").tap()
    }

    /// Waits until the name field is empty: the form started the next food. An empty text field has its placeholder
    /// as its value.
    private func waitForEmptyName(_ name: XCUIElement) {
        let empty = NSPredicate(format: "value == nil OR value == '' OR value == 'Name'")
        wait(for: [expectation(for: empty, evaluatedWith: name)], timeout: 10)
    }

    /// Waits until the text field has the keyboard, and fails the test with the message when it does not get it.
    private func waitForKeyboard(in field: XCUIElement, _ message: String) {
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        let result = XCTWaiter.wait(for: [expectation(for: focused, evaluatedWith: field)], timeout: 10)
        XCTAssertEqual(result, .completed, message)
    }

    private func hasKeyboardFocus(_ field: XCUIElement) -> Bool {
        (field.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }

    /// Scrolls the form down until the element is on the screen: the element is above the visible part.
    @discardableResult
    private func scrollBackTo(_ element: XCUIElement, _ message: String) -> XCUIElement {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < 6 {
            app.swipeDown(velocity: .slow)
            swipes += 1
        }
        XCTAssertTrue(element.exists && element.isHittable, message)
        return element
    }

    private func waitForLabel(_ element: XCUIElement, contains text: String, _ message: String) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let result = XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 10)
        XCTAssertEqual(result, .completed, "\(message): \(element.exists ? element.label : "no element")")
    }

    /// The quantity in the row of a food on My Fridge, for example "4 l • Expires tomorrow".
    private func rowOnMyFridge(of productId: String) -> XCUIElement {
        scrollTo(app.buttons["food_\(productId)"], "My Fridge does not show the food \(productId)")
    }

    // MARK: - Add by hand

    /// Port of `aFoodThatIsAddedByHandIsOnMyFridgeAndOnHome`.
    func testAFoodThatIsAddedByHandIsOnMyFridgeAndOnHome() throws {
        launch(inventory: .empty)
        let name = openAddForm()
        // An empty form starts with the keyboard in the name field.
        waitForKeyboard(in: name, "The name field does not have the keyboard")

        // A name with no food in the table has no estimate. "Save and add another" keeps the form open.
        name.typeText("Rice")
        XCTAssertTrue(element("field_expiry").label.contains("No expiry date"), "A food with no estimate has a date")
        app.buttons["save_another"].tap()
        expect(app.staticTexts["Rice added"], "The message of the add did not show")
        waitForEmptyName(name)
        waitForKeyboard(in: name, "The name field of the next food does not have the keyboard")

        // A food of the table gives its category and an estimated date.
        name.typeText("but")
        expect(app.buttons["suggestion_food_fk-1"], "The form does not suggest Butter").tap()
        XCTAssertEqual(name.value as? String, "Butter")
        XCTAssertTrue(element("field_category").label.contains("Dairy"), "Butter did not give its category")
        waitForLabel(element("field_expiry"), contains: "estimated", "Butter has no estimated date")
        // The date is 30 days after the fixed date of the test, and it is not today.
        XCTAssertTrue(element("field_expiry").label.contains("Dec 14, 2026"), element("field_expiry").label)
        capture("add-food-butter")
        replaceText(of: app.textFields["field_quantity"], with: "2")
        hideKeyboard()
        let note = scrollTo(element("field_note"), "The form has no note field")
        note.tap()
        note.typeText("For the cake")
        app.buttons["save"].tap()

        // The form closes. Home has the two foods, and My Fridge shows them.
        expect(app.staticTexts["Butter added"], "The message of the add did not show")
        XCTAssertFalse(name.exists, "The form did not close")
        XCTAssertEqual(app.staticTexts["hero_total"].label, "2")
        openMyFridge()
        expect(app.staticTexts["Butter"], "My Fridge does not show Butter")
        XCTAssertTrue(app.staticTexts["Rice"].exists, "My Fridge does not show Rice")
        let butter = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "2 pcs")).firstMatch
        XCTAssertTrue(butter.exists, "Butter does not have 2 pcs")
        XCTAssertTrue(butter.label.contains("estimated"), "The batch of Butter is not an estimate: \(butter.label)")
    }

    /// Port of `aFoodOfTheTableGoesToAnAreaOfItsUsualStorageKind`.
    func testAFoodOfTheTableGoesToAnAreaOfItsUsualStorageKind() throws {
        launch(inventory: .empty)
        let name = openAddForm()

        // The person puts the first food in the freezer. The next form starts in the freezer.
        name.typeText("Rice")
        select("area_option_freezer", in: "field_area")
        app.buttons["save_another"].tap()
        expect(app.staticTexts["Rice added"], "The message of the add did not show")
        waitForEmptyName(name)
        XCTAssertEqual(element("field_area").value as? String, "Freezer")

        // Butter is usually kept in the fridge.
        name.typeText("but")
        expect(app.buttons["suggestion_food_fk-1"], "The form does not suggest Butter").tap()
        XCTAssertEqual(element("field_area").value as? String, "Fridge")
        // The storage tips have the general advice of the table of foods for butter, and no text of a package.
        let general = scrollTo(element("storage_advice_general"), "The form has no storage tips")
        XCTAssertEqual(general.label, "General advice for Butter")
        XCTAssertTrue(element("storage_advice_fridge").label.contains("About 1 month."), element("storage_advice_fridge").label)
        XCTAssertFalse(element("storage_advice_package").exists, "A food with no package has a text of a package")
        capture("add-food-storage-tips")
        app.buttons["save"].tap()
        expect(app.staticTexts["Butter added"], "The message of the add did not show")

        // Rice is in the freezer, and Butter is in the fridge.
        openMyFridge()
        expect(app.staticTexts["Butter"], "Butter is not in the fridge")
        XCTAssertFalse(app.staticTexts["Rice"].exists, "Rice is in the fridge")
        openMyFridge(area: "Freezer")
        expect(app.staticTexts["Rice"], "Rice is not in the freezer")
    }

    /// Correction 7: after the person selected "Chicken", a longer name does not keep the estimate of raw chicken.
    func testALongerNameDoesNotKeepTheEstimateOfTheFirstFood() throws {
        launch(inventory: .empty)
        let name = openAddForm()
        name.typeText("chicken")
        expect(app.buttons["suggestion_food_fk-113"], "The form does not suggest Chicken").tap()
        XCTAssertEqual(name.value as? String, "Chicken")
        waitForLabel(element("field_expiry"), contains: "Nov 15, 2026, estimated", "Chicken has no estimate of 1 day")

        name.tap()
        name.typeText(" stew")
        waitForLabel(element("field_expiry"), contains: "No expiry date", "Chicken stew kept the estimate of raw chicken")
    }

    // MARK: - Food that the person had before

    func testARecentFoodFillsInTheFormAndAFoodCanLeaveTheList() throws {
        launch(inventory: .sample)
        let name = openAddForm()

        // An empty name shows the foods that the person added, used, or threw away last.
        expect(app.staticTexts["suggestions_recent"], "The empty name field does not show the recent foods")
        let juice = app.buttons["suggestion_product_sample-juice"]
        let bananas = app.buttons["suggestion_product_sample-bananas"]
        XCTAssertEqual(juice.value as? String, "In your inventory")
        XCTAssertEqual(bananas.value as? String, "You had this before")
        capture("add-food-recent")

        // A food leaves the list with its button.
        app.buttons["recent_remove_sample-juice"].tap()
        XCTAssertTrue(juice.waitForNonExistence(timeout: 5), "The food stayed in the list")

        // A recent food gets its usual quantity and the storage area of its newest batch. The form is short: the
        // category and the unit are those of the food.
        bananas.tap()
        XCTAssertEqual(name.value as? String, "Bananas")
        let existing = expect(element("name_existing"), "The form does not say that it adds a batch")
        XCTAssertEqual(existing.label, "You had this food before. The form adds a new batch to it.")
        XCTAssertEqual(app.textFields["field_quantity"].value as? String, "6")
        XCTAssertTrue(app.staticTexts["pcs"].exists, "The form does not show the unit of the food")
        XCTAssertFalse(element("field_category").exists, "The short form has a category")
        XCTAssertFalse(element("field_unit").exists, "The short form has a unit menu")
        XCTAssertEqual(element("field_area").value as? String, "Fridge")
        waitForLabel(element("field_expiry"), contains: "estimated", "Bananas have no estimated date")
        capture("add-food-again")
        app.buttons["save"].tap()
        expect(app.staticTexts["Bananas added"], "The message of the add did not show")
        XCTAssertEqual(app.staticTexts["hero_total"].label, "13")
    }

    func testANameOfAFoodInTheInventoryAddsABatchToIt() throws {
        launch(inventory: .sample)
        let name = openAddForm()
        name.typeText("whole")
        let milk = expect(app.buttons["suggestion_product_sample-milk"], "The form does not suggest the milk of the inventory")
        XCTAssertEqual(milk.value as? String, "In your inventory")
        capture("add-food-suggestions")
        milk.tap()

        // The form has the note of the food, its usual quantity, and its unit.
        let existing = expect(element("name_existing"), "The form does not say that it adds a batch")
        XCTAssertEqual(existing.label, "This food is in your inventory. The form adds a batch to it.")
        XCTAssertEqual(app.textFields["field_quantity"].value as? String, "1")
        XCTAssertEqual(scrollTo(element("field_note"), "The form has no note field").value as? String, "Opened on Tuesday")
        app.buttons["save"].tap()

        // The food count stays, and the milk has one more litre.
        expect(app.staticTexts["Whole milk added"], "The message of the add did not show")
        XCTAssertEqual(app.staticTexts["hero_total"].label, "12")
        openMyFridge()
        let row = rowOnMyFridge(of: "sample-milk")
        XCTAssertTrue(row.label.contains("4 l"), "The milk does not have 4 l: \(row.label)")
    }

    /// Correction 18: the form starts in the storage area that My Fridge shows.
    func testTheFormStartsInTheStorageAreaOfTheOpenTab() throws {
        launch(inventory: .sample)
        expect(app.staticTexts["hero_total"], "Home does not show the number of foods")
        openMyFridge(area: "Freezer")
        tab("Add food").tap()
        expect(app.textFields["field_name"], "The add form did not open")
        XCTAssertEqual(element("field_area").value as? String, "Freezer")
    }

    // MARK: - Problems

    /// Correction 14: two fast taps on "Save" add one batch. A form with a problem saves nothing.
    func testAFormWithAProblemSavesNothingAndTwoTapsAddOneBatch() throws {
        launch(inventory: .sample)
        let name = openAddForm()
        waitForKeyboard(in: name, "The name field does not have the keyboard")

        // Before the first key, the bar of the keyboard covers a part of the buttons of the form (a defect of the
        // shared form frame), so the keyboard closes first.
        hideKeyboard()
        app.buttons["save"].tap()
        let nameProblem = expect(app.staticTexts["error_name"], "The form did not show the problem of the name")
        XCTAssertEqual(nameProblem.label, "Enter a name.")
        XCTAssertTrue(name.exists, "The form closed with no name")

        name.tap()
        name.typeText("Kiwi")
        replaceText(of: app.textFields["field_quantity"], with: "0")
        app.buttons["save"].tap()
        let quantityProblem = expect(app.staticTexts["error_quantity"], "The form did not show the problem of the quantity")
        XCTAssertEqual(quantityProblem.label, "Enter a quantity above 0.")
        capture("add-food-problems")

        replaceText(of: app.textFields["field_quantity"], with: "3")
        app.buttons["save"].doubleTap()
        expect(app.staticTexts["Kiwi added"], "The message of the add did not show")
        XCTAssertEqual(app.staticTexts["hero_total"].label, "13")
        openMyFridge()
        let kiwi = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "3 pcs")).firstMatch
        XCTAssertTrue(kiwi.exists, "Kiwi does not have 3 pcs: two taps added two batches, or none")
    }

    // MARK: - The scanner

    func testTheScanCardOpensTheScannerAndAsksBeforeItDropsAChangedForm() throws {
        launch(inventory: .sample)
        let name = openAddForm()

        // A changed form asks first.
        name.typeText("Plum")
        hideKeyboard()
        scrollBackTo(app.buttons["name_scan"], "The empty form has no scan card").tap()
        expect(app.buttons["Discard changes"], "The changed form did not ask before it opened the scanner")
        closeQuestion()
        XCTAssertTrue(app.buttons["Discard changes"].waitForNonExistence(timeout: 5), "The question did not close")
        XCTAssertEqual(name.value as? String, "Plum")

        scrollBackTo(app.buttons["name_scan"], "The empty form has no scan card").tap()
        expect(app.buttons["Discard changes"], "The changed form did not ask before it opened the scanner").tap()
        expect(app.buttons["scan_add_by_hand"], "The scanner did not open")
        XCTAssertFalse(name.exists, "The form stayed open below the scanner")

        // A form that the scanner opened goes back to the scanner. It has no question when it is not changed.
        app.buttons["scan_add_by_hand"].tap()
        expect(app.textFields["field_name"], "The add form did not open above the scanner")
        app.buttons["name_scan"].tap()
        expect(app.buttons["scan_add_by_hand"], "The scanner did not show again")
        XCTAssertTrue(app.textFields["field_name"].waitForNonExistence(timeout: 5), "The form stayed above the scanner")
    }

    func testAFormAfterAScanHasTheValuesOfTheLookupAndSaveAndScanNextShowsTheScannerAgain() throws {
        launch(inventory: .sample, lookups: [Self.jar: .response(body: Self.jarAnswer)])
        expect(app.staticTexts["hero_total"], "Home does not show the number of foods")
        openMyFridge()
        scan(Self.jar)

        // The form says where the values come from, and shows the barcode that the food keeps.
        let name = expect(app.textFields["field_name"], "The add form did not open after the scan")
        let note = expect(element("scan_note"), "The form does not say where its values come from")
        XCTAssertTrue(note.label.hasPrefix("From Open Food Facts. Check the values before you save."), note.label)
        XCTAssertTrue(note.label.contains(Self.jar), "The form does not show the barcode: \(note.label)")
        XCTAssertTrue((name.value as? String ?? "").contains("Hazelnut spread"), "The form does not have the name of the lookup")
        XCTAssertFalse(hasKeyboardFocus(name), "A form with a name from the lookup opened the keyboard")
        XCTAssertEqual(app.textFields["field_quantity"].value as? String, "400")
        XCTAssertTrue(element("field_unit").label.hasSuffix("g"), element("field_unit").label)
        XCTAssertFalse(app.buttons["name_scan"].exists, "A form after a scan has the scan card")
        XCTAssertFalse(app.staticTexts["suggestions_recent"].exists, "A form after a scan shows the recent foods")
        // The storage tips have the text of the package.
        let package = scrollTo(element("storage_advice_package"), "The form does not show the text of the package")
        XCTAssertEqual(package.label, "Store in a cool, dry place.")
        capture("add-food-after-scan")

        // "Save and scan next" saves, and shows the scanner again.
        app.buttons["save_scan_next"].tap()
        expect(app.buttons["scan_add_by_hand"], "The scanner did not show again")
        XCTAssertTrue(name.waitForNonExistence(timeout: 5), "The form stayed above the scanner")
        let added = NSPredicate(format: "label ENDSWITH %@", "Hazelnut spread added")
        expect(app.staticTexts.matching(added).firstMatch, "The message of the add did not show above the scanner")
    }

    func testABarcodeWithNoProductGivesAnEmptyNameWithTheKeyboard() throws {
        launch(inventory: .sample, lookups: [Self.jar: .response(body: #"{"status":0}"#)])
        expect(app.staticTexts["hero_total"], "Home does not show the number of foods")
        openMyFridge()
        scan(Self.jar)

        let name = expect(app.textFields["field_name"], "The add form did not open after the scan")
        let note = expect(element("scan_note"), "The form does not say that the barcode has no product")
        XCTAssertTrue(note.label.hasPrefix("Open Food Facts has no product with this barcode. Type the name."), note.label)
        waitForKeyboard(in: name, "The empty name field does not have the keyboard")
        XCTAssertFalse(app.staticTexts["suggestions_recent"].exists, "A form after a scan shows the recent foods")

        // "Save" closes the form and the scanner below it.
        name.typeText("Quince jam")
        app.buttons["save"].tap()
        expect(app.staticTexts["Quince jam added"], "The message of the add did not show")
        expect(app.buttons["area_picker"], "The form and the scanner did not close")
    }

    /// Correction 1: a scan of a barcode that the inventory has gets the values of "Add again". In the Android app
    /// the form has a quantity of 1 in the last used storage area.
    func testAScanOfAFoodInTheInventoryGetsItsUsualQuantityAndItsStorageArea() throws {
        let log = """
        {"id":"c-1","at":1,"origin":"phone-1","body":{"type":"productSaved","product":{"id":"p-1","name":"Garden peas","category":"produce","unit":"g","barcode":"\(Self.jar)","foodId":null}}}
        {"id":"c-2","at":2,"origin":"phone-1","body":{"type":"batchAdded","batch":{"id":"b-1","productId":"p-1","quantity":500000,"storageAreaId":"freezer","dateAdded":"2026-11-10","expiryDate":null,"expirySource":null}}}

        """
        launch(inventory: .changeLog(log))
        expect(app.staticTexts["hero_total"], "The inventory did not load")
        openMyFridge()
        scan(Self.jar)

        let name = expect(app.textFields["field_name"], "The add form did not open after the scan")
        XCTAssertEqual(name.value as? String, "Garden peas")
        let existing = expect(element("name_existing"), "The form does not say that it adds a batch")
        XCTAssertEqual(existing.label, "This food is in your inventory. The form adds a batch to it.")
        XCTAssertFalse(element("scan_note").exists, "A food of the inventory has a note of the lookup")
        XCTAssertEqual(app.textFields["field_quantity"].value as? String, "500")
        XCTAssertEqual(element("field_area").value as? String, "Freezer")

        app.buttons["save_scan_next"].tap()
        expect(app.buttons["scan_add_by_hand"], "The scanner did not show again")
        expect(app.buttons["scan_close"], "The scanner has no close button").tap()
        openMyFridge(area: "Freezer")
        let row = rowOnMyFridge(of: "p-1")
        XCTAssertTrue(row.label.contains("1,000 g"), "The peas do not have two batches of 500 g: \(row.label)")
    }
}
