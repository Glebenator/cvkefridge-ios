import XCTest

/// Home, My Fridge, the quantity question, and the storage areas on a simulator. The tests are the port of
/// `InventoryScreensDeviceTest.kt`, of the card tests of `InventoryChangesDeviceTest.kt`, and of the offer test of
/// `ReminderDeviceTest.kt` of the Android app. The captures are attachments, so CI can show the real screens.
final class InventoryScreensUITests: FridgeUITestCase {
    // MARK: Home

    func test01AnEmptyInventoryShowsZeroOnHomeAndNoCardOnMyFridge() throws {
        launch(inventory: .empty)

        expect(app.staticTexts["home_title"], "Home has no title")
        XCTAssertEqual(app.staticTexts["home_title"].label, "Your Kitchen")
        XCTAssertEqual(expect(app.staticTexts["hero_total"], "Home does not show the number of foods").label, "0")
        scrollTo(app.staticTexts["No items yet"], "Home does not say that the inventory has no food")
        XCTAssertTrue(app.buttons["empty_scan"].exists, "The empty state has no scanner")
        XCTAssertTrue(app.buttons["empty_add"].exists, "The empty state has no add form")
        XCTAssertFalse(app.staticTexts["sample_note"].exists, "An empty inventory is not a sample")
        XCTAssertFalse(app.buttons["reminder_offer_turn_on"].exists, "Home offers reminders with no food")
        capture("home-empty")

        tab("My Fridge").tap()
        expect(app.navigationBars["My Fridge"], "My Fridge did not open")
        expect(app.staticTexts["No items yet"], "My Fridge does not say that the inventory has no food")
        capture("my-fridge-empty")

        // About names the product, its version, and the maker.
        tab("Home").tap()
        expect(app.buttons["about_button"], "Home has no About button").tap()
        expect(app.staticTexts["Made by"], "About does not name the maker")
        XCTAssertTrue(app.images["cvke"].exists || app.otherElements["about_maker"].exists, "About has no maker mark")
        XCTAssertEqual(app.staticTexts["about_app_version"].label, "Version 0.1.0 (1)")
        XCTAssertTrue(app.staticTexts["CVKE Fridge"].exists)
        capture("about")
        app.buttons["about_close"].tap()
        expect(app.staticTexts["hero_total"], "About did not close")
    }

    func test02HomeShowsTheTotalsAndTheBatchesThatNeedAttention() throws {
        launch(inventory: .sample)

        XCTAssertEqual(expect(app.staticTexts["hero_total"], "Home does not show the number of foods").label, "12")
        XCTAssertTrue(app.staticTexts["sample_note"].exists, "The sample is not marked as a sample")
        XCTAssertEqual(app.buttons["metric_expiring"].value as? String, "3")
        XCTAssertEqual(app.buttons["metric_expired"].value as? String, "1")
        capture("home")

        // The expired batch is first. Its card says that the date is an estimate.
        let chicken = scrollTo(app.buttons["attention_sample-batch-1"], "Home does not show the expired batch")
        XCTAssertEqual(chicken.label, "Chicken thighs")
        XCTAssertTrue(value(of: chicken).hasPrefix("Expired yesterday, estimated"), value(of: chicken))
        XCTAssertTrue(value(of: app.buttons["attention_sample-batch-5"]).hasPrefix("Expires in 2d"))
        // A fresh batch is not on Home.
        XCTAssertFalse(app.buttons["attention_sample-batch-6"].exists)
        capture("home-needs-attention")

        // A card opens the food.
        chicken.tap()
        expect(app.staticTexts["food_name"], "The card did not open the food")
        tab("Home").tap()

        // The number of expiring batches opens My Fridge with the food that is expiring, in all storage areas.
        scrollBackTo(app.buttons["metric_expiring"], "Home does not show the expiring food").tap()
        expect(app.navigationBars["My Fridge"], "My Fridge did not open")
        XCTAssertTrue(areaTab("All").isSelected, "The count of Home did not show all storage areas")
        XCTAssertTrue(isOn(app.switches["filter_expiring"]), "The count of Home did not turn on its filter")
        XCTAssertFalse(isOn(app.switches["filter_expired"]))
        scrollTo(app.buttons["food_sample-spinach/fridge"], "My Fridge does not show the card food_sample-spinach/fridge")
        XCTAssertFalse(app.buttons["food_sample-chicken/fridge"].exists)
        capture("my-fridge-expiring")

        // A tap on the selected tab starts My Fridge again: the Fridge, with no filter.
        tab("My Fridge").tap()
        wait(for: areaTab("Fridge"), toBeSelected: true)
        XCTAssertFalse(isOn(app.switches["filter_expiring"]))
        scrollTo(app.buttons["food_sample-chicken/fridge"], "My Fridge does not show the card food_sample-chicken/fridge")

        // "View all" opens My Fridge with no filter.
        tab("Home").tap()
        scrollTo(app.buttons["View all"], "Home has no View all").tap()
        expect(app.navigationBars["My Fridge"], "My Fridge did not open")
        XCTAssertTrue(areaTab("All").isSelected)
        XCTAssertFalse(isOn(app.switches["filter_expiring"]))
        scrollTo(app.buttons["food_sample-chicken/fridge"], "My Fridge does not show the card food_sample-chicken/fridge")
    }

