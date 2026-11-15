import XCTest

/// The form that adds food, on a simulator. Each test does what a person does, and then reads the screen. The tests
/// port the cases of `InventoryChangesDeviceTest.kt` of the Android app that add food, and add the cases of the
/// corrections of the iOS app (`docs/android-parity-plan.md`, section 7: 1, 7, 14, 15, and 18).
///
/// A UI test cannot read the change log, so each test reads the result on the screens. `FridgeUITestCase` has the
/// ways to My Fridge, to the card of a food, and to the scanner.
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

    /// Opens the scanner from My Fridge and gives it a barcode, as a person who types the digits.
    private func scan(_ barcode: String) {
        if !app.buttons["type_barcode"].exists {
            openScanner()
        }
        typeBarcode(barcode)
    }

    // MARK: - Parts of the form

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

    /// What the card of a food on My Fridge says after the name, for example "Expires tomorrow, 4 l, Dairy".
    private func cardOnMyFridge(of productId: String) -> String {
        value(of: scrollTo(card(productId), "My Fridge does not show the food \(productId)"))
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
        XCTAssertTrue(scrolledTo("field_expiry").label.contains("No expiry date"), "A food with no estimate has a date")
        app.buttons["save_another"].tap()
        expect(app.staticTexts["Rice added"], "The message of the add did not show")
        waitForEmptyName(name)
        waitForKeyboard(in: name, "The name field of the next food does not have the keyboard")

        // A food of the table gives its category and an estimated date.
        name.typeText("but")
        expect(app.buttons["suggestion_food_fk-1"], "The form does not suggest Butter").tap()
        XCTAssertEqual(scrollBackTo(name, "The name field is not on the screen").value as? String, "Butter")
        XCTAssertTrue(scrolledTo("field_category").label.contains("Dairy"), "Butter did not give its category")
        wait(for: scrolledTo("field_expiry"), toHaveLabelWith: "estimated")
        // The date is 30 days after the fixed date of the test, and it is not today.
        XCTAssertTrue(scrolledTo("field_expiry").label.contains("Dec 14, 2026"), scrolledTo("field_expiry").label)
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
        let butter = value(of: expect(card(named: "Butter"), "My Fridge does not show Butter"))
        XCTAssertTrue(card(named: "Rice").exists, "My Fridge does not show Rice")
        XCTAssertTrue(butter.contains("2 pcs"), "Butter does not have 2 pcs: \(butter)")
        XCTAssertTrue(butter.contains("estimated"), "The batch of Butter is not an estimate: \(butter)")
        // The note of the food is on its card.
        XCTAssertTrue(butter.contains("For the cake"), "The card of Butter does not show the note: \(butter)")
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
        XCTAssertEqual(scrolledTo("field_area").value as? String, "Freezer")

        // Butter is usually kept in the fridge.
        name.typeText("but")
        expect(app.buttons["suggestion_food_fk-1"], "The form does not suggest Butter").tap()
        XCTAssertEqual(scrolledTo("field_area").value as? String, "Fridge")
        // The storage tips have the general advice of the table of foods for butter, and no text of a package.
        let general = scrollTo(element("storage_advice_general"), "The form has no storage tips")
        XCTAssertEqual(general.label, "General advice for Butter")
        XCTAssertTrue(scrolledTo("storage_advice_fridge").label.contains("About 1 month."), scrolledTo("storage_advice_fridge").label)
        XCTAssertFalse(element("storage_advice_package").exists, "A food with no package has a text of a package")
        capture("add-food-storage-tips")
        app.buttons["save"].tap()
        expect(app.staticTexts["Butter added"], "The message of the add did not show")

        // Rice is in the freezer, and Butter is in the fridge.
        openMyFridge()
        expect(card(named: "Butter"), "Butter is not in the fridge")
        XCTAssertFalse(card(named: "Rice").exists, "Rice is in the fridge")
        openMyFridge(area: "Freezer")
        expect(card(named: "Rice"), "Rice is not in the freezer")
        XCTAssertFalse(card(named: "Butter").exists, "Butter is in the freezer")
    }

    /// Correction 7: after the person selected "Chicken", a longer name does not keep the estimate of raw chicken.
    func testALongerNameDoesNotKeepTheEstimateOfTheFirstFood() throws {
        launch(inventory: .empty)
        let name = openAddForm()
        name.typeText("chicken")
        expect(app.buttons["suggestion_food_fk-113"], "The form does not suggest Chicken").tap()
        XCTAssertEqual(scrollBackTo(name, "The name field is not on the screen").value as? String, "Chicken")
        wait(for: scrolledTo("field_expiry"), toHaveLabelWith: "Nov 15, 2026, estimated")

        scrollBackTo(name, "The name field is not on the screen").tap()
        name.typeText(" stew")
        wait(for: scrolledTo("field_expiry"), toHaveLabelWith: "No expiry date")
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
        XCTAssertEqual(scrollBackTo(name, "The name field is not on the screen").value as? String, "Bananas")
        let existing = scrollTo(element("name_existing"), "The form does not say that it adds a batch")
        XCTAssertEqual(existing.label, "You had this food before. The form adds a new batch to it.")
        XCTAssertEqual(scrolledTo("field_quantity").value as? String, "6")
        XCTAssertTrue(app.staticTexts["pcs"].exists, "The form does not show the unit of the food")
        XCTAssertFalse(element("field_category").exists, "The short form has a category")
        XCTAssertFalse(element("field_unit").exists, "The short form has a unit menu")
        XCTAssertEqual(scrolledTo("field_area").value as? String, "Fridge")
        wait(for: scrolledTo("field_expiry"), toHaveLabelWith: "estimated")
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
        let existing = scrollTo(element("name_existing"), "The form does not say that it adds a batch")
        XCTAssertEqual(existing.label, "This food is in your inventory. The form adds a batch to it.")
        XCTAssertEqual(scrolledTo("field_quantity").value as? String, "1")
        XCTAssertEqual(scrollTo(element("field_note"), "The form has no note field").value as? String, "Opened on Tuesday")
        app.buttons["save"].tap()

        // The food count stays, and the milk has one more litre.
        expect(app.staticTexts["Whole milk added"], "The message of the add did not show")
        XCTAssertEqual(app.staticTexts["hero_total"].label, "12")
        openMyFridge()
        let card = cardOnMyFridge(of: "sample-milk")
        XCTAssertTrue(card.contains("4 l"), "The milk does not have 4 l: \(card)")
    }

    /// Correction 18: the form starts in the storage area that My Fridge shows.
    func testTheFormStartsInTheStorageAreaOfTheOpenTab() throws {
        launch(inventory: .sample)
        expect(app.staticTexts["hero_total"], "Home does not show the number of foods")
        openMyFridge(area: "Freezer")
        tab("Add food").tap()
        expect(app.textFields["field_name"], "The add form did not open")
        XCTAssertEqual(scrolledTo("field_area").value as? String, "Freezer")
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
        let kiwi = value(of: scrollTo(card(named: "Kiwi"), "My Fridge does not show Kiwi"))
        XCTAssertTrue(kiwi.contains("3 pcs"), "Kiwi does not have 3 pcs: two taps added two batches, or none: \(kiwi)")
    }

    // MARK: - The photo

    /// A new food gets the photo of its form. The card of My Fridge and the screen of the food show it. The picture
    /// comes from the built-in pictures of the debug build, in the place of the photo picker of the system.
    func testANewFoodIsSavedWithThePhotoOfTheForm() throws {
        launch(inventory: .empty, arguments: ["-uiTestPicture", "photo"])
        let name = openAddForm()
        name.typeText("Papaya")
        hideKeyboard()

        // The photo is the last section of the form. "Choose a photo" makes the photo at once, and the form shows it.
        scrollTo(app.buttons["photo_choose"], "The form has no Choose a photo").tap()
        expect(element("form_photo_image"), "The form does not show its photo")
        XCTAssertTrue(app.buttons["photo_change"].exists, "A form with a photo has no Change photo")
        XCTAssertFalse(app.buttons["photo_choose"].exists, "A form with a photo has Choose a photo")

        // "Remove photo" drops the photo of the form, and the form has the two sources again.
        scrollTo(app.buttons["photo_remove"], "A form with a photo has no Remove photo").tap()
        waitToGo(element("form_photo_image"), "The removed photo still shows in the form")
        scrollTo(app.buttons["photo_choose"], "The form has no Choose a photo after the remove").tap()
        expect(element("form_photo_image"), "The form does not show its second photo")
        capture("add-food-photo")
        app.buttons["save"].tap()
        expect(app.staticTexts["Papaya added"], "The message of the add did not show")
        XCTAssertFalse(name.exists, "The form did not close")

        // The card of My Fridge shows the photo: the value of the picture is the name of the photo file.
        openMyFridge()
        let papaya = expect(card(named: "Papaya"), "My Fridge does not show the new food")
        let productId = String(papaya.identifier.dropFirst("food_".count).prefix { $0 != "/" })
        XCTAssertFalse(productId.isEmpty, "The card has no identifier of its food: \(papaya.identifier)")
        let onCard = element("product_image_\(productId)")
        wait(for: onCard, toMatch: NSPredicate(format: "value BEGINSWITH %@", productId + "."), "The card of My Fridge does not show the photo")
        capture("add-food-photo-card")

        // The screen of the food shows the photo above the name, with "Change photo" and "Remove photo".
        papaya.tap()
        let title = expect(app.staticTexts["food_name"], "The screen of the food did not open")
        let photo = expect(element("food_photo"), "The screen of the food does not show the photo")
        XCTAssertEqual(photo.label, "Photo of Papaya")
        XCTAssertLessThan(photo.frame.minY, title.frame.minY, "The photo is not above the name")
        XCTAssertTrue(app.buttons["photo_change"].exists, "A food with a photo has no Change photo")
        XCTAssertTrue(app.buttons["photo_remove"].exists, "A food with a photo has no Remove photo")
        capture("add-food-photo-food")
    }

    // MARK: - The scanner

    func testTheScanCardOpensTheScannerAndAsksBeforeItDropsAChangedForm() throws {
        launch(inventory: .sample)
        let name = openAddForm()

        // A changed form asks first.
        name.typeText("Plum")
        hideKeyboard()
        scrollBackTo(app.buttons["name_scan"], "The empty form has no scan card").tap()
        closeQuestion(with: expect(app.buttons["Discard changes"], "The changed form did not ask before it opened the scanner"))
        XCTAssertTrue(app.buttons["Discard changes"].waitForNonExistence(timeout: 5), "The question did not close")
        XCTAssertEqual(scrollBackTo(name, "The name field is not on the screen").value as? String, "Plum")

        scrollBackTo(app.buttons["name_scan"], "The empty form has no scan card").tap()
        expect(app.buttons["Discard changes"], "The changed form did not ask before it opened the scanner").tap()
        expect(app.buttons["scan_add_by_hand"], "The scanner did not open")
        XCTAssertFalse(name.exists, "The form stayed open below the scanner")

        // A form that the scanner opened goes back to the scanner. It has no question when it is not changed.
        app.buttons["scan_add_by_hand"].tap()
        expect(app.textFields["field_name"], "The add form did not open above the scanner")
        app.buttons["name_scan"].tap()
        expect(app.buttons["scan_add_by_hand"], "The scanner did not show again")
        waitToGo(app.navigationBars["Add food"], "The form stayed above the scanner")
    }

    func testAFormAfterAScanHasTheValuesOfTheLookupAndSaveAndScanNextShowsTheScannerAgain() throws {
        launch(inventory: .sample, lookups: [Self.jar: .response(body: Self.jarAnswer)])
        expect(app.staticTexts["hero_total"], "Home does not show the number of foods")
        openMyFridge()
        scan(Self.jar)

        // The form says where the values come from, and shows the barcode that the food keeps.
        let name = expectAddForm("The add form did not open after the scan")
        XCTAssertTrue((name.value as? String ?? "").contains("Hazelnut spread"), "The form does not have the name of the lookup")
        XCTAssertFalse(hasKeyboardFocus(name), "A form with a name from the lookup opened the keyboard")
        let note = scrollBackTo(element("scan_note"), "The form does not say where its values come from")
        XCTAssertTrue(note.label.hasPrefix("From Open Food Facts. Check the values before you save."), note.label)
        XCTAssertTrue(note.label.contains(Self.jar), "The form does not show the barcode: \(note.label)")
        XCTAssertEqual(scrolledTo("field_quantity").value as? String, "400")
        XCTAssertTrue(scrolledTo("field_unit").label.hasSuffix("g"), scrolledTo("field_unit").label)
        XCTAssertFalse(app.buttons["name_scan"].exists, "A form after a scan has the scan card")
        XCTAssertFalse(app.staticTexts["suggestions_recent"].exists, "A form after a scan shows the recent foods")
        // The storage tips have the text of the package.
        let package = scrollTo(element("storage_advice_package"), "The form does not show the text of the package")
        XCTAssertEqual(package.label, "Store in a cool, dry place.")
        capture("add-food-after-scan")

        // "Save and scan next" saves, and shows the scanner again.
        app.buttons["save_scan_next"].tap()
        expect(app.buttons["scan_add_by_hand"], "The scanner did not show again")
        waitToGo(app.navigationBars["Add food"], "The form stayed above the scanner")
        let added = NSPredicate(format: "label ENDSWITH %@", "Hazelnut spread added")
        expect(app.staticTexts.matching(added).firstMatch, "The message of the add did not show above the scanner")
    }

    func testABarcodeWithNoProductGivesAnEmptyNameWithTheKeyboard() throws {
        launch(inventory: .sample, lookups: [Self.jar: .response(body: #"{"status":0}"#)])
        expect(app.staticTexts["hero_total"], "Home does not show the number of foods")
        openMyFridge()
        scan(Self.jar)

        let name = expectAddForm("The add form did not open after the scan")
        waitForKeyboard(in: name, "The empty name field does not have the keyboard")
        let note = scrollBackTo(element("scan_note"), "The form does not say that the barcode has no product")
        XCTAssertTrue(note.label.hasPrefix("Open Food Facts has no product with this barcode. Type the name."), note.label)
        scrollTo(name, "The name field is not on the screen")
        XCTAssertFalse(app.staticTexts["suggestions_recent"].exists, "A form after a scan shows the recent foods")

        // "Save" closes the form and the scanner below it.
        name.typeText("Quince jam")
        app.buttons["save"].tap()
        expect(app.staticTexts["Quince jam added"], "The message of the add did not show")
        expect(areaTab("Fridge"), "The form and the scanner did not close")
        XCTAssertFalse(app.buttons["type_barcode"].exists, "The scanner stayed open after Save")
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

        let name = expectAddForm("The add form did not open after the scan")
        XCTAssertEqual(scrollBackTo(name, "The name field is not on the screen").value as? String, "Garden peas")
        let existing = scrollTo(element("name_existing"), "The form does not say that it adds a batch")
        XCTAssertEqual(existing.label, "This food is in your inventory. The form adds a batch to it.")
        XCTAssertFalse(element("scan_note").exists, "A food of the inventory has a note of the lookup")
        XCTAssertEqual(scrolledTo("field_quantity").value as? String, "500")
        XCTAssertEqual(scrolledTo("field_area").value as? String, "Freezer")

        app.buttons["save_scan_next"].tap()
        expect(app.buttons["scan_add_by_hand"], "The scanner did not show again")
        expect(app.buttons["scan_close"], "The scanner has no close button").tap()
        openMyFridge(area: "Freezer")
        let peas = cardOnMyFridge(of: "p-1")
        XCTAssertTrue(peas.contains("1,000 g"), "The peas do not have two batches of 500 g: \(peas)")
    }
}
