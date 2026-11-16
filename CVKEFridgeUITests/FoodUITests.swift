import XCTest

/// The screen of one food on a simulator: the product, its batches in the use-first order, the note, "Still good?",
/// the storage tips, the history of the food, the photo, and the actions with "Undo". The tests of the batch, of the
/// note, and of "Still good?" are the tests of `InventoryChangesDeviceTest.kt` of the Android app. The captures are
/// attachments, so CI can show the real screens.
///
/// The labels in these tests are the labels of VoiceOver: they have a comma where the screen has the separator sign.
///
/// "Used" and "Thrown away" ask for a quantity in a sheet (`test12`). Food with one item left needs no question
/// (`test04`). The photo comes from the built-in pictures of the debug build (`-uiTestPicture`), in the place of the
/// photo picker of the system.
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
        wait(for: app.staticTexts["food_batches"], toHaveLabel: "1 batch")
        XCTAssertEqual(app.staticTexts["food_summary"].label, "Dairy, 2 l")
        // One batch is not "Use first".
        XCTAssertFalse(element("batch_sample-batch-4").label.contains("Use first"))

        app.buttons["Undo"].tap()
        wait(for: app.staticTexts["food_batches"], toHaveLabel: "2 batches")
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
        // The history of the food counts the use. A sum has a no-break space before its unit.
        XCTAssertTrue(app.staticTexts["Used: 2\u{00A0}bottles from 2 batches"].exists, "The history does not count the use")
        capture("food-none")

        app.buttons["Undo"].tap()
        expect(app.buttons["food_used"], "Undo did not bring the batch back")
        XCTAssertFalse(app.staticTexts["You have none of this food now"].exists)

        // The menu of the batch records the same for the batch.
        app.buttons["batch_menu_sample-batch-7"].tap()
        expect(app.buttons["menu_thrown_away"], "The menu of the batch has no Thrown away").tap()
        expect(app.staticTexts["1 bottle of Orange juice thrown away"], "The message of the throw away did not show")
        expect(app.staticTexts["Thrown away: 1\u{00A0}bottle from 1 batch"], "The history does not count the throw away")
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
        wait(for: batch, toHaveLabelWith: "Expires tomorrow")
        // The new date is not from the package, and the screen does not say so.
        XCTAssertTrue(batch.label.contains("Your date: Nov 15, 2026"), batch.label)
        expect(app.staticTexts["Chicken thighs now expires on Nov 15, 2026"], "The message of the new date did not show")
        capture("food-your-date")

        app.buttons["Undo"].tap()
        wait(for: batch, toHaveLabelWith: "Expired yesterday, estimated")

        // One more week is seven days from today.
        app.buttons["later_expiry_7"].tap()
        wait(for: batch, toHaveLabelWith: "Your date: Nov 21, 2026")
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
        wait(for: batch, toHaveLabelWith: "Your date: Nov 15, 2026")
        XCTAssertTrue(batch.label.contains("Expires tomorrow"), batch.label)

        // The batch now expires tomorrow, so it is expiring. The calendar starts on the day after that date.
        app.buttons["later_expiry_other"].tap()
        expect(app.buttons["date_confirm"], "The calendar did not open the second time").tap()
        wait(for: batch, toHaveLabelWith: "Your date: Nov 16, 2026")
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
        wait(for: app.buttons["food_note"], toHaveLabelWith: "For the cake")
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
        wait(for: app.buttons["food_note"], toHaveLabelWith: "For the cake")
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
        waitToGo(app.staticTexts["food_name"], "The screen of the deleted food stayed open")
        XCTAssertTrue(app.navigationBars["My Fridge"].exists, "The screen did not go back to My Fridge")
        XCTAssertFalse(card("sample-cheddar").exists, "My Fridge shows the deleted food")

        app.buttons["Undo"].tap()
        scrollTo(card("sample-cheddar"), "Undo did not bring the food back")
    }

    func test09TheScreenClosesWhenTheAddOfItsFoodIsUndone() throws {
        launch(inventory: .empty)
        // The form opens from the empty My Fridge. So the card of the new food is on the screen when the form
        // closes, and the test needs only one tap to open the food while the message of the add shows.
        openMyFridge()
        expect(app.buttons["empty_add"], "The empty My Fridge has no add form").tap()
        let name = expect(app.textFields["field_name"], "The add form did not open")
        name.typeText("Kiwi")
        // The elements are found before the save, so that the test loses no time while the message shows.
        let kiwi = card(named: "Kiwi")
        let undo = app.buttons["Undo"]
        let title = app.staticTexts["food_name"]
        app.buttons["save"].tap()

        // The message stays above the tab bar while the screen of the new food opens. Its "Undo" removes the food.
        expect(kiwi, "My Fridge does not show the new food").tap()
        expect(title, "The screen of the food did not open")
        XCTAssertEqual(title.label, "Kiwi")
        expect(undo, "The message of the add does not show above the screen of the food", timeout: 2).tap()
        waitToGo(title, "The screen of a food that is not there stayed open")
        XCTAssertTrue(app.navigationBars["My Fridge"].exists, "The screen did not go back to My Fridge")
        expect(app.staticTexts["No items yet"], "My Fridge shows the food after the Undo of its add")
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
        // "Choose a photo" gives a built-in picture of the debug build. The photo picker of the system is a
        // different process, and it shows the pictures of the simulator: a test cannot rely on it.
        launch(inventory: .sample, arguments: ["-uiTestPicture", "photo"])
        openFood("sample-milk", name: "Whole milk")
        XCTAssertFalse(element("food_photo").exists, "A food with no photo shows a photo")
        expect(app.buttons["photo_choose"], "The food has no Choose a photo").tap()

        // The photo is at the top, above the name, with "Change photo" and "Remove photo".
        let photo = expect(element("food_photo"), "The photo of the food does not show")
        XCTAssertEqual(photo.label, "Photo of Whole milk")
        XCTAssertLessThan(photo.frame.minY, app.staticTexts["food_name"].frame.minY, "The photo is not above the name")
        XCTAssertTrue(app.buttons["photo_change"].exists, "A food with a photo has no Change photo")
        capture("food-photo")

        app.buttons["photo_remove"].tap()
        expect(app.staticTexts["Photo removed"], "The message of the removed photo did not show")
        waitToGo(element("food_photo"), "The removed photo still shows")
        XCTAssertTrue(app.buttons["photo_choose"].exists)
        app.buttons["Undo"].tap()
        expect(element("food_photo"), "Undo did not bring the photo back")
    }

    // MARK: The quantity

    func test12ATypedQuantityIsRecordedFromTheFoodFromABatchAndFromTheCardOfMyFridge() throws {
        launch(inventory: .sample)
        openFood("sample-milk", name: "Whole milk")
        XCTAssertEqual(app.staticTexts["food_summary"].label, "Dairy, 3 l")

        // "Used" of the food asks for a quantity. The field starts with the quantity of the batch to use first.
        app.buttons["food_used"].tap()
        var quantity = expect(app.textFields["field_quantity"], "The sheet for the quantity did not open")
        XCTAssertEqual(quantity.value as? String, "1")
        XCTAssertTrue(app.staticTexts["How much was used?"].exists, "The sheet does not ask how much was used")
        XCTAssertEqual(
            app.staticTexts["take_available"].label,
            "Whole milk: you have 3 l. The quantity comes from the oldest batch first."
        )
        capture("food-take-quantity")

        // A quantity that is more than the food has is not recorded.
        replaceText(of: quantity, with: "3.5")
        app.buttons["take_confirm"].tap()
        expect(app.staticTexts["You have only 3 l."], "The sheet took more than the food has")

        // 1.5 l is more than the first batch has, so the rest comes from the second batch.
        replaceText(of: quantity, with: "1.5")
        app.buttons["take_confirm"].tap()
        expect(app.staticTexts["1.5 l of Whole milk used"], "The message of the quantity did not show")
        waitToGo(quantity, "The sheet did not close")
        wait(for: app.staticTexts["food_summary"], toHaveLabel: "Dairy, 1.5 l")
        wait(for: app.staticTexts["food_batches"], toHaveLabel: "1 batch")
        XCTAssertFalse(element("batch_sample-batch-3").exists, "The first batch stayed with no quantity")
        XCTAssertTrue(element("batch_sample-batch-4").label.contains("1.5 l"), element("batch_sample-batch-4").label)

        // "Undo" brings the two batches back.
        app.buttons["Undo"].tap()
        wait(for: app.staticTexts["food_summary"], toHaveLabel: "Dairy, 3 l")
        wait(for: app.staticTexts["food_batches"], toHaveLabel: "2 batches")

        // The menu of a batch asks for a quantity of that batch only.
        app.buttons["batch_menu_sample-batch-4"].tap()
        expect(app.buttons["menu_thrown_away"], "The menu of the batch has no Thrown away").tap()
        quantity = expect(app.textFields["field_quantity"], "The sheet for the quantity of the batch did not open")
        XCTAssertEqual(quantity.value as? String, "2")
        XCTAssertTrue(app.staticTexts["How much was thrown away?"].exists, "The sheet does not ask how much was thrown away")
        XCTAssertTrue(app.staticTexts["take_available"].label.hasPrefix("Whole milk: you have 2 l."), app.staticTexts["take_available"].label)
        replaceText(of: quantity, with: "0.5")
        // Two fast taps record the quantity one time. The sheet is on the screen while it closes.
        app.buttons["take_confirm"].doubleTap()
        expect(app.staticTexts["0.5 l of Whole milk thrown away"], "The message of the quantity did not show")
        waitToGo(quantity, "The sheet did not close")
        wait(for: element("batch_sample-batch-4"), toHaveLabelWith: "1.5 l")
        wait(for: app.staticTexts["food_summary"], toHaveLabel: "Dairy, 2.5 l")
        XCTAssertTrue(element("batch_sample-batch-3").label.contains("1 l"), "The quantity came from a different batch")

        // The menu of the card on My Fridge asks for a quantity of the food in that storage area.
        app.navigationBars.buttons.firstMatch.tap()
        let milk = scrollTo(card("sample-milk", area: "fridge"), "My Fridge does not show the milk")
        XCTAssertTrue(value(of: milk).contains("2.5 l"), value(of: milk))
        scrollTo(app.buttons["food_menu_sample-milk/fridge"], "The card of the milk has no menu").tap()
        expect(app.buttons["menu_used"], "The menu of the card has no Used").tap()
        quantity = expect(app.textFields["field_quantity"], "The sheet for the quantity did not open from the card")
        XCTAssertEqual(quantity.value as? String, "1")
        XCTAssertTrue(app.staticTexts["take_available"].label.hasPrefix("Whole milk: you have 2.5 l."), app.staticTexts["take_available"].label)
        replaceText(of: quantity, with: "2")
        app.buttons["take_confirm"].tap()
        expect(app.staticTexts["2 l of Whole milk used"], "The message of the quantity did not show on My Fridge")
        waitToGo(quantity, "The sheet did not close")
        // The milk now expires later, so its card is at a different place in the list. With large text, that place
        // is below the screen.
        wait(for: scrollTo(milk, "My Fridge does not show the milk after the use"), toHaveValueWith: "0.5 l")

        // The close button of the sheet records nothing.
        scrollTo(app.buttons["food_menu_sample-milk/fridge"], "The card of the milk has no menu").tap()
        expect(app.buttons["menu_thrown_away"], "The menu of the card has no Thrown away").tap()
        expect(app.buttons["take_close"], "The sheet has no close button").tap()
        waitToGo(app.textFields["field_quantity"], "The sheet did not close")
        XCTAssertTrue(value(of: milk).contains("0.5 l"), "The closed sheet recorded a quantity: \(value(of: milk))")
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

    /// Opens the screen of a food from My Fridge, and makes sure that it is the screen of the food with the `name`.
    private func openFood(_ productId: String, name: String) {
        XCTAssertEqual(openFood(productId).label, name)
    }
}