    func test03HomeOffersRemindersAndExplainsTheNotificationsFirst() throws {
        launch(inventory: .sample, notifications: "ask")

        // Home offers reminders, because the inventory has food with an expiry date. Nothing asks at the start.
        let turnOn = scrollTo(app.buttons["reminder_offer_turn_on"], "Home does not offer reminders")
        XCTAssertFalse(app.alerts.firstMatch.exists, "The app asked at the start")
        turnOn.tap()

        // The explanation comes before the question of the system.
        let explanation = expect(app.alerts["Allow notifications"], "The app did not explain the notifications")
        capture("reminder-explanation")
        explanation.buttons["Continue"].firstMatch.tap()
        expect(app.staticTexts["Reminders are on"], "The message of the reminders did not show")
        XCTAssertFalse(app.buttons["reminder_offer_turn_on"].exists, "The offer stayed after reminders were on")
    }

    func test04NotNowClosesTheOfferOfRemindersAndBlockedNotificationsOpenTheSettings() throws {
        launch(inventory: .sample, notifications: "blocked")

        // The notifications are off in the Settings app. The app says so, and it does not ask.
        scrollTo(app.buttons["reminder_offer_turn_on"], "Home does not offer reminders").tap()
        let off = expect(app.alerts["Notifications are off"], "The app did not say that the notifications are off")
        XCTAssertTrue(off.buttons["Open settings"].firstMatch.exists)
        off.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(app.buttons["reminder_offer_turn_on"].exists, "The offer closed with no answer")

        app.buttons["reminder_offer_dismiss"].tap()
        expect(app.staticTexts["You can turn on reminders in Settings at any time."], "The app did not say where the switch is")
        XCTAssertFalse(app.buttons["reminder_offer_turn_on"].exists, "The offer stayed after Not now")
    }

    func test05HomeSaysThatSomeChangesWereNotRead() throws {
        let log = """
        {"id":"c-1","at":1,"origin":"phone-1","body":{"type":"productSaved","product":{"id":"p-1","name":"Butter","category":"dairy","unit":"g","barcode":null,"foodId":null}}}
        this line is not a change
        {"id":"c-2","at":2,"origin":"phone-1","body":{"type":"batchAdded","batch":{"id":"b-1","productId":"p-1","quantity":250000,"storageAreaId":"fridge","dateAdded":"2026-11-10","expiryDate":null,"expirySource":null}}}

        """
        launch(inventory: .changeLog(log))

        XCTAssertEqual(expect(app.staticTexts["hero_total"], "The inventory did not load").label, "1")
        // The note stays on Home after the message went away.
        let note = expect(app.staticTexts["skipped_changes_note"], "Home has no note about the lines that were not read")
        XCTAssertTrue(note.label.hasPrefix("1 change in the inventory file"), note.label)
        // The food has no expiry date, so nothing needs attention, and Home does not offer reminders.
        XCTAssertTrue(app.staticTexts["All fresh"].exists)
        XCTAssertFalse(app.buttons["reminder_offer_turn_on"].exists)
    }

    // MARK: My Fridge

