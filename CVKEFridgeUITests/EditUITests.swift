import XCTest

/// The forms that edit a product and a batch, on a simulator. Each test does what a person does, and then reads the
/// screen. The tests port the cases of `InventoryChangesDeviceTest.kt` of the Android app that edit the inventory, and
/// add the cases of the corrections of the iOS app (`docs/android-parity-plan.md`, section 7: 3, 4, and 15).
///
/// The tests open the forms from My Fridge and the screen of a food. `openFood(_:)`, `openEditFood()`, and
/// `openEditBatch(_:)` have the identifiers of those screens. Change them there when those screens change.
final class EditUITests: FridgeUITestCase {
    // MARK: - The way to the forms

    /// Opens the screen of a food of the sample from My Fridge.
    private func openFood(_ productId: String, area: String? = nil) {
        expect(app.staticTexts["hero_total"], "Home does not show the number of foods")
        tab("My Fridge").tap()
        expect(app.navigationBars["My Fridge"], "My Fridge did not open")
        if let area {
            app.buttons["area_picker"].tap()
            expect(app.buttons[area], "The storage area \(area) is not in the list").tap()
        }
        scrollTo(app.buttons["food_\(productId)"], "My Fridge does not show the food \(productId)").tap()
        expect(app.staticTexts["food_name"], "The food did not open")
    }

    /// Opens the form that edits the product, from the screen of the food.
    private func openEditFood() {
        expect(app.buttons["food_edit"], "The screen of the food has no edit button").tap()
        expect(app.textFields["field_name"], "The form that edits the food did not open")
    }

    /// Opens the form that edits the batch, from the screen of the food.
    private func openEditBatch(_ batchId: String) {
        scrollTo(app.buttons["batch_\(batchId)"], "The screen of the food does not show the batch \(batchId)").tap()
        expect(app.textFields["field_quantity"], "The form that edits the batch did not open")
    }

    // MARK: - Parts of the forms

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

