import XCTest

/// The base of the UI tests: it starts the debug build of the app with a data folder of its own, a fixed date, and no
/// network, so that a test does not change the inventory of the person and gives the same result on each day.
/// `App/LaunchOptions.swift` in the app has the list of the launch arguments.
///
/// ```swift
/// final class HomeUITests: FridgeUITestCase {
///     func testTotals() {
///         launch(inventory: .sample)
///         XCTAssertEqual(app.staticTexts["hero_total"].label, "12")
///         capture("home")
///     }
/// }
/// ```
///
/// ## The accessibility identifiers
///
/// The tests find the parts of the app by their accessibility identifiers. The screens give the identifiers, and all
/// screens use one convention. An identifier is in lower case, with `_` between its words.
///
/// | Part | Identifier | Examples |
/// | --- | --- | --- |
/// | A screen or a sheet | `<name>_screen` | `home_screen`, `food_screen`, `add_food_screen`, `scan_screen` |
/// | A part that shows one object | `<part>_<id of the object>` | `batch_<batchId>`, `attention_<batchId>`, `area_card_<areaId>`, `history_<changeId>`, `product_image_<productId>` |
/// | The card of a food on My Fridge | `food_<productId>/<areaId>` | `food_sample-milk/fridge`. A food has one card in each storage area that has a batch of it. |
/// | The menu button of an object | `<part>_menu_<id>` | `food_menu_<productId>/<areaId>`, `batch_menu_<batchId>`, `area_menu_<areaId>` |
/// | An item of a menu | `menu_<action>` | `menu_used`, `menu_thrown_away`, `menu_edit_batch`, `menu_scan` |
/// | A swipe action | `swipe_<action>` | `swipe_used`, `swipe_thrown_away`, `swipe_delete_area` |
/// | A field of a form | `field_<name>` | `field_name`, `field_quantity`, `field_area`, `field_expiry`, `field_barcode` |
/// | An option in the menu of a field | `<name>_option_<value>` | `area_option_freezer`, `unit_option_kg`, `category_option_other`, `sort_option_name` |
/// | The problem of a field | `error_<name>` | `error_name`, `error_quantity`, `error_barcode` |
/// | A button of a form | its action | `save`, `save_another`, `save_scan_next`, `form_close`, `take_confirm`, `area_save` |
/// | A filter of My Fridge | `filter_<name>` | `filter_category`, `filter_expiring`, `filter_expired`, `filter_clear` |
/// | Another part of one screen | `<screen or group>_<part>` | `hero_total`, `metric_expiring`, `food_name`, `food_edit`, `photo_choose`, `scan_close`, `reminders_switch` |
///
/// - The identifier of an object is its identifier in the change log, so a test that makes its own change log knows
///   it.
/// - One identifier is one part on one screen. Two screens can have the same identifier (`save`, `field_quantity`,
///   `menu_used`) when only one of them shows at a time.
/// - The parts of the system have no identifier: the tabs, the titles of the navigation bars, the alerts, and the
///   words of a message ("Undo", "Discard changes"). The tests find them by their English words.
/// - `card(_:area:)`, `areaTab(_:)`, `openMyFridge(area:)`, `openFood(_:)`, `openScanner()`, and `typeBarcode(_:)`
///   of this file have the identifiers of the ways between the screens. When a screen changes one of them, change it
///   here, and not in each test.
@MainActor
class FridgeUITestCase: XCTestCase {
    /// The inventory at the start of the app.
    enum StartInventory {
        /// The sample of the debug build, with dates from `today`.
        case sample
        /// No food.
        case empty
        /// A change log: one change on each line, as the app writes it.
        case changeLog(String)
    }

    /// An answer of the product lookup for one barcode.
    enum LookupAnswer {
        /// The answer of Open Food Facts: the HTTP status and the JSON text.
        case response(status: Int = 200, body: String)
        case timeout
        case noConnection
    }

    // XCUITest objects belong to the main actor, so they are made at first use.
    private(set) lazy var app = XCUIApplication()