    func test06MyFridgeFiltersSearchesAndSorts() throws {
        launch(inventory: .sample)
        tab("My Fridge").tap()
        expect(app.navigationBars["My Fridge"], "My Fridge did not open")

        // My Fridge opens on the Fridge. The test starts with all storage areas.
        XCTAssertTrue(areaTab("Fridge").isSelected)
        selectArea("All")

        // The list starts with the food that expires first. One card has both batches of the milk in the Fridge.
        let milk = scrollTo(app.buttons["food_sample-milk/fridge"], "My Fridge does not show the milk")
        XCTAssertTrue(value(of: milk).contains("2 expiry dates"), value(of: milk))
        XCTAssertTrue(value(of: milk).contains("Opened on Tuesday"), "The card does not show the note")
        // On the tab of all storage areas, a card names its storage area.
        XCTAssertTrue(value(of: milk).contains("Fridge"), value(of: milk))

        // The search field goes away when the list scrolls up. It comes back at the top of the list.
        let search = app.searchFields.firstMatch
        var swipes = 0
        while !search.exists && swipes < 8 {
            app.swipeDown(velocity: .slow)
            swipes += 1
        }
        expect(search, "My Fridge has no search field").tap()
        search.typeText("ket")
        scrollTo(app.buttons["food_sample-ketchup/sample-pantry"], "The search did not find the ketchup")
        XCTAssertFalse(app.buttons["food_sample-milk/fridge"].exists)

        // The storage areas are tabs. The search text stays when the tab changes.
        selectArea("Freezer")
        expect(app.staticTexts["No matching items"], "The Freezer shows food for a search text that it does not have")
        XCTAssertFalse(app.buttons["filter_clear"].exists, "Clear filters shows with no filter")
        capture("my-fridge-no-match")
        clearText(of: search)
        // With an empty search text, the "search" key does not close the keyboard. With large text, the keyboard
        // covers the second card, so the search closes.
        closeSearch()
        scrollTo(app.buttons["food_sample-bread/freezer"], "The Freezer does not show the bread")
        // With large text, the second card is below the screen.
        scrollTo(app.buttons["food_sample-peas/freezer"], "The Freezer does not show the peas")

        // The search compares the words on the screen: the name of a category finds its food.
        type("bakery", in: search)
        scrollTo(app.buttons["food_sample-bread/freezer"], "The search did not find the category")
        XCTAssertFalse(app.buttons["food_sample-peas/freezer"].exists)
        clearText(of: search)
        closeSearch()

        // The menu of the category chip has the categories with food in the Freezer, with the number of foods.
        chip("filter_category").tap()
        let all = expect(app.buttons["category_all"], "The menu of the categories did not open")
        XCTAssertEqual(all.label, "All categories")
        XCTAssertTrue(all.isSelected, "All categories is not the selected item")
        XCTAssertTrue(app.buttons["category_produce"].exists)
        XCTAssertFalse(app.buttons["category_dairy"].exists)
        capture("my-fridge-category-menu")
        app.buttons["category_bakery"].tap()
        wait(for: chip("filter_category"), toHaveValue: "Bakery")
        scrollTo(app.buttons["food_sample-bread/freezer"], "My Fridge does not show the card food_sample-bread/freezer")
        XCTAssertFalse(app.buttons["food_sample-peas/freezer"].exists)

        // No bakery food in the Freezer is expired. "Clear filters" shows the food of the Freezer again.
        XCTAssertEqual(chip("filter_expired").label, "Freshness: Expired, 0 items")
        chip("filter_expired").tap()
        expect(app.staticTexts["No matching items"], "The list shows food that is not expired")
        scrollTo(app.buttons["filter_clear"], "The list with no food for the filters has no Clear filters").tap()
        scrollTo(app.buttons["food_sample-peas/freezer"], "Clear filters did not show the food again")
        XCTAssertFalse(isOn(chip("filter_expired")))
        XCTAssertEqual(value(of: chip("filter_category")), "")

        // The two freshness chips together show the food that is expiring or expired.
        selectArea("All")
        chip("filter_expired").tap()
        // The expired food is the first card, and the list has only that card.
        XCTAssertEqual(firstCard.identifier, "food_sample-chicken/fridge", "The list does not show the expired food")
        XCTAssertFalse(app.buttons["food_sample-spinach/fridge"].exists)
        chip("filter_expiring").tap()
        scrollTo(app.buttons["food_sample-spinach/fridge"], "The list does not show the expiring food")
        scrollBackTo(app.buttons["food_sample-chicken/fridge"], "The list does not show the expired food with the two filters")
        capture("my-fridge-two-filters")
        chip("filter_expired").tap()
        chip("filter_expiring").tap()
        scrollTo(app.buttons["food_sample-cheddar/fridge"], "The list does not show the fresh food with no filter")

        // The sort order by name, and then its other direction. Baby spinach is the first name, and Whole milk is
        // the last name.
        app.buttons["sort_key"].tap()
        expect(app.buttons["sort_option_name"], "The menu of the sort orders did not open").tap()
        XCTAssertEqual(app.buttons["sort_order"].label, "Ascending order")
        _ = chip("filter_category")
        XCTAssertEqual(firstCard.identifier, "food_sample-spinach/fridge", "The list is not in the order of the names")
        app.buttons["sort_order"].tap()
        XCTAssertEqual(app.buttons["sort_order"].label, "Descending order")
        _ = chip("filter_category")
        XCTAssertEqual(firstCard.identifier, "food_sample-milk/fridge", "The list is not in the opposite order")

        // A tap on the selected tab starts My Fridge again. The sort order stays.
        tab("My Fridge").tap()
        wait(for: areaTab("Fridge"), toBeSelected: true)
        XCTAssertEqual(app.buttons["sort_order"].label, "Descending order")
    }

