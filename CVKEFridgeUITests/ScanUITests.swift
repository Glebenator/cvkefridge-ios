import XCTest

/// From a barcode to a saved food, through the production code: the scanner, the product lookup with its cache, the
/// add form, and the change log. The tests type the barcode, which is the second way into the same lookup: the
/// Simulator has no camera. The answers of Open Food Facts are fixtures (`CVKE_HTTP_FIXTURES`), so no test uses the
/// network. The Android file `BarcodeDeviceTest.kt` has the same cases.
///
/// The live camera needs a real iPhone: the picture, the read of a barcode, the focus, the light, and the rotation
/// of the picture. `test7` shows the layout of the camera state with a drawn picture (`-scanStandIn`).
final class ScanUITests: FridgeUITestCase {
    /// The answer of Open Food Facts for the barcode 3017620422003 on 12 November 2026.
    private static let nutella = #"{"code":"3017620422003","product":{"brands":"Ferrero, Nutella","categories_tags":["en:breakfasts","en:spreads","en:sweet-spreads","fr:pates-a-tartiner","en:hazelnut-spreads","en:confectionary-based-spreads","fr:Nutella"],"generic_name":"Hazelnut And Cocoa Spread","product_name":"Nutella","product_name_en":"Nutella","quantity":"400 g e"},"status":1,"status_verbose":"product found"}"#

    private static let storageText = "Bei -18 °C mindestens haltbar bis: siehe Seitenlasche."

    /// A frozen pizza in the form of an answer of Open Food Facts. It is not a real answer.
    private static let frozenPizza = #"{"code":"4006381333931","product":{"brands":"Dr. Oetker","categories_tags":["en:frozen-foods","en:meals","en:pizzas-pies-and-quiches","en:pizzas","en:frozen-pizzas-and-pies","en:frozen-pizzas"],"conservation_conditions":"\#(storageText)","product_name":"Ristorante Mozzarella","quantity":"355 g"},"status":1,"status_verbose":"product found"}"#

    private static let notFound = #"{"code":"4099999999996","status":0,"status_verbose":"product not found"}"#

