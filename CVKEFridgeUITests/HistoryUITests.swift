import XCTest

/// History on a simulator, with a change log of the test: the summary, the list with its outcomes, the filter, the
/// period, and "Add again". It is the port of the parts of `HistoryDeviceTest.kt` of the Android app that do not need a
/// photo. The change log has the uses and the throw aways, so that the test does not depend on the swipes of My Fridge.
/// Today is 14 November 2026 (`FridgeUITestCase.today`).
final class HistoryUITests: FridgeUITestCase {
    func test1NothingEndedSaysSo() throws {
        launch(inventory: .changeLog(log(
            product("t-milk", "Milk", unit: "l"),
            batch("t-milk-1", product: "t-milk", quantity: 2_000, added: "2026-11-12")
        )))
        openHistory()

        expect(element("history_empty"), "History does not say that nothing ended")
        XCTAssertTrue(app.staticTexts["Nothing used or thrown away yet"].exists)
        XCTAssertTrue(app.staticTexts["When you record food as used or as thrown away, it shows here."].exists)
        XCTAssertFalse(element("history_summary").exists, "History shows a summary with no entry")
        capture("history-empty")
    }

    func test2UsedAndThrownAwayFoodIsInHistoryWithItsOutcome() throws {
        launch(inventory: .changeLog(log(
            product("t-milk", "Milk", unit: "l"),
            product("t-cheese", "Cheese", unit: "g"),
            batch("t-milk-1", product: "t-milk", quantity: 2_000, added: "2026-11-12"),
            batch("t-cheese-1", product: "t-cheese", quantity: 200_000, added: "2026-11-12"),
            used("t-milk-1", quantity: 2_000, date: "2026-11-14"),
            thrownAway("t-cheese-1", quantity: 200_000, date: "2026-11-14")
        )))
        let milk = "t-change-5"
        let cheese = "t-change-6"
        openHistory()

        // The summary counts the batches of this month, with their quantities, and names the food thrown away.
        expect(element("history_summary"), "History has no summary")
        XCTAssertEqual(element("summary_used").label, "1 batch used, 2 l")
        XCTAssertEqual(element("summary_thrown_away").label, "1 batch thrown away, 200 g")
        XCTAssertEqual(element("most_thrown_away_t-cheese").label, "Cheese, 1 batch")

        // VoiceOver reads each entry as one item with its outcome and its day. The newest entry is first. With large
        // text, the list makes its rows when they come on the screen.
        scrollTo(element("history_day_2026-11-14"), "History has no header for today")
        XCTAssertEqual(element("history_day_2026-11-14").label, "Today")
        scrollTo(element("history_\(milk)"), "History does not show the used entry")
        XCTAssertEqual(element("history_\(milk)").label, "Milk, 2 l, Used, Today")
        XCTAssertEqual(element("history_\(cheese)").label, "Cheese, 200 g, Thrown away, Today")
        XCTAssertLessThan(element("history_\(cheese)").frame.minY, element("history_\(milk)").frame.minY)
        capture("history-list")

        // The segmented control shows one outcome.
        let filter = app.segmentedControls["history_filter"]
        filter.buttons["Used"].tap()
        XCTAssertTrue(element("history_\(cheese)").waitForNonExistence(timeout: 5), "Used shows a thrown-away entry")
        XCTAssertTrue(element("history_\(milk)").exists)
        filter.buttons["Thrown away"].tap()
        XCTAssertTrue(element("history_\(milk)").waitForNonExistence(timeout: 5), "Thrown away shows a used entry")
        XCTAssertTrue(element("history_\(cheese)").exists)
        filter.buttons["All"].tap()
        expect(element("history_\(cheese)"), "All does not show the thrown-away entry")

        // A tap on an entry opens the screen of the food.
        scrollTo(element("history_\(milk)"), "All does not show the used entry").tap()
        expect(app.staticTexts["food_name"], "The entry did not open the food")
        XCTAssertEqual(app.staticTexts["food_name"].label, "Milk")
    }

    func test3ThePeriodChangesTheSummaryAndAnEmptyFilterSaysSo() throws {
        launch(inventory: .changeLog(log(
            product("t-cheese", "Cheese", unit: "g"),
            batch("t-cheese-1", product: "t-cheese", quantity: 200_000, added: "2026-10-01"),
            thrownAway("t-cheese-1", quantity: 200_000, date: "2026-10-05")
        )))
        openHistory()

        // Nothing ended in this month.
        expect(element("summary_none"), "The summary of this month does not say that nothing ended")
        XCTAssertEqual(element("summary_none").label, "Nothing was used or thrown away in this time.")

        element("history_period").tap()
        expect(app.buttons["Last month"], "The period has no menu").tap()
        expect(element("summary_thrown_away"), "The summary of last month has no number")
        XCTAssertEqual(element("summary_thrown_away").label, "1 batch thrown away, 200 g")
        XCTAssertEqual(element("summary_used").label, "0 batches used")
        XCTAssertFalse(element("summary_none").exists)

        // A day that is not today or yesterday has the full date.
        scrollTo(element("history_day_2026-10-05"), "History has no header for the day")
        XCTAssertEqual(element("history_day_2026-10-05").label, "Monday, October 5, 2026")

        // A filter with no entry says so.
        app.segmentedControls["history_filter"].buttons["Used"].tap()
        expect(element("history_no_match"), "The filter with no entry does not say so")
        XCTAssertTrue(app.staticTexts["Nothing used yet"].exists)
        XCTAssertFalse(element("history_t-change-3").exists)
        capture("history-no-match")
    }