    func test07ASwipeRecordsTheOldestBatchAndUndoBringsItBack() throws {
        launch(inventory: .sample)
        tab("My Fridge").tap()
        // In the order of the names, a card stays in its place when its batch to use first changes.
        expect(app.buttons["sort_key"], "My Fridge has no sort order").tap()
        expect(app.buttons["sort_option_name"], "The menu of the sort orders did not open").tap()
        let milk = scrollTo(app.buttons["food_sample-milk/fridge"], "My Fridge does not show the milk")
        XCTAssertTrue(value(of: milk).contains("3 l"), value(of: milk))

        // The oldest batch of the milk has 1 l. A swipe from the leading side records it as used.
        swipeRow(milk, fromLeading: true)
        expect(app.staticTexts["1 l of Whole milk used"], "The message of the swipe to the trailing side did not show")
        capture("my-fridge-used-undo")
        wait(for: milk, toHaveValueWith: "2 l")

        app.buttons["Undo"].tap()
        wait(for: milk, toHaveValueWith: "3 l")

        // A swipe from the trailing side records the oldest batch as thrown away.
        let spinach = scrollBackTo(app.buttons["food_sample-spinach/fridge"], "My Fridge does not show the spinach")
        swipeRow(spinach, fromLeading: false)
        expect(app.staticTexts["200 g of Baby spinach thrown away"], "The message of the swipe to the leading side did not show")
        capture("my-fridge-thrown-away-undo")
        XCTAssertTrue(app.buttons["Undo"].exists)
        // The spinach had one batch, so its card goes.
        waitToGo(spinach, "The card stayed after its one batch was thrown away")
    }

    func test08TheMenuOfACardRecordsAQuantityAsThrownAway() throws {
        launch(inventory: .sample)
        tab("My Fridge").tap()
        let cheddar = scrollTo(app.buttons["food_sample-cheddar/fridge"], "My Fridge does not show the cheddar")
        XCTAssertTrue(value(of: cheddar).contains("350 g"), value(of: cheddar))
        app.buttons["food_menu_sample-cheddar/fridge"].tap()
        capture("my-fridge-card-menu")
        // "Delete" is only in the menu, with the other actions.
        for item in ["menu_used", "menu_thrown_away", "menu_add_batch", "menu_edit", "menu_delete"] {
            XCTAssertTrue(app.buttons[item].waitForExistence(timeout: 5), "The menu of the card has no \(item)")
        }
        app.buttons["menu_thrown_away"].tap()

        // The sheet starts with the quantity of the oldest batch, and it does not take more than the food has.
        let quantity = expect(app.textFields["field_quantity"], "The sheet for the quantity did not open")
        XCTAssertEqual(quantity.value as? String, "350")
        XCTAssertTrue(app.staticTexts["How much was thrown away?"].exists)
        XCTAssertTrue(app.staticTexts["Cheddar: you have 350 g. The quantity comes from the oldest batch first."].exists)
        capture("take-quantity")
        replaceText(of: quantity, with: "400")
        app.buttons["take_confirm"].tap()
        expect(app.staticTexts["You have only 350 g."], "The sheet took more than the food has")
        capture("take-quantity-too-much")
        replaceText(of: quantity, with: "100")
        app.buttons["take_confirm"].tap()

        expect(app.staticTexts["100 g of Cheddar thrown away"], "The message of the quantity did not show")
        waitToGo(quantity, "The sheet did not close")
        wait(for: cheddar, toHaveValueWith: "250 g")

        // With one item left, the menu records it with no question.
        // With large text, the juice can be above the part of the list that shows.
        scrollBackTo(app.buttons["food_menu_sample-juice/fridge"], "My Fridge does not show the juice").tap()
        expect(app.buttons["menu_used"], "The menu of the card did not open").tap()
        expect(app.staticTexts["1 bottle of Orange juice used"], "One item left was not recorded at once")
        XCTAssertFalse(app.textFields["field_quantity"].exists, "The sheet opened for one item")
    }

