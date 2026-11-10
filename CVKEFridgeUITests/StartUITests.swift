import XCTest

/// The start screen on a simulator. The capture is an attachment, so CI can show the real screen.
@MainActor
final class StartUITests: XCTestCase {
    // XCUITest objects belong to the main actor, so they are made at first use.
    private lazy var app = XCUIApplication()

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test1StartScreen() throws {
        continueAfterFailure = false
        app.launch()
        XCTAssertTrue(app.staticTexts["start_title"].waitForExistence(timeout: 10), "Missing the title")
        XCTAssertEqual(app.staticTexts["start_version"].label, "Version 0.1.0 (1)")
        capture("start")
    }
}