    override func setUp() async throws {
        try await super.setUp()
        // A test that failed on a wide screen can leave the Simulator turned.
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Steps

    /// The add form above the scanner, with its name field.
    @discardableResult
    private func expectForm(name: String) -> XCUIElement {
        let field = expectAddForm("The add form did not open above the scanner")
        // An empty field gives its placeholder as its value.
        let value = field.value as? String ?? ""
        XCTAssertEqual(value == field.placeholderValue ? "" : value, name, "The name of the form")
        return field
    }

    private func expectScannerOnly() {
        expect(app.buttons["type_barcode"], "The scanner does not show again")
        waitToGo(app.navigationBars["Add food"], "The add form stayed above the scanner")
    }

    private func expectHomeTotal(_ total: String) {
        tab("Home").tap()
        let hero = expect(app.staticTexts["hero_total"], "Home does not show the number of foods")
        wait(for: [expectation(for: NSPredicate(format: "label == %@", total), evaluatedWith: hero)], timeout: 10)
    }

    /// The note at the top of the add form after a scan: where the values come from, and the barcode that the food
    /// keeps.
    private func expectScanNote(source: String, barcode: String) {
        // With large text, the note is above the screen after the scroll to the name field.
        let note = scrollBackTo(element("scan_note"), "The form does not say where its values come from")
        XCTAssertTrue(note.label.hasPrefix(source), "The note of the scan does not start with \"\(source)\": \(note.label)")
        XCTAssertTrue(note.label.contains("Barcode \(barcode)."), "The note of the scan does not show the barcode: \(note.label)")
    }

    // MARK: - Tests

    func test1AFoundProductFillsInTheFormAndTheNextScanFindsItInTheInventory() throws {
        launch(inventory: .empty, lookups: ["3017620422003": .response(body: Self.nutella)])
        openScanner()
        // The scanner says what leaves the phone.
        let privacy = expect(element("scan_privacy"), "The scanner does not say what leaves the phone")
        XCTAssertTrue(privacy.label.contains("Only the barcode number goes to Open Food Facts"), privacy.label)
        // The Simulator has no camera. The scanner says so, and it works with a typed barcode.
        expect(app.staticTexts["No camera on this device"], "The scanner does not say that there is no camera")
        capture("scan-no-camera")
        typeBarcode("3017620422003")

        expectForm(name: "Nutella")
        expectScanNote(source: "From Open Food Facts. Check the values before you save.", barcode: "3017620422003")
        for (field, value) in [("field_category", "Condiment"), ("field_quantity", "400"), ("field_unit", "g")] {
            // With large text, a field can be below the screen.
            let picker = scrolledTo(field)
            let shown = "\(picker.label) \(picker.value as? String ?? "")"
            XCTAssertTrue(shown.contains(value), "\(field) shows \(shown), not \(value)")
        }
        capture("scan-form-after-lookup")
        app.buttons["save"].tap()

        // "Save" closes the form and the scanner.
        expect(app.staticTexts["Nutella added"], "The message of the add did not show")
        expect(app.buttons["my_fridge_menu"], "The form and the scanner did not close")
        XCTAssertFalse(app.buttons["type_barcode"].exists, "The scanner stayed open after Save")
        expectHomeTotal("1")

        // The second scan of the barcode finds the product in the inventory. The form adds a batch to it.
        openScanner()
        typeBarcode("3017620422003")
        expectForm(name: "Nutella")
        // The product is in the inventory now. The form says that it adds a batch, and it has no note of a lookup.
        let existing = scrollTo(element("name_existing"), "The form does not say that it adds a batch")
        XCTAssertEqual(existing.label, "This food is in your inventory. The form adds a batch to it.")
        XCTAssertFalse(element("scan_note").exists, "A food of the inventory has a note of the lookup")
        tapFormButton("save_scan_next")

        // "Save and scan next" shows the scanner again. The message is above the panel: "Undo" is there, and the
        // buttons of the panel are not under the message.
        expectScannerOnly()
        expect(app.staticTexts["Nutella added"], "The message of the second add did not show")
        let undo = expect(app.buttons["Undo"], "The message has no Undo")
        let panel = expect(element("scan_panel"), "The scanner has no panel")
        XCTAssertLessThanOrEqual(undo.frame.maxY, panel.frame.minY, "The message is not above the panel")
        XCTAssertFalse(undo.frame.intersects(panel.frame), "The message covers the panel")
        capture("scan-notice-above-panel")
    }

    func test2AFrozenProductGetsTheFreezerFromItsStorageHintAndShowsThePackageText() throws {
        launch(inventory: .empty, lookups: ["4006381333931": .response(body: Self.frozenPizza)])
        openScanner()
        typeBarcode("4006381333931")

        // The name has no food of the table of foods. The storage text of the package gives the freezer.
        expectForm(name: "Dr. Oetker Ristorante Mozzarella")
        // The form says where the values come from.
        expectScanNote(source: "From Open Food Facts. Check the values before you save.", barcode: "4006381333931")
        let area = scrollTo(app.buttons["field_area"].firstMatch, "The form has no storage area")
        XCTAssertEqual(area.value as? String, "Freezer", "The storage hint did not select the freezer")
        capture("scan-form-frozen")
        // The storage tips show the text of the package, with its source. The name has no food of the table of
        // foods, so there is no general advice.
        let package = scrollTo(element("storage_advice_package"), "The form does not show the text of the package")
        XCTAssertEqual(package.label, Self.storageText)
        XCTAssertTrue(app.staticTexts["From the package"].exists, "The text of the package does not name its source")
        XCTAssertFalse(element("storage_advice_general").exists, "A name with no food of the table has general advice")
        capture("scan-form-frozen-storage-tips")
        app.buttons["save"].tap()

        expect(app.staticTexts["Dr. Oetker Ristorante Mozzarella added"], "The message of the add did not show")
        expectHomeTotal("1")
    }

    func test3ABarcodeThatOpenFoodFactsDoesNotHaveKeepsTheBarcodeAndAsksForTheName() throws {
        launch(inventory: .empty, lookups: ["4099999999996": .response(status: 404, body: Self.notFound)])
        openScanner()
        typeBarcode("4099999999996")

        let name = expectForm(name: "")
        expectScanNote(source: "Open Food Facts has no product with this barcode. Type the name.", barcode: "4099999999996")
        scrollTo(name, "The name field is not on the screen")
        // The empty name field has the keyboard, so the person types the name at once.
        wait(for: name, toMatch: NSPredicate(format: "hasKeyboardFocus == true"), "The empty name field does not have the keyboard")
        capture("scan-form-not-found")
        name.typeText("Oat drink")
        tapFormButton("save_scan_next")

        // "Save and scan next" shows the scanner again.
        expectScannerOnly()
        expect(app.staticTexts["Oat drink added"], "The message of the add did not show")
        app.buttons["scan_close"].tap()
        expectHomeTotal("1")
    }

    func test4WithNoConnectionTheScannerSaysSoAndKeepsTheBarcodeForEnterByHand() throws {
        launch(inventory: .empty, lookups: ["5449000000996": .noConnection])
        openScanner()

        // A typed number with a wrong check digit is not looked up.
        typeBarcode("5449000000997")
        let problem = expect(app.staticTexts["error_barcode"], "The sheet does not show the wrong check digit")
        XCTAssertTrue(problem.label.contains("A digit is not correct"), problem.label)
        XCTAssertFalse(element("lookup_failed").exists)
        capture("scan-wrong-check-digit")
        app.buttons["barcode_cancel"].tap()
        expect(app.buttons["type_barcode"], "The sheet did not close")
        XCTAssertFalse(element("lookup_failed").exists, "A number with a wrong check digit was looked up")

        typeBarcode("5449000000996")
        let failed = expect(element("lookup_failed"), "The scanner does not show the failed lookup")
        XCTAssertTrue(failed.label.contains("No connection"), failed.label)
        XCTAssertTrue(failed.label.contains("5449000000996"), "The failure does not name the barcode that stays")
        capture("scan-no-connection")

        // "Try again" does one lookup. The app never tries again by itself.
        app.buttons["lookup_try_again"].tap()
        expect(element("lookup_failed"), "The scanner does not show the second failed lookup")

        // "Scan again" forgets the barcode, and the panel has its two buttons again.
        app.buttons["scan_again"].tap()
        expect(app.buttons["scan_add_by_hand"], "\"Scan again\" did not show the panel of the scanner")

        typeBarcode("5449000000996")
        expect(element("lookup_failed"), "The scanner does not show the failed lookup")
        app.buttons["enter_by_hand"].tap()
        let name = expectForm(name: "")
        // The form shows the barcode that the food keeps, and says that the app did not look it up.
        expectScanNote(source: "The app could not look up this barcode. Type the name.", barcode: "5449000000996")
        scrollTo(name, "The name field is not on the screen")
        wait(for: name, toMatch: NSPredicate(format: "hasKeyboardFocus == true"), "The empty name field does not have the keyboard")
        name.typeText("Cola")
        app.buttons["save"].tap()

        expect(app.staticTexts["Cola added"], "The message of the add did not show")
        expect(app.buttons["my_fridge_menu"], "The form and the scanner did not close")
        expectHomeTotal("1")

        // The food kept the barcode: the next scan finds it in the inventory, with no lookup. The lookup has no
        // connection, so a lookup shows the failure.
        openScanner()
        typeBarcode("5449000000996")
        expectForm(name: "Cola")
        XCTAssertFalse(element("lookup_failed").exists, "The scan of a kept barcode used the network")
        scrollTo(element("name_existing"), "The form does not say that it adds a batch to the food")
    }

    func test5EachFailureOfTheLookupHasItsWords() throws {
        launch(inventory: .empty, lookups: [
            "3017620422003": .timeout,
            "4006381333931": .response(status: 429, body: ""),
            "4099999999996": .response(status: 500, body: ""),
        ])
        openScanner()
        for (barcode, title) in [
            ("3017620422003", "Open Food Facts did not answer"),
            ("4006381333931", "Too many lookups"),
            ("4099999999996", "Open Food Facts has a problem"),
        ] {
            typeBarcode(barcode)
            let failed = expect(element("lookup_failed"), "The scanner does not show the failed lookup")
            XCTAssertTrue(failed.label.contains(title), "\(failed.label) does not say \(title)")
            // With a large text size, the panel scrolls to its buttons.
            for button in ["lookup_try_again", "enter_by_hand", "scan_again"] {
                XCTAssertTrue(app.buttons[button].exists, "The failed lookup has no \(button)")
            }
            app.buttons["scan_again"].tap()
            expect(app.buttons["type_barcode"], "\"Scan again\" did not show the panel of the scanner")
        }
    }

    func test6EightDigitsFindAUpcEOfTheInventoryWithNoNetwork() throws {
        // "01234565" is a valid EAN-8, and as a UPC-E it is the barcode 0012345000065 of the product. The lookup has
        // no answer for a barcode, so a request to the network gives "No connection".
        let log = """
        {"id":"c-1","at":1,"origin":"phone-1","body":{"type":"productSaved","product":{"id":"p-1","name":"Cola can","category":"beverage","unit":"ml","barcode":"0012345000065","foodId":null}}}
        {"id":"c-2","at":2,"origin":"phone-1","body":{"type":"batchAdded","batch":{"id":"b-1","productId":"p-1","quantity":330000,"storageAreaId":"fridge","dateAdded":"2026-11-10","expiryDate":null,"expirySource":null}}}

        """
        launch(inventory: .changeLog(log))
        openScanner()
        typeBarcode("0123 4565")

        expectForm(name: "Cola can")
        XCTAssertFalse(element("lookup_failed").exists, "The lookup used the network for a barcode of the inventory")
    }

    func test7TheCameraStateShowsTheHintTheLightAndThePanel() throws {
        // A drawn picture is in the place of the camera. The scanner reads no barcode from it.
        launch(inventory: .empty, arguments: ["-scanStandIn"])
        openScanner()

        let hint = expect(app.staticTexts["scan_hint"], "The panel has no hint for the camera")
        XCTAssertEqual(hint.label, "Point the camera at the barcode.")
        XCTAssertTrue(app.buttons["type_barcode"].exists)
        XCTAssertTrue(app.buttons["scan_add_by_hand"].exists)
        capture("scan-camera")

        // The light button names its action.
        let light = expect(app.buttons["torch"], "The camera has no light button")
        XCTAssertEqual(light.label, "Turn on the light")
        light.tap()
        wait(for: [expectation(for: NSPredicate(format: "label == %@", "Turn off the light"), evaluatedWith: light)], timeout: 5)

        // A tap on the picture shows the focus indicator, and the buttons of the panel stay.
        app.images["camera"].tap()
        capture("scan-camera-focus")

        // After some seconds with no barcode, the hint says what helps.
        let slow = NSPredicate(format: "label BEGINSWITH %@", "Can't read the barcode?")
        wait(for: [expectation(for: slow, evaluatedWith: hint)], timeout: 20)
        capture("scan-camera-slow-hint")

        app.buttons["scan_close"].tap()
        expect(app.buttons["my_fridge_menu"], "The scanner did not close")
    }

    func test8OnAWideScreenThePanelIsAtTheSideOfTheCamera() throws {
        launch(inventory: .empty, lookups: ["5449000000996": .noConnection], arguments: ["-scanStandIn"])
        openScanner()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

        let panel = expect(element("scan_panel"), "The scanner has no panel")
        // The panel starts at the top of the screen, after the close button. Below the camera, it starts below it.
        let close = app.buttons["scan_close"]
        let atSide = NSPredicate { _, _ in
            panel.frame.minX > close.frame.maxX && panel.frame.minY < close.frame.maxY
        }
        wait(for: [expectation(for: atSide, evaluatedWith: nil)], timeout: 10)
        for button in ["scan_close", "torch"] {
            XCTAssertTrue(app.buttons[button].isHittable, "The wide scanner has no \(button)")
        }
        for button in ["type_barcode", "scan_add_by_hand"] {
            XCTAssertTrue(app.buttons[button].exists, "The panel of the wide scanner has no \(button)")
        }
        capture("scan-camera-wide")

        // A failed lookup has its three buttons in the panel at the side.
        typeBarcode("5449000000996")
        expect(element("lookup_failed"), "The scanner does not show the failed lookup")
        for button in ["lookup_try_again", "enter_by_hand", "scan_again"] {
            XCTAssertTrue(app.buttons[button].exists, "The failed lookup has no \(button)")
        }
        capture("scan-no-connection-wide")
    }
}