    func test4AddAgainOpensTheFormWithTheProduct() throws {
        launch(inventory: .changeLog(log(
            // Yogurt of the table of foods: 7 days in the fridge, 30 days in the freezer.
            product("t-yoghurt", "Yoghurt", unit: "pcs", foodId: "fk-33"),
            batch("t-yoghurt-1", product: "t-yoghurt", quantity: 4_000, added: "2026-10-25"),
            batch("t-yoghurt-2", product: "t-yoghurt", quantity: 4_000, area: "freezer", added: "2026-11-04"),
            used("t-yoghurt-1", quantity: 4_000, date: "2026-10-27"),
            thrownAway("t-yoghurt-2", quantity: 4_000, date: "2026-11-12")
        )))
        openHistory()

        // The plus button at the end of the entry opens the add form with the product.
        let entry = scrollTo(element("history_t-change-5"), "History does not show the thrown-away entry")
        entry.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -22, dy: 0)).tap()
        let name = expect(app.textFields["field_name"], "Add again did not open the add form")
        XCTAssertEqual(name.value as? String, "Yoghurt")
        capture("history-add-again")
        app.buttons["save"].tap()

        // The form closes. The new batch is in the inventory, and History stays.
        expect(app.staticTexts["Yoghurt added"], "The add did not show its message")
        XCTAssertFalse(app.textFields["field_name"].exists, "The form did not close")
        XCTAssertTrue(element("history_t-change-5").exists)

        // A swipe to the right on an entry has "Add again" also.
        entry.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: entry.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)))
        expect(app.buttons["Add again"], "The swipe has no Add again").tap()
        expect(app.textFields["field_name"], "The swipe did not open the add form")
    }

    func test5TheSampleIsMarkedAndTheFilterStaysAtTheTop() throws {
        launch(inventory: .sample)
        openHistory()
        expect(element("history_summary"), "History has no summary of the sample")
        XCTAssertTrue(app.staticTexts["sample_note"].exists, "The sample is not marked as a sample")
        capture("history-sample")

        // The filter stays below the navigation bar while the list scrolls.
        let filter = app.segmentedControls["history_filter"]
        var swipes = 0
        while !(filter.exists && filter.frame.minY < app.frame.height / 3) && swipes < 10 {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
        app.swipeUp(velocity: .slow)
        XCTAssertTrue(filter.isHittable, "The filter scrolled away")
        XCTAssertLessThan(filter.frame.minY, app.frame.height / 3, "The filter is not at the top")
        capture("history-sample-scrolled")

        // On a wide screen the content is not wider than the content width, and the filter stays.
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        expect(filter, "The filter is not there after the rotation")
        capture("history-sample-landscape")
    }

    // MARK: - Helpers

    private func openHistory() {
        expect(tab("History"), "The tab bar has no History").tap()
        expect(app.navigationBars["History"], "History did not open")
    }

    /// A change log: one change on each line, with the identifiers `t-change-1`, `t-change-2`, and so on.
    private func log(_ bodies: String...) -> String {
        bodies.enumerated()
            .map { index, body in #"{"id":"t-change-\#(index + 1)","at":\#(index + 1),"origin":"test","body":\#(body)}"# }
            .joined(separator: "\n") + "\n"
    }

    private func product(_ id: String, _ name: String, unit: String, foodId: String? = nil) -> String {
        let food = foodId.map { "\"\($0)\"" } ?? "null"
        return #"{"type":"productSaved","product":{"id":"\#(id)","name":"\#(name)","category":"dairy","unit":"\#(unit)","barcode":null,"foodId":\#(food)}}"#
    }

    private func batch(_ id: String, product: String, quantity: Int, area: String = "fridge", added: String) -> String {
        #"{"type":"batchAdded","batch":{"id":"\#(id)","productId":"\#(product)","quantity":\#(quantity),"storageAreaId":"\#(area)","dateAdded":"\#(added)","expiryDate":null,"expirySource":null}}"#
    }

    private func used(_ batch: String, quantity: Int, date: String) -> String {
        #"{"type":"batchUsed","batchId":"\#(batch)","quantity":\#(quantity),"date":"\#(date)"}"#
    }

    private func thrownAway(_ batch: String, quantity: Int, date: String) -> String {
        #"{"type":"batchThrownAway","batchId":"\#(batch)","quantity":\#(quantity),"date":"\#(date)"}"#
    }
}
