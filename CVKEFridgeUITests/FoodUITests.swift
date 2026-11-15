import XCTest

/// The screen of one food on a simulator: the product, its batches in the use-first order, the note, "Still good?",
/// the storage tips, the history of the food, the photo, and the actions with "Undo". The tests of the batch, of the
/// note, and of "Still good?" are the tests of `InventoryChangesDeviceTest.kt` of the Android app. The captures are
/// attachments, so CI can show the real screens.
///
/// The labels in these tests are the labels of VoiceOver: they have a comma where the screen has the separator sign.
///
/// "Used" and "Thrown away" are here only for food with one item left. Such food needs no question for a quantity,
/// so these tests do not use the sheet of the quantity.
final class FoodUITests: FridgeUITestCase {
    // MARK: The product and its batches

    func test01TheFoodShowsItsBatchesInTheUseFirstOrder() throws {
        launch(inventory: .sample)
        openFood("sample-milk", name: "Whole milk")

        XCTAssertEqual(app.staticTexts["food_summary"].label, "Dairy, 3 l")
        XCTAssertEqual(app.staticTexts["food_batches"].label, "2 batches")
        XCTAssertTrue(app.buttons["food_used"].exists, "The food has no Used button")
        XCTAssertTrue(app.buttons["food_thrown_away"].exists, "The food has no Thrown away button")
        XCTAssertTrue(element("food_note").label.contains("Opened on Tuesday"), "The note of the food does not show")

        // The batch that expires first is the first batch, and it says so. Each batch names the source of its date.
        let first = element("batch_sample-batch-3")
        let second = element("batch_sample-batch-4")
        for text in ["Use first", "1 l", "Expires tomorrow", "Printed date: Nov 15, 2026", "Fridge, Added Nov 8, 2026"] {
            XCTAssertTrue(first.label.contains(text), "The first batch does not say \(text): \(first.label)")
        }
        for text in ["2 l", "Expires in 8d", "Printed date: Nov 22, 2026"] {
            XCTAssertTrue(second.label.contains(text), "The second batch does not say \(text): \(second.label)")
        }
        XCTAssertFalse(second.label.contains("Use first"))
        XCTAssertLessThan(first.frame.minY, second.frame.minY, "The batches are not in the use-first order")
        capture("food-batches")

        // The history of the food has its totals and its entries. A sum has a no-break space before its unit.
        let total = app.staticTexts["Used: 2\u{00A0}l from 2 batches"]
        scrollTo(total, "The history of the food does not show its total")
        capture("food-history")
    }

    func test02TheMenuOfABatchAndTheToolbarOpenTheForms() throws {
        launch(inventory: .sample)
        openFood("sample-milk", name: "Whole milk")

        // The actions of a batch are in its menu.
        app.buttons["batch_menu_sample-batch-3"].tap()
        for item in ["menu_used", "menu_thrown_away", "menu_edit_batch", "menu_delete_batch"] {
            expect(app.buttons[item], "The menu of the batch has no \(item)")
        }
        capture("food-batch-menu")
        app.buttons["menu_edit_batch"].tap()
        expect(app.navigationBars["Edit batch"], "The form of the batch did not open")
        app.buttons["form_close"].tap()

        expect(app.buttons["food_edit"], "The toolbar has no Edit").tap()
        expect(app.navigationBars["Edit food"], "The form of the food did not open")
        app.buttons["form_close"].tap()

        scrollTo(app.buttons["food_add_batch"], "The food has no Add a batch").tap()
        expect(app.navigationBars["Add food"], "The add form did not open")
    }

    func test03ADeletedBatchComesBackWithUndo() throws {
        launch(inventory: .sample)
        openFood("sample-milk", name: "Whole milk")

        app.buttons["batch_menu_sample-batch-3"].tap()
        expect(app.buttons["menu_delete_batch"], "The menu of the batch has no Delete batch").tap()
        expect(app.staticTexts["1 batch of Whole milk deleted"], "The message of the delete did not show")
        waitForLabel(app.staticTexts["food_batches"], "1 batch")
        XCTAssertEqual(app.staticTexts["food_summary"].label, "Dairy, 2 l")
        // One batch is not "Use first".
        XCTAssertFalse(element("batch_sample-batch-4").label.contains("Use first"))

        app.buttons["Undo"].tap()
        waitForLabel(app.staticTexts["food_batches"], "2 batches")
        XCTAssertTrue(element("batch_sample-batch-3").exists, "Undo did not bring the batch back")
    }

    // MARK: Used and thrown away