    func test09TheMenuOfACardDeletesItsBatchesWithUndoAndOpensTheForms() throws {
        launch(inventory: .sample)
        tab("My Fridge").tap()
        let cheddar = scrollTo(app.buttons["food_sample-cheddar/fridge"], "My Fridge does not show the cheddar")

        app.buttons["food_menu_sample-cheddar/fridge"].tap()
        expect(app.buttons["menu_delete"], "The menu of the card did not open").tap()
        // The cheddar has no other batch, so the food goes with its batch.
        expect(app.staticTexts["Cheddar deleted"], "The message of the delete did not show")
        waitToGo(cheddar, "The card stayed after the delete")
        app.buttons["Undo"].tap()
        expect(cheddar, "Undo did not bring the card back")

        // "Add a batch" opens the add form for the food, and "Edit" opens the form of the food.
        scrollTo(app.buttons["food_menu_sample-cheddar/fridge"], "The card has no menu").tap()
        expect(app.buttons["menu_add_batch"], "The menu of the card did not open").tap()
        let name = expect(app.textFields["field_name"], "The add form did not open")
        XCTAssertEqual(name.value as? String, "Cheddar")
        app.buttons["form_close"].tap()

        scrollTo(app.buttons["food_menu_sample-cheddar/fridge"], "The card has no menu").tap()
        expect(app.buttons["menu_edit"], "The menu of the card did not open").tap()
        expect(app.navigationBars["Edit food"], "The edit form did not open")
        app.buttons["form_close"].tap()

        // A tap on the card opens the food.
        scrollTo(cheddar, "My Fridge does not show the cheddar").tap()
        expect(app.staticTexts["food_name"], "The food did not open")
    }

    // MARK: Storage areas

    func test10ANewStorageAreaHasATabOnMyFridge() throws {
        launch(inventory: .sample)
        tab("My Fridge").tap()
        expect(app.buttons["my_fridge_menu"], "My Fridge has no menu").tap()
        expect(app.buttons["menu_storage_areas"], "The menu has no storage areas").tap()
        expect(app.navigationBars["Storage areas"], "The storage areas did not open")
        XCTAssertEqual(app.staticTexts["area_card_fridge"].label, "Fridge, Fridge • 8 items • Fixed")
        XCTAssertEqual(app.staticTexts["area_card_freezer"].label, "Freezer, Freezer • 2 items • Fixed")
        XCTAssertEqual(app.buttons["area_card_sample-pantry"].label, "Pantry, Pantry • 2 items")
        capture("storage-areas")

        // The name of another storage area is not accepted. Case has no effect.
        app.buttons["add_area"].tap()
        let name = expect(app.textFields["field_area_name"], "The form of the storage area did not open")
        name.typeText("pantry")
        app.buttons["area_save"].tap()
        expect(app.staticTexts["Another storage area has this name."], "The form accepted the name of another storage area")
        capture("storage-area-form")
        replaceText(of: name, with: "Cellar")
        // With large text, the button of the form is above the keyboard and covers the storage kind.
        hideKeyboard()
        scrollTo(app.buttons["field_storage_kind"], "The form has no storage kind").tap()
        expect(app.buttons["storage_kind_option_fridge"], "The menu of the storage kinds did not open").tap()
        app.buttons["area_save"].tap()
        let cellar = expect(app.buttons["Cellar, Fridge • 0 items"], "The new storage area is not in the list")
        waitToGo(name, "The form did not close")

        // A storage area with food cannot be deleted. The screen says why.
        app.buttons["area_menu_sample-pantry"].tap()
        expect(app.buttons["menu_delete_area"], "The menu of the storage area did not open").tap()
        let inUse = expect(app.alerts["Pantry has food in it"], "The screen did not say why the delete is not possible")
        XCTAssertTrue(inUse.staticTexts["Pantry has 2 items. Move them to a different storage area, or record them as used or thrown away. Then delete the storage area."].exists)
        capture("storage-area-in-use")
        inUse.buttons["OK"].firstMatch.tap()
        XCTAssertTrue(app.buttons["area_card_sample-pantry"].exists)

        // An empty storage area goes, and "Undo" brings it back.
        swipeRow(scrollTo(cellar, "The new storage area is not on the screen"), fromLeading: false)
        capture("storage-area-swipe")
        expect(app.buttons["swipe_delete_area"], "The swipe has no Delete").tap()
        expect(app.staticTexts["Cellar deleted"], "The message of the delete did not show")
        waitToGo(cellar, "The storage area stayed after the delete")
        app.buttons["Undo"].tap()
        expect(cellar, "Undo did not bring the storage area back")

        // A tap opens the form with the values of the storage area. A new name shows in the list.
        cellar.tap()
        let edited = expect(app.textFields["field_area_name"], "The form of the storage area did not open")
        XCTAssertEqual(edited.value as? String, "Cellar")
        XCTAssertTrue(app.navigationBars["Edit storage area"].exists)
        replaceText(of: edited, with: "Wine fridge")
        app.buttons["area_save"].tap()
        expect(app.buttons["Wine fridge, Fridge • 0 items"], "The new name is not in the list")

        // The new storage area has a tab on My Fridge.
        app.navigationBars["Storage areas"].buttons.firstMatch.tap()
        expect(app.buttons["my_fridge_menu"], "The back button did not go to My Fridge")
        // With large text, the new tab is out of the screen, and the row scrolls sideways.
        selectArea("Wine fridge")
        expect(app.staticTexts["No items yet"], "The new storage area is not empty")
        capture("my-fridge-new-area")
    }