    private func waitForLabel(_ element: XCUIElement, contains text: String, _ message: String) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 10)
        XCTAssertTrue(element.label.contains(text), message)
    }

    // MARK: - The batch

    /// Port of `aBatchGetsANewQuantityAndANewStorageArea`, with the "Undo" of the iOS app.
    func testABatchGetsANewQuantityAndANewStorageAreaAndUndoBringsThemBack() throws {
        launch(inventory: .sample)
        openFood("sample-yoghurt")
        XCTAssertTrue(app.staticTexts["4 pcs"].exists, "The batch of the sample does not have 4 pcs")

        openEditBatch("sample-batch-5")
        XCTAssertEqual(element("batch_food_name").label.lowercased(), "greek yoghurt", "The form does not name the food")
        replaceText(of: app.textFields["field_quantity"], with: "6")
        select("area_option_freezer", in: "field_area")
        capture("edit-batch")
        app.buttons["save"].tap()

        // The form closes, and the screen of the food shows the batch with its new quantity. The printed date stays.
        expect(app.staticTexts["Batch of Greek yoghurt saved"], "The message of the edit did not show")
        expect(app.staticTexts["6 pcs"], "The batch does not have the new quantity")
        XCTAssertFalse(app.textFields["field_quantity"].exists, "The form did not close")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Printed date")).firstMatch.exists,
            "The printed date of the batch did not stay"
        )

        // The edit has "Undo". The Android app has none.
        expect(app.buttons["Undo"], "The message of the edit has no Undo").tap()
        expect(app.staticTexts["4 pcs"], "Undo did not bring the quantity back")
    }

    func testAQuantityThatIsNotANumberSavesNothingAndAChangedFormAsksBeforeItCloses() throws {
        launch(inventory: .sample)
        openFood("sample-yoghurt")
        openEditBatch("sample-batch-5")

        replaceText(of: app.textFields["field_quantity"], with: "0")
        app.buttons["save"].tap()
        let problem = expect(app.staticTexts["error_quantity"], "The form did not show the problem of the quantity")
        XCTAssertEqual(problem.label, "Enter a quantity above 0.")
        XCTAssertTrue(app.textFields["field_quantity"].exists, "The form closed with a quantity of 0")

        // A changed form asks before it closes. The Android app drops the changes with no question.
        app.buttons["form_close"].tap()
        expect(app.buttons["Discard changes"], "The changed form did not ask before it closed")
        closeQuestion()
        XCTAssertTrue(app.buttons["Discard changes"].waitForNonExistence(timeout: 5), "The question did not close")
        XCTAssertTrue(app.textFields["field_quantity"].exists, "The form closed with no answer to the question")
        app.buttons["form_close"].tap()
        expect(app.buttons["Discard changes"], "The changed form did not ask before it closed").tap()
        expect(app.staticTexts["4 pcs"], "The batch changed with no save")
    }

    /// Correction 4: "Done" in the calendar with the same date keeps the source of the date. A date that the person
    /// chose because the food was still good stays "Your date", and an estimated date stays an estimate.
    func testTheSourceOfAnExpiryDateStaysWhenTheDateDoesNotChange() throws {
        let log = """
        {"id":"c-1","at":1,"origin":"phone-1","body":{"type":"productSaved","product":{"id":"p-1","name":"Soup","category":"leftovers","unit":null,"barcode":null,"foodId":null}}}
        {"id":"c-2","at":2,"origin":"phone-1","body":{"type":"batchAdded","batch":{"id":"b-1","productId":"p-1","quantity":1000,"storageAreaId":"fridge","dateAdded":"2026-11-10","expiryDate":"2026-11-16","expirySource":"chosen"}}}

        """
        launch(inventory: .changeLog(log))
        openFood("p-1")
        openEditBatch("b-1")

        let expiry = scrollTo(app.buttons["field_expiry"], "The form has no expiry date")
        XCTAssertTrue(expiry.label.contains("Nov 16, 2026"), "The form does not show the date of the batch: \(expiry.label)")
        let chosen = NSPredicate(format: "label BEGINSWITH %@", "Your date")
        XCTAssertTrue(app.staticTexts.matching(chosen).firstMatch.exists, "The form does not say that the date is a chosen date")

        // The calendar opens with the date of the batch. "Done" with no other date changes nothing.
        expiry.tap()
        expect(app.buttons["date_confirm"], "The calendar did not open").tap()
        XCTAssertTrue(app.staticTexts.matching(chosen).firstMatch.waitForExistence(timeout: 5), "Done made the chosen date a printed date")
        capture("edit-batch-your-date")

        // Nothing changed, so the form closes with no question, and "Save" writes nothing.
        app.buttons["save"].tap()
        expect(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Your date")).firstMatch, "The batch lost its chosen date")
        XCTAssertFalse(app.staticTexts["Batch of Soup saved"].exists, "A save that changes nothing gave a message")
    }

    // MARK: - The product

    /// Port of the last part of `aNoteIsAddedOnTheScreenOfTheFoodAndRemovedInTheEditForm`, with the "Undo" of the iOS
    /// app.
    func testAnEmptyNoteInTheEditFormRemovesTheNoteAndUndoBringsItBack() throws {
        launch(inventory: .sample)
        openFood("sample-milk")
        XCTAssertTrue(app.staticTexts["Opened on Tuesday"].exists, "The milk of the sample has no note")

        openEditFood()
        let note = scrollTo(element("field_note"), "The form has no note field")
        XCTAssertEqual(note.value as? String, "Opened on Tuesday")
        replaceText(of: note, with: " ")
        app.buttons["save"].tap()

        expect(app.staticTexts["Note of Whole milk removed"], "The message of the edit did not show")
        XCTAssertFalse(app.staticTexts["Opened on Tuesday"].exists, "The note stayed")
        expect(app.buttons["Undo"], "The message of the edit has no Undo").tap()
        expect(app.staticTexts["Opened on Tuesday"], "Undo did not bring the note back")
    }

    func testAFoodCannotGetTheNameOfAnotherFoodAndGetsANewNameAndCategory() throws {
        launch(inventory: .sample)
        openFood("sample-cheddar")
        openEditFood()

        // Case has no effect: "eggs" is the name of "Eggs".
        replaceText(of: app.textFields["field_name"], with: "eggs")
        app.buttons["save"].tap()
        let problem = expect(app.staticTexts["error_name"], "The form did not show the problem of the name")
        XCTAssertEqual(problem.label, "Another food has this name.")

        replaceText(of: app.textFields["field_name"], with: "Mature cheddar")
        select("category_option_other", in: "field_category")
        capture("edit-food")
        app.buttons["save"].tap()
        expect(app.staticTexts["Mature cheddar saved"], "The message of the edit did not show")
        XCTAssertEqual(app.staticTexts["food_name"].label, "Mature cheddar")
    }

    /// Correction 3: a change of the unit between g and kg converts the quantities. In the Android app 350 g becomes
    /// 350 kg.
    func testAChangeFromGramsToKilogramsConvertsTheQuantities() throws {
        launch(inventory: .sample)
        openFood("sample-cheddar")
        XCTAssertTrue(app.staticTexts["350 g"].exists, "The cheddar of the sample does not have 350 g")
        openEditFood()

        select("unit_option_kg", in: "field_unit")
        let note = expect(element("unit_converts"), "The form does not say that it converts the quantities")
        XCTAssertTrue(note.label.contains("350 g becomes 0.35 kg"), "The form does not show the example: \(note.label)")
        capture("edit-food-unit-converts")
        app.buttons["save"].tap()

        expect(app.staticTexts["0.35 kg"], "The quantity was not converted")
        expect(app.buttons["Undo"], "The message of the edit has no Undo").tap()
        expect(app.staticTexts["350 g"], "Undo did not bring the unit back")
    }

    /// Correction 3: for two units with no fixed relation, the numbers stay, and the form asks before it saves.
    func testAChangeToAUnitWithNoRelationAsksBeforeItKeepsTheNumbers() throws {
        launch(inventory: .sample)
        openFood("sample-cheddar")
        openEditFood()

        select("unit_option_pcs", in: "field_unit")
        let note = expect(element("unit_keeps_numbers"), "The form does not say that the numbers stay")
        XCTAssertTrue(note.label.contains("350 g becomes 350 pcs"), "The form does not show the example: \(note.label)")

        // A question with no answer saves nothing.
        hideKeyboard()
        app.buttons["save"].tap()
        expect(app.staticTexts["Change the unit to pcs?"], "Save did not ask about the unit")
        capture("edit-food-unit-question")
        closeQuestion()
        XCTAssertTrue(app.buttons["unit_change_confirm"].firstMatch.waitForNonExistence(timeout: 5), "The question did not close")
        XCTAssertTrue(app.textFields["field_name"].exists, "The form closed with no answer to the question")

        app.buttons["save"].tap()
        expect(app.buttons["unit_change_confirm"].firstMatch, "Save did not ask about the unit").tap()
        expect(app.staticTexts["350 pcs"], "The numbers did not stay")
    }
}