    func test04TheLastItemIsUsedWithNoQuestionAndTheFoodHasAddAgain() throws {
        launch(inventory: .sample)
        openFood("sample-juice", name: "Orange juice")
        XCTAssertEqual(app.staticTexts["food_summary"].label, "Beverage, 1 bottle")

        // One bottle is left, so there is no quantity to choose.
        app.buttons["food_used"].tap()
        expect(app.staticTexts["1 bottle of Orange juice used"], "The message of the use did not show")

        // The food stays, with no batch. The screen says so and has "Add again".
        expect(app.staticTexts["You have none of this food now"], "The food does not say that it has no batch")
        XCTAssertEqual(app.staticTexts["food_summary"].label, "Beverage")
        XCTAssertFalse(app.buttons["food_used"].exists, "A food with no batch has a Used button")
        capture("food-none")
        scrollTo(app.staticTexts["Used: 2\u{00A0}bottles from 2 batches"], "The history does not count the use")

        scrollTo(app.buttons["Undo"], "The message has no Undo").tap()
        expect(app.buttons["food_used"], "Undo did not bring the batch back")
        XCTAssertFalse(app.staticTexts["You have none of this food now"].exists)

        // The menu of the batch records the same for the batch.
        app.buttons["batch_menu_sample-batch-7"].tap()
        expect(app.buttons["menu_thrown_away"], "The menu of the batch has no Thrown away").tap()
        expect(app.staticTexts["1 bottle of Orange juice thrown away"], "The message of the throw away did not show")
        let add = scrollTo(app.buttons["add_again"], "The food with no batch has no Add again")
        add.tap()
        expect(app.navigationBars["Add food"], "Add again did not open the add form")
    }

    // MARK: Still good?

    func test05AnExpiredFoodThatIsStillGoodGetsALaterExpiryDateWithUndo() throws {
        launch(inventory: .sample)
        openFood("sample-chicken", name: "Chicken thighs")
        let batch = element("batch_sample-batch-1")
        XCTAssertTrue(batch.label.contains("Expired yesterday, estimated"), batch.label)
        XCTAssertTrue(batch.label.contains("Estimated date: Nov 13, 2026"), batch.label)
        capture("food-still-good")

        // An expired batch starts from today: one more day is good until tomorrow.
        app.buttons["later_expiry_1"].tap()
        waitForLabel(batch, containing: "Expires tomorrow")
        // The new date is not from the package, and the screen does not say so.
        XCTAssertTrue(batch.label.contains("Your date: Nov 15, 2026"), batch.label)
        expect(app.staticTexts["Chicken thighs now expires on Nov 15, 2026"], "The message of the new date did not show")
        capture("food-your-date")

        app.buttons["Undo"].tap()
        waitForLabel(batch, containing: "Expired yesterday, estimated")

        // One more week is seven days from today.
        app.buttons["later_expiry_7"].tap()
        waitForLabel(batch, containing: "Your date: Nov 21, 2026")
        XCTAssertFalse(app.buttons["later_expiry_1"].exists, "A fresh batch has the Still good? choices")
    }

    func test06OtherDateStartsOnTheDayAfterTodayAndAfterTheExpiryDate() throws {
        launch(inventory: .sample)
        openFood("sample-chicken", name: "Chicken thighs")

        // The batch expired yesterday. The calendar starts tomorrow, and "Done" with no other choice gives that date.
        app.buttons["later_expiry_other"].tap()
        expect(app.buttons["date_confirm"], "The calendar did not open")
        capture("food-other-date")
        app.buttons["date_confirm"].tap()
        let batch = element("batch_sample-batch-1")
        waitForLabel(batch, containing: "Your date: Nov 15, 2026")
        XCTAssertTrue(batch.label.contains("Expires tomorrow"), batch.label)

        // The batch now expires tomorrow, so it is expiring. The calendar starts on the day after that date.
        app.buttons["later_expiry_other"].tap()
        expect(app.buttons["date_confirm"], "The calendar did not open the second time").tap()
        waitForLabel(batch, containing: "Your date: Nov 16, 2026")
    }

    // MARK: The note