    /// The date that the app uses as today, when a test does not give another.
    static let today = "2026-11-14"

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
    }

    /// Starts the app.
    ///
    /// - Parameters:
    ///   - today: The date that the app uses as today, in the form `YYYY-MM-DD`.
    ///   - lookups: The answers of the product lookup, by barcode. A barcode that is not there gets no connection.
    ///   - notifications: What the notification permission says: `ask`, `allowed`, `blocked`, or `alertsOff`.
    ///   - keepsStore: True to keep the files of an earlier start of the same test.
    ///   - arguments: More launch arguments.
    func launch(
        inventory: StartInventory = .sample,
        today: String = FridgeUITestCase.today,
        lookups: [String: LookupAnswer] = [:],
        notifications: String = "ask",
        keepsStore: Bool = false,
        arguments: [String] = []
    ) {
        // The name of the test is the name of its data folder.
        let store = name.filter { $0.isLetter || $0.isNumber }
        var launchArguments = ["-uiTestStore", store, "-today", today]
        if keepsStore {
            launchArguments.append("-uiTestKeepStore")
        }
        switch inventory {
        case .sample:
            launchArguments += ["-inventory", "sample"]
        case .empty:
            launchArguments += ["-inventory", "empty"]
        case .changeLog(let text):
            app.launchEnvironment["CVKE_CHANGE_LOG"] = text
        }
        if !lookups.isEmpty {
            var fixtures: [String: [String: Any]] = [:]
            for (barcode, answer) in lookups {
                switch answer {
                case .response(let status, let body):
                    fixtures[barcode] = ["status": status, "body": body]
                case .timeout:
                    fixtures[barcode] = ["error": "timeout"]
                case .noConnection:
                    fixtures[barcode] = ["error": "noConnection"]
                }
            }
            if let data = try? JSONSerialization.data(withJSONObject: fixtures),
               let json = String(data: data, encoding: .utf8) {
                app.launchEnvironment["CVKE_HTTP_FIXTURES"] = json
            }
        }
        app.launchEnvironment["CVKE_NOTIFICATIONS"] = notifications
        app.launchArguments = launchArguments + arguments
        app.launch()
    }

    /// Attaches a capture of the screen, so that CI can show the real screen.
    func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// A button of the tab bar, by its name: "Home", "My Fridge", "History", "Settings", or "Add food". On an iPad
    /// the tab bar is at the top of the window, and it is not a tab bar for XCTest.
    func tab(_ name: String) -> XCUIElement {
        let inTabBar = app.tabBars.buttons[name].firstMatch
        return inTabBar.exists ? inTabBar : app.buttons[name].firstMatch
    }

    /// Scrolls the screen until the centre of the element is on the part of the screen that no bar covers, and fails
    /// the test with the message when it does not come there. A tap then gets to the element, and not to a bar above
    /// it. A list makes its rows when they come on the screen, so a row can be missing, for example with large text.
    /// While the element is not there, the content moves up to its end, and then down to its start.
    @discardableResult
    func scrollTo(_ element: XCUIElement, _ message: String) -> XCUIElement {
        bring(element, searchingDown: true, message)
    }

    /// Scrolls as `scrollTo`. While the element is not there, the content moves down first: it is for an element
    /// above the part that shows.
    @discardableResult
    func scrollBackTo(_ element: XCUIElement, _ message: String) -> XCUIElement {
        bring(element, searchingDown: false, message)
    }

    /// The buttons of the bars at the bottom edge of the sheets. They float above the content.
    private static let bottomBarButtons = ["save", "save_another", "save_scan_next", "take_confirm", "area_save", "food_note_save"]

    /// The part of the screen, from its top to its bottom, where the content shows with no bar above it: below the
    /// navigation bar and the row of the storage areas, and above the tab bar, the buttons of a form, and the
    /// keyboard.
    private func contentBand() -> ClosedRange<CGFloat> {
        let window = app.frame
        // The navigation bar of a sheet is below the navigation bar of the screen under it, so the lowest one counts.
        var top = window.minY + 100
        let bars = app.navigationBars.allElementsBoundByIndex + [app.scrollViews["area_tabs"]]
        for bar in bars where bar.exists {
            let frame = bar.frame
            if !frame.isEmpty, frame.maxY < window.midY {
                top = max(top, frame.maxY)
            }
        }
        top += 8
        var bottom = window.maxY - 100
        var covers = [app.keyboards.firstMatch, app.toolbars.firstMatch, app.tabBars.firstMatch]
        covers += app.buttons.matching(NSPredicate(format: "identifier IN %@", Self.bottomBarButtons)).allElementsBoundByIndex
        for cover in covers where cover.exists {
            let frame = cover.frame
            if !frame.isEmpty, frame.minY > top {
                bottom = min(bottom, frame.minY)
            }
        }
        // With the largest text and the keyboard, the bars can leave only a small part.
        return top...max(top + 80, bottom - 8)
    }

    private func bring(_ element: XCUIElement, searchingDown: Bool, _ message: String) -> XCUIElement {
        let band = contentBand()
        let height = band.upperBound - band.lowerBound
        let middle = (band.lowerBound + band.upperBound) / 2
        let origin = app.coordinate(withNormalizedOffset: .zero)
        // The drags start at the leading side of the centre, where a card has no menu button.
        let x = app.frame.width * 0.4
        // While the element is not there, the search goes to one end of the content, and then to the other end.
        let firstSearch = 14
        var searches = 0
        for _ in 0..<70 {
            // A positive step moves the content up.
            var step: CGFloat
            if element.exists {
                let y = element.frame.midY
                if band.contains(y) && element.isHittable {
                    return element
                }
                step = max(-height * 0.8, min(height * 0.8, y - middle))
                if abs(step) < 12 {
                    step = step < 0 ? -12 : 12
                }
            } else if searches < firstSearch * 3 {
                let down = (searches < firstSearch) == searchingDown
                step = (down ? 1 : -1) * height * 0.7
                searches += 1
            } else {
                break
            }
            // The finger stops before it goes up, so the content does not move more after the drag.
            origin.withOffset(CGVector(dx: x, dy: middle + step / 2)).press(
                forDuration: 0.05,
                thenDragTo: origin.withOffset(CGVector(dx: x, dy: middle - step / 2)),
                withVelocity: 400,
                thenHoldForDuration: 0.2
            )
        }
        XCTFail(message)
        return element
    }

    /// Waits for an element, and fails the test with the message when it does not come.
    @discardableResult
    func expect(_ element: XCUIElement, _ message: String, timeout: TimeInterval = 10) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message)
        return element
    }

    // MARK: - Parts of each screen

    /// An element of each type, by its identifier. A part that VoiceOver reads as one element is not always a text
    /// or a button for XCTest.
    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// A part of a form or of a long screen, by its identifier, after a scroll to it. A list has only the rows that
    /// are on the screen. With large text, a form has few rows on the screen, so a test scrolls to a row before it
    /// reads the row.
    func scrolledTo(_ identifier: String) -> XCUIElement {
        scrollTo(element(identifier), "The screen has no \(identifier)")
    }

    /// The accessibility value of an element as text.
    func value(of element: XCUIElement) -> String {
        element.value as? String ?? ""
    }

    /// True when a chip that is a switch is on.
    func isOn(_ element: XCUIElement) -> Bool {
        value(of: element) == "1"
    }

    // MARK: - Waits

    /// Waits until the predicate is true for the element, and fails the test with the message when it stays false.
    /// The failure shows the label and the value of the element.
    func wait(
        for element: XCUIElement,
        toMatch predicate: NSPredicate,
        _ message: String,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        if XCTWaiter().wait(for: [expectation], timeout: timeout) != .completed {
            let shown = element.exists ? "label \"\(element.label)\", value \"\(value(of: element))\"" : "no element"
            XCTFail("\(message) (\(shown))", file: file, line: line)
        }
    }

    func wait(for element: XCUIElement, toBeSelected selected: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "isSelected == %@", NSNumber(value: selected))
        let message = selected ? "The element is not selected" : "The element is selected"
        wait(for: element, toMatch: predicate, message, file: file, line: line)
    }

    func wait(for element: XCUIElement, toHaveValue value: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "value == %@", value)
        wait(for: element, toMatch: predicate, "The value is not \"\(value)\"", file: file, line: line)
    }

    func wait(for element: XCUIElement, toHaveValueWith part: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "value CONTAINS %@", part)
        wait(for: element, toMatch: predicate, "The value does not contain \"\(part)\"", file: file, line: line)
    }

    func wait(for element: XCUIElement, toHaveLabel label: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label == %@", label)
        wait(for: element, toMatch: predicate, "The label is not \"\(label)\"", file: file, line: line)
    }

    func wait(for element: XCUIElement, toHaveLabelWith part: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label CONTAINS %@", part)
        wait(for: element, toMatch: predicate, "The label does not contain \"\(part)\"", file: file, line: line)
    }

    /// Waits until an element is not on the screen, and fails the test with the message when it stays.
    func waitToGo(_ element: XCUIElement, _ message: String, timeout: TimeInterval = 10) {
        XCTAssertTrue(element.waitForNonExistence(timeout: timeout), message)
    }

    /// Shows the swipe action of a row of a list: a short drag from the centre of the row, to the trailing side for
    /// the action at the leading side (`fromLeading`), or the opposite. The drag is not a full swipe, so the button
    /// of the action shows and the action does not run. The centre of the row must be on the screen: see `scrollTo`.
    func showSwipeAction(of row: XCUIElement, fromLeading: Bool) {
        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: fromLeading ? 130 : -130, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: 300, thenHoldForDuration: 0.3)
    }

    // MARK: - Text fields and questions

    /// Closes the keyboard with the "Done" button above it. A swipe from the centre of the screen then scrolls the
    /// screen: with the keyboard open, the centre of the screen can be the bar with the buttons of a form.
    func hideKeyboard() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else {
            return
        }
        // The return key of some keyboards is "Done" also. It has the identifier "Done", and the button above the
        // keyboard has no identifier.
        let done = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Done", "Done")).firstMatch
        if done.exists && done.isHittable {
            done.tap()
            _ = keyboard.waitForNonExistence(timeout: 5)
        }
    }

    /// Replaces the text of a field that has one line.
    func replaceText(of field: XCUIElement, with text: String) {
        // The keyboard or the buttons of a form can be above the field. A tap there does not get to the field.
        scrollTo(field, "The field is not on the screen")
        // A tap one point from the trailing edge puts the cursor after the text, also in a field with its text at
        // that end. A tap that is more to the centre can be on the last character, and the cursor then goes before it.
        let end = field.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -1, dy: 0))
        // The value of an empty field is its placeholder, so the number of characters is not always known. More
        // deletes than characters do no harm.
        let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: max((field.value as? String ?? "").count, 1))
        // The tap that gives the field the keyboard can put the cursor before the text, when a different field had
        // the keyboard. The second tap is in a field with the keyboard, and the cursor then goes to the tap.
        for _ in 0..<2 {
            end.tap()
            field.typeText(deletes)
        }
        field.typeText(text)
    }

    /// Closes a question of the system with no answer: a tap out of it. The system shows no "Keep editing" button
    /// on an iPhone. The question is near the control that opened it, and its size changes with the text size, so the
    /// tap is at the edge of the screen that is farther from the question.
    ///
    /// - Parameter part: A button or a text of the question.
    func closeQuestion(with part: XCUIElement) {
        let inTopHalf = part.frame.midY < app.frame.midY
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: inTopHalf ? 0.97 : 0.08)).tap()
    }

    /// Selects an option in the menu of a field of a form, for example
    /// `select("area_option_freezer", in: "field_area")`.
    func select(_ option: String, in field: String) {
        hideKeyboard()
        scrollTo(element(field), "The form has no \(field)").tap()
        tapMenuItem(app.buttons[option], "The menu of \(field) has no \(option)")
    }

    /// Selects an item of an open menu of the system. With large text, a long menu shows only its first items, and
    /// it scrolls.
    func tapMenuItem(_ item: XCUIElement, _ message: String) {
        let window = app.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        var drags = 0
        // The menu is open when one of its items is there. A first item that is not this one shows that also.
        _ = item.waitForExistence(timeout: 3)
        while drags < 10 && !(item.exists && item.isHittable) {
            // The drag starts on the menu: the menu is around the centre of the screen when it is long.
            origin.withOffset(CGVector(dx: window.midX, dy: window.height * 0.6)).press(
                forDuration: 0.05,
                thenDragTo: origin.withOffset(CGVector(dx: window.midX, dy: window.height * 0.4)),
                withVelocity: 400,
                thenHoldForDuration: 0.2
            )
            drags += 1
        }
        XCTAssertTrue(item.exists && item.isHittable, message)
        item.tap()
    }

    // MARK: - The ways between the screens

    /// A tab of the row of the storage areas of My Fridge, by its name: "All", "Fridge", "Freezer", or the name of
    /// another storage area.
    func areaTab(_ name: String) -> XCUIElement {
        app.scrollViews["area_tabs"].buttons[name].firstMatch
    }

    /// Selects a tab of the row of the storage areas of My Fridge. With large text, the tab can be out of the screen,
    /// and the row scrolls sideways.
    func selectArea(_ name: String) {
        let tab = expect(areaTab(name), "My Fridge has no tab for \(name)")
        let row = app.scrollViews["area_tabs"]
        let window = app.frame
        var drags = 0
        // The centre of the tab must be on the screen for the tap. A tab out of the screen has a frame, but XCTest
        // cannot tell if a tap gets to it.
        while drags < 12 && !(window.minX + 24...window.maxX - 24).contains(tab.frame.midX) {
            let step = max(-window.width * 0.5, min(window.width * 0.5, tab.frame.midX - window.midX))
            let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -step, dy: 0)), withVelocity: 400, thenHoldForDuration: 0.2)
            drags += 1
        }
        tab.tap()
        wait(for: tab, toBeSelected: true)
    }

    /// Opens the My Fridge tab, and selects the tab of a storage area when the test gives its name. My Fridge starts
    /// on the Fridge.
    func openMyFridge(area: String? = nil) {
        expect(tab("My Fridge"), "The tab bar has no My Fridge").tap()
        expect(app.navigationBars["My Fridge"], "My Fridge did not open")
        if let area {
            selectArea(area)
        }
    }

    /// The card of a food on My Fridge. A food has one card for each storage area: with no `area`, the result is its
    /// first card on the screen.
    ///
    /// - Parameter area: The identifier of the storage area, for example "fridge", "freezer", or "sample-pantry".
    func card(_ productId: String, area: String? = nil) -> XCUIElement {
        if let area {
            return app.buttons["food_\(productId)/\(area)"]
        }
        return app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "food_\(productId)/")).firstMatch
    }

    /// The card of a food on My Fridge, by the name of the food. It is for a food that the test added: the app makes
    /// the identifier of a new food.
    func card(named name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "food_", name)).firstMatch
    }

    /// Opens the screen of a food from the tab of My Fridge that shows. The result is the name on the screen.
    @discardableResult
    func openFood(_ productId: String) -> XCUIElement {
        if !app.navigationBars["My Fridge"].exists {
            openMyFridge()
        }
        scrollTo(card(productId), "My Fridge does not show the food \(productId)").tap()
        return expect(app.staticTexts["food_name"], "The screen of the food did not open")
    }

    /// Waits for the add form, and scrolls to its name field. The result is the name field. After a scan, the note
    /// of the lookup is above the name field, and with large text the field is then below the screen.
    @discardableResult
    func expectAddForm(_ message: String) -> XCUIElement {
        expect(app.navigationBars["Add food"], message)
        return scrollTo(app.textFields["field_name"], "The add form has no name field")
    }

    /// Opens the scanner from the menu of My Fridge.
    func openScanner() {
        if !app.buttons["my_fridge_menu"].exists {
            openMyFridge()
        }
        expect(app.buttons["my_fridge_menu"], "My Fridge has no menu").tap()
        expect(app.buttons["menu_scan"], "The menu has no scanner").tap()
        expect(app.buttons["type_barcode"], "The scanner did not open")
    }

    /// Types a barcode in the sheet of the scanner, and selects "Look up". The Simulator has no camera, so a typed
    /// barcode is the way into the lookup.
    func typeBarcode(_ barcode: String) {
        expect(app.buttons["type_barcode"], "The scanner has no \"Type the barcode\"").tap()
        let field = expect(app.textFields["field_barcode"], "The sheet for a typed barcode did not open")
        // The field has the keyboard when the sheet opens.
        field.typeText(barcode)
        app.buttons["barcode_look_up"].tap()
    }
}
