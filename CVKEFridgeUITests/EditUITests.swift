import XCTest

/// The forms that edit a product and a batch, on a simulator. Each test does what a person does, and then reads the
/// screen. The tests port the cases of `InventoryChangesDeviceTest.kt` of the Android app that edit the inventory, and
/// add the cases of the corrections of the iOS app (`docs/android-parity-plan.md`, section 7: 3, 4, and 15).
///
/// The tests open the forms from the screen of a food, as a person does: "Edit food" in the toolbar, and "Edit batch"
/// in the menu of a batch. On the screen of a food, VoiceOver reads a batch as one element (`batch_<id>`): its label
/// has the quantity, the days left, the expiry date with its source, and the storage area.
final class EditUITests: FridgeUITestCase {
    // MARK: - The way to the forms

    /// Opens the form that edits the product, from the screen of the food.
    private func openEditFood() {
        expect(app.buttons["food_edit"], "The screen of the food has no edit button").tap()
        expect(app.textFields["field_name"], "The form that edits the food did not open")
    }

    /// Opens the form that edits the batch, from the menu of the batch on the screen of the food.
    private func openEditBatch(_ batchId: String) {
        scrollTo(app.buttons["batch_menu_\(batchId)"], "The screen of the food does not show the batch \(batchId)").tap()
        expect(app.buttons["menu_edit_batch"], "The menu of the batch has no Edit batch").tap()
        expect(app.navigationBars["Edit batch"], "The form that edits the batch did not open")
        expect(app.textFields["field_quantity"], "The form that edits the batch has no quantity")
    }

    /// The label of a batch on the screen of the food.
    private func batch(_ batchId: String) -> XCUIElement {
        element("batch_\(batchId)")
    }

    /// The category and the sum of the batches on the screen of the food, for example "Dairy, 350 g".
    private var summary: XCUIElement {
        app.staticTexts["food_summary"]
    }

    // MARK: - The batch

    /// Port of `aBatchGetsANewQuantityAndANewStorageArea`, with the "Undo" of the iOS app.
    func testABatchGetsANewQuantityAndANewStorageAreaAndUndoBringsThemBack() throws {
        launch(inventory: .sample)
        openFood("sample-yoghurt")
        let yoghurt = batch("sample-batch-5")
        XCTAssertTrue(yoghurt.label.contains("4 pcs"), "The batch of the sample does not have 4 pcs: \(yoghurt.label)")
        XCTAssertTrue(yoghurt.label.contains("Fridge"), "The batch of the sample is not in the fridge: \(yoghurt.label)")

        openEditBatch("sample-batch-5")
        XCTAssertEqual(element("batch_food_name").label.lowercased(), "greek yoghurt", "The form does not name the food")
        replaceText(of: app.textFields["field_quantity"], with: "6")
        select("area_option_freezer", in: "field_area")
        capture("edit-batch")
        app.buttons["save"].tap()

        // The form closes, and the screen of the food shows the batch with its new quantity. The printed date stays.
        expect(app.staticTexts["Batch of Greek yoghurt saved"], "The message of the edit did not show")
        wait(for: yoghurt, toHaveLabelWith: "6 pcs")
        XCTAssertFalse(app.textFields["field_quantity"].exists, "The form did not close")
        XCTAssertTrue(yoghurt.label.contains("Freezer"), "The batch is not in the freezer: \(yoghurt.label)")
        XCTAssertTrue(yoghurt.label.contains("Printed date"), "The printed date of the batch did not stay: \(yoghurt.label)")

        // The edit has "Undo". The Android app has none.
        expect(app.buttons["Undo"], "The message of the edit has no Undo").tap()
        wait(for: yoghurt, toHaveLabelWith: "4 pcs")
        XCTAssertTrue(yoghurt.label.contains("Fridge"), "Undo did not bring the storage area back: \(yoghurt.label)")
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
        keepEditing()
        XCTAssertTrue(app.buttons["Discard changes"].waitForNonExistence(timeout: 5), "The question did not close")
        XCTAssertTrue(app.textFields["field_quantity"].exists, "The form closed with no answer to the question")
        app.buttons["form_close"].tap()
        expect(app.buttons["Discard changes"], "The changed form did not ask before it closed").tap()
        waitToGo(app.navigationBars["Edit batch"], "The form did not close")
        XCTAssertTrue(batch("sample-batch-5").label.contains("4 pcs"), "The batch changed with no save")
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
        // The screen of the food names the source of the date.
        let soup = batch("b-1")
        XCTAssertTrue(soup.label.contains("Your date: Nov 16, 2026"), "The batch does not have a chosen date: \(soup.label)")
        openEditBatch("b-1")

        let expiry = scrollTo(app.buttons["field_expiry"], "The form has no expiry date")
        XCTAssertTrue(expiry.label.contains("Nov 16, 2026"), "The form does not show the date of the batch: \(expiry.label)")

        // The calendar opens with the date of the batch. "Done" with no other date changes nothing.
        expiry.tap()
        expect(app.buttons["date_confirm"], "The calendar did not open").tap()
        waitToGo(app.buttons["date_confirm"], "The calendar did not close")
        capture("edit-batch-your-date")

        // Nothing changed. So the close button closes the form with no question: a date that became a printed date
        // is a change, and the form asks before it drops a change.
        app.buttons["form_close"].tap()
        waitToGo(app.navigationBars["Edit batch"], "Done in the calendar with the same date changed the form")
        XCTAssertFalse(app.buttons["Discard changes"].exists, "The form asked about changes that it does not have")

        // "Save" with no change writes nothing: the batch keeps the source of its date, and no message shows.
        openEditBatch("b-1")
        scrollTo(app.buttons["field_expiry"], "The form has no expiry date").tap()
        expect(app.buttons["date_confirm"], "The calendar did not open").tap()
        waitToGo(app.buttons["date_confirm"], "The calendar did not close")
        app.buttons["save"].tap()
        waitToGo(app.navigationBars["Edit batch"], "The form did not close after Save")
        XCTAssertTrue(soup.label.contains("Your date: Nov 16, 2026"), "The batch lost its chosen date: \(soup.label)")
        XCTAssertFalse(app.staticTexts["Batch of Soup saved"].exists, "A save that changes nothing gave a message")
    }