    func test07ANoteIsAddedChangedAndRemovedWithUndo() throws {
        launch(inventory: .sample)
        openFood("sample-yoghurt", name: "Greek yoghurt")

        // The note is saved without the spaces at its ends.
        app.buttons["food_add_note"].tap()
        let field = expect(element("food_note_field"), "The editor of the note did not open")
        field.tap()
        field.typeText("  For the cake  ")
        capture("food-note-editor")
        app.buttons["food_note_save"].tap()
        expect(app.staticTexts["Note of Greek yoghurt saved"], "The message of the note did not show")
        let note = expect(app.buttons["food_note"], "The screen does not show the note")
        XCTAssertTrue(note.label.hasSuffix("For the cake"), note.label)
        capture("food-note")

        // A changed note asks before the editor closes.
        note.tap()
        expect(element("food_note_field"), "The editor did not open for the note").tap()
        element("food_note_field").typeText("!")
        app.buttons["form_close"].tap()
        expect(app.buttons["Discard changes"], "The changed note did not ask before it closed").tap()
        waitForLabel(app.buttons["food_note"], containing: "For the cake")
        XCTAssertFalse(app.buttons["food_note"].label.contains("!"), "The note changed with no save")

        // A note with no text is removed, and "Undo" brings it back.
        app.buttons["food_note"].tap()
        let again = expect(element("food_note_field"), "The editor did not open for the note")
        again.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        again.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20))
        app.buttons["food_note_save"].tap()
        expect(app.staticTexts["Note of Greek yoghurt removed"], "The message of the removed note did not show")
        expect(app.buttons["food_add_note"], "The removed note still shows")
        app.buttons["Undo"].tap()
        waitForLabel(app.buttons["food_note"], containing: "For the cake")
    }

    // MARK: Delete food

    func test08ADeletedFoodClosesTheScreenAndComesBackWithUndo() throws {
        launch(inventory: .sample)
        openFood("sample-cheddar", name: "Cheddar")

        app.buttons["food_menu"].tap()
        capture("food-menu")
        expect(app.buttons["food_delete"], "The menu has no Delete food").tap()

        // The screen closes, and the message with "Undo" shows on My Fridge.
        expect(app.staticTexts["Cheddar deleted"], "The message of the delete did not show")
        waitUntilGone(app.staticTexts["food_name"], "The screen of the deleted food stayed open")
        XCTAssertTrue(app.navigationBars["My Fridge"].exists, "The screen did not go back to My Fridge")
        XCTAssertFalse(card("sample-cheddar").exists, "My Fridge shows the deleted food")

        app.buttons["Undo"].tap()
        scrollTo(card("sample-cheddar"), "Undo did not bring the food back")
    }

    func test09TheScreenClosesWhenTheAddOfItsFoodIsUndone() throws {
        launch(inventory: .empty)
        expect(app.staticTexts["hero_total"], "Home did not open")
        tab("Add food").tap()
        let name = expect(app.textFields["field_name"], "The add form did not open")
        name.tap()
        name.typeText("Kiwi")
        app.buttons["save"].tap()
        expect(app.staticTexts["Kiwi added"], "The message of the add did not show")

        // The message stays above the tab bar while the screen of the new food opens. Its "Undo" removes the food.
        tab("My Fridge").tap()
        let kiwi = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Kiwi")).firstMatch
        expect(kiwi, "My Fridge does not show the new food").tap()
        expect(app.staticTexts["food_name"], "The screen of the food did not open")
        expect(app.buttons["Undo"], "The message of the add went away").tap()
        waitUntilGone(app.staticTexts["food_name"], "The screen of a food that is not there stayed open")
        XCTAssertTrue(app.navigationBars["My Fridge"].exists, "The screen did not go back to My Fridge")
    }

    // MARK: The storage tips and the history

    func test10TheStorageTipsNameTheirSourcesAndTheHistoryShowsAllEntries() throws {
        launch(inventory: .changeLog(Self.bananas))
        openFood("p-1", name: "Bananas")
        XCTAssertEqual(app.staticTexts["food_summary"].label, "Produce, 3 pcs")
        // A food with one batch has no "Use first".
        XCTAssertFalse(element("batch_b-1").label.contains("Use first"))

        // The text of the package and the general advice are two parts, each with its source.
        scrollTo(app.staticTexts["From the package"], "The storage tips do not show the text of the package")
        XCTAssertTrue(app.staticTexts["Keep in a cool, dry place."].exists)
        XCTAssertTrue(app.staticTexts["This text is about this product. It comes from Open Food Facts."].exists)
        scrollTo(app.staticTexts["General advice for Bananas"], "The storage tips do not show the general advice")
        XCTAssertTrue(app.staticTexts["Usual place: Pantry"].exists)
        let fridge = app.staticTexts["storage_advice_fridge"]
        XCTAssertTrue(fridge.label.hasPrefix("Fridge  About 3 days."), fridge.label)
        XCTAssertTrue(app.staticTexts["storage_advice_freezer"].label.hasSuffix("About 2 months."))
        capture("food-storage-tips")

        // The history has the totals of each outcome, the first five entries, and "Show all".
        scrollTo(app.staticTexts["Used: 7\u{00A0}pcs from 1 batch"], "The history does not show what was used")
        XCTAssertTrue(app.staticTexts["Thrown away: 2\u{00A0}pcs from 1 batch"].exists)
        let newest = scrollTo(element("food_history_c-10"), "The history does not show its newest entry")
        XCTAssertEqual(newest.label, "Thrown away, 2 pcs, Yesterday")
        XCTAssertFalse(element("food_history_c-3").exists, "The history shows more than its first entries")
        let all = scrollTo(app.buttons["food_history_all"], "The history has no Show all")
        XCTAssertEqual(all.label, "Show all 8 entries")
        all.tap()
        let oldest = scrollTo(element("food_history_c-3"), "Show all did not show the oldest entry")
        XCTAssertEqual(oldest.label, "Used, 1 pcs, Nov 2, 2026")
        XCTAssertFalse(app.buttons["food_history_all"].exists, "Show all stays after all entries show")
        capture("food-history-all")
    }

    // MARK: The photo

    func test11APhotoShowsAtTheTopAndARemovedPhotoComesBackWithUndo() throws {
        launch(inventory: .sample)
        openFood("sample-milk", name: "Whole milk")
        XCTAssertFalse(element("food_photo").exists, "A food with no photo shows a photo")

        // The photo picker of the system is a different process. It shows the pictures of the simulator.
        expect(app.buttons["photo_choose"], "The food has no Choose a photo").tap()
        let picker = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow.photospicker")
        let picture = picker.images.firstMatch
        guard picture.waitForExistence(timeout: 15) else {
            throw XCTSkip("The photo picker of this simulator shows no picture.")
        }
        picture.tap()

        // The photo is at the top, above the name, with "Change photo" and "Remove photo".
        let photo = expect(element("food_photo"), "The photo of the food does not show", timeout: 20)
        XCTAssertEqual(photo.label, "Photo of Whole milk")
        XCTAssertLessThan(photo.frame.minY, app.staticTexts["food_name"].frame.minY, "The photo is not above the name")
        XCTAssertTrue(app.buttons["photo_change"].exists, "A food with a photo has no Change photo")
        capture("food-photo")

        app.buttons["photo_remove"].tap()
        expect(app.staticTexts["Photo removed"], "The message of the removed photo did not show")
        waitUntilGone(element("food_photo"), "The removed photo still shows")
        XCTAssertTrue(app.buttons["photo_choose"].exists)
        app.buttons["Undo"].tap()
        expect(element("food_photo"), "Undo did not bring the photo back")
    }

    // MARK: Parts

    /// A food with a food of the table of foods and a storage text, one batch, and eight history entries.
    private static let bananas: String = {
        func change(_ number: Int, _ body: String) -> String {
            #"{"id":"c-\#(number)","at":\#(number),"origin":"phone-1","body":\#(body)}"#
        }
        var lines = [
            change(1, #"{"type":"productSaved","product":{"id":"p-1","name":"Bananas","category":"produce","unit":"pcs","barcode":null,"foodId":"fk-251","note":null,"storageText":"Keep in a cool, dry place."}}"#),
            change(2, #"{"type":"batchAdded","batch":{"id":"b-1","productId":"p-1","quantity":12000,"storageAreaId":"fridge","dateAdded":"2026-11-01","expiryDate":null,"expirySource":null}}"#),
        ]
        for day in 2...8 {
            lines.append(change(day + 1, #"{"type":"batchUsed","batchId":"b-1","quantity":1000,"date":"2026-11-0\#(day)"}"#))
        }
        lines.append(change(10, #"{"type":"batchThrownAway","batchId":"b-1","quantity":2000,"date":"2026-11-13"}"#))
        return lines.joined(separator: "\n") + "\n"
    }()

    /// An element of each type, by its identifier.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The card of a food on My Fridge. Its identifier starts with "food_" and the identifier of the product.
    private func card(_ productId: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "food_\(productId)")).firstMatch
    }

    /// Opens the screen of a food from My Fridge.
    private func openFood(_ productId: String, name: String) {
        expect(tab("My Fridge"), "The tab bar has no My Fridge").tap()
        expect(app.navigationBars["My Fridge"], "My Fridge did not open")
        scrollTo(card(productId), "My Fridge does not show \(name)").tap()
        let title = expect(app.staticTexts["food_name"], "The screen of the food did not open")
        XCTAssertEqual(title.label, name)
    }

    private func waitForLabel(_ element: XCUIElement, _ label: String) {
        let predicate = NSPredicate(format: "label == %@", label)
        wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 10)
    }

    private func waitForLabel(_ element: XCUIElement, containing text: String) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 10)
    }

    private func waitUntilGone(_ element: XCUIElement, _ message: String) {
        let predicate = NSPredicate(format: "exists == false")
        let result = XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 10)
        XCTAssertEqual(result, .completed, message)
    }
}