    func test11TheStorageAreasOpenAboveAFormAndANewStorageAreaIsInTheListOfTheForm() throws {
        launch(inventory: .sample)
        expect(app.staticTexts["hero_total"], "Home does not show the number of foods")
        tab("Add food").tap()
        expect(app.textFields["field_name"], "The add form did not open")

        // "Manage storage areas" of the form opens the storage areas in a sheet above the form. The empty form
        // starts with the keyboard, which covers the storage area.
        hideKeyboard()
        scrollTo(element("field_area"), "The form has no storage area").tap()
        expect(app.buttons["manage_areas"], "The list of the storage areas has no Manage storage areas").tap()
        expect(app.navigationBars["Storage areas"], "The storage areas did not open above the form")
        app.buttons["add_area"].tap()
        let name = expect(app.textFields["field_area_name"], "The form of the storage area did not open")
        name.typeText("Cellar")
        app.buttons["area_save"].tap()
        waitToGo(name, "The form of the storage area did not close")
        expect(app.buttons["Cellar, Pantry • 0 items"], "The new storage area is not in the list")
        capture("storage-areas-above-form")

        // "Done" goes back to the form, and its list has the new storage area.
        app.buttons["storage_areas_done"].tap()
        waitToGo(app.navigationBars["Storage areas"], "The storage areas did not close")
        scrollTo(element("field_area"), "The form has no storage area after the storage areas closed").tap()
        let cellar = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Cellar")).firstMatch
        expect(cellar, "The list of the form does not have the new storage area")
    }

    // MARK: Parts

    /// A chip of the row above the cards of My Fridge, after a scroll to it: the row is the top of the list, and it
    /// goes up with the cards.
    private func chip(_ identifier: String) -> XCUIElement {
        scrollBackTo(element(identifier), "My Fridge has no \(identifier)")
    }

    /// The first card of the list of My Fridge. The list must be at its top: see `chip(_:)`.
    private var firstCard: XCUIElement {
        expect(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "food_sample-")).firstMatch,
            "My Fridge shows no card"
        )
    }

    /// Removes the text of the search field with its "Clear text" button. The button shows only while the field
    /// has the keyboard, and a scroll with large text can close the keyboard.
    private func clearText(of search: XCUIElement) {
        let clear = search.buttons["Clear text"]
        if !clear.exists {
            search.tap()
        }
        expect(clear, "The search field has no Clear text").tap()
    }

    /// Closes the search field of My Fridge, with the button of the system.
    private func closeSearch() {
        for name in ["Close", "Cancel"] {
            let button = app.buttons[name].firstMatch
            if button.exists && button.isHittable {
                button.tap()
                return
            }
        }
    }
}
