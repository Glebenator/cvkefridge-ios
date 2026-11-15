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

    /// Scrolls the screen up until the element is on it, and fails the test with the message when it does not come.
    /// A list makes its rows when they come on the screen, so a row can be missing with large text.
    @discardableResult
    func scrollTo(_ element: XCUIElement, _ message: String) -> XCUIElement {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < 10 {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
        XCTAssertTrue(element.exists && element.isHittable, message)
        return element
    }

    /// Waits for an element, and fails the test with the message when it does not come.
    @discardableResult
    func expect(_ element: XCUIElement, _ message: String, timeout: TimeInterval = 10) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message)
        return element
    }
}