    // MARK: - The product

    /// Port of the last part of `aNoteIsAddedOnTheScreenOfTheFoodAndRemovedInTheEditForm`, with the "Undo" of the iOS
    /// app.
    func testAnEmptyNoteInTheEditFormRemovesTheNoteAndUndoBringsItBack() throws {
        launch(inventory: .sample)
        openFood("sample-milk")
        let shownNote = app.buttons["food_note"]
        XCTAssertTrue(shownNote.label.contains("Opened on Tuesday"), "The milk of the sample has no note: \(shownNote.label)")

        openEditFood()
        let note = scrollTo(element("field_note"), "The form has no note field")
        XCTAssertEqual(note.value as? String, "Opened on Tuesday")
        replaceText(of: note, with: " ")
        app.buttons["save"].tap()

        expect(app.staticTexts["Note of Whole milk removed"], "The message of the edit did not show")
        expect(app.buttons["food_add_note"], "The note stayed")
        XCTAssertFalse(shownNote.exists, "The note stayed")
        expect(app.buttons["Undo"], "The message of the edit has no Undo").tap()
        wait(for: shownNote, toHaveLabelWith: "Opened on Tuesday")
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
        XCTAssertEqual(summary.label, "Dairy, 350 g", "The cheddar of the sample does not have 350 g")
        XCTAssertTrue(batch("sample-batch-9").label.contains("350 g"), batch("sample-batch-9").label)
        openEditFood()

        select("unit_option_kg", in: "field_unit")
        let note = expect(element("unit_converts"), "The form does not say that it converts the quantities")
        XCTAssertTrue(note.label.contains("350 g becomes 0.35 kg"), "The form does not show the example: \(note.label)")
        capture("edit-food-unit-converts")
        app.buttons["save"].tap()

        wait(for: summary, toHaveLabel: "Dairy, 0.35 kg")
        XCTAssertTrue(batch("sample-batch-9").label.contains("0.35 kg"), "The batch was not converted: \(batch("sample-batch-9").label)")
        expect(app.buttons["Undo"], "The message of the edit has no Undo").tap()
        wait(for: summary, toHaveLabel: "Dairy, 350 g")
    }

    /// Correction 3: for two units with no fixed relation, the numbers stay, and the form asks before it saves.
    func testAChangeToAUnitWithNoRelationAsksBeforeItKeepsTheNumbers() throws {
        launch(inventory: .sample)
        openFood("sample-cheddar")
        openEditFood()

        select("unit_option_pcs", in: "field_unit")
        let note = expect(element("unit_keeps_numbers"), "The form does not say that the numbers stay")
        XCTAssertTrue(note.label.contains("350 g becomes 350 pcs"), "The form does not show the example: \(note.label)")

        // "Keep editing" saves nothing.
        hideKeyboard()
        app.buttons["save"].tap()
        expect(app.staticTexts["Change the unit to pcs?"], "Save did not ask about the unit")
        capture("edit-food-unit-question")
        keepEditing()
        XCTAssertTrue(app.buttons["unit_change_confirm"].firstMatch.waitForNonExistence(timeout: 5), "The question did not close")
        XCTAssertTrue(app.textFields["field_name"].exists, "The form closed with no answer to the question")

        app.buttons["save"].tap()
        expect(app.buttons["unit_change_confirm"].firstMatch, "Save did not ask about the unit").tap()
        wait(for: summary, toHaveLabel: "Dairy, 350 pcs")
    }
}
