import XCTest

/// The photo of a food on a simulator, with the sample inventory: a new photo, the photo after a restart, "Change
/// photo" and "Remove photo" with "Undo", a picture that cannot be read, and the dialogs of the camera access.
///
/// The pictures come from the built-in pictures of the debug build (`-uiTestPicture`), in the place of the photo
/// picker and the camera of the system. With them, the debug build shows the thumbnail to the tests: its value is the
/// name of the photo file on the screen, or "icon". The Simulator has no camera, so `-uiTestCamera` gives "Take a
/// photo" and a camera access.
final class PhotoUITests: FridgeUITestCase {
    private static let product = "sample-cheddar"
    private static let pictures = ["-uiTestPicture", "photo"]

    /// Opens the screen of the cheddar from My Fridge.
    private func openFood(checkingRowValue rowValue: String? = nil) {
        expect(app.staticTexts["hero_total"], "Home does not show the number of foods")
        tab("My Fridge").tap()
        let row = scrollTo(app.buttons["food_\(Self.product)"], "My Fridge does not show the food")
        if let rowValue {
            // The card of My Fridge shows the photo too.
            waitForValue(image(in: app), rowValue, "The card of My Fridge does not show the photo")
        }
        row.tap()
        expect(app.staticTexts["food_name"], "The food did not open")
    }

    /// The thumbnail of the cheddar in the `container`.
    private func image(in container: XCUIElement) -> XCUIElement {
        container.descendants(matching: .any).matching(identifier: "product_image_\(Self.product)").firstMatch
    }

    /// The thumbnail of the cheddar on the screen of the food.
    private var foodImage: XCUIElement {
        image(in: app.descendants(matching: .any).matching(identifier: "food_screen").firstMatch)
    }

    /// Waits until the value of the thumbnail is `value`, and gives the value.
    @discardableResult
    private func waitForValue(_ element: XCUIElement, _ value: String, _ message: String) -> String {
        let predicate = NSPredicate(format: "value == %@", value)
        let result = XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 10)
        XCTAssertEqual(result, .completed, "\(message): \(element.value as? String ?? "no value")")
        return value
    }

    /// Waits until the thumbnail shows a photo of the cheddar that is not `other`, and gives the name of its file.
    private func waitForPhoto(other: String? = nil, _ message: String) -> String {
        let element = foodImage
        var format = "value BEGINSWITH %@"
        var arguments: [Any] = [Self.product + "."]
        if let other {
            format += " AND value != %@"
            arguments.append(other)
        }
        let predicate = NSPredicate(format: format, argumentArray: arguments)
        let result = XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 10)
        XCTAssertEqual(result, .completed, "\(message): \(element.value as? String ?? "no value")")
        return element.value as? String ?? ""
    }

    func test1APhotoStaysAfterARestartAndChangeAndRemoveHaveUndo() throws {
        launch(inventory: .sample, arguments: Self.pictures)
        openFood()

        // A food with no photo shows its icon. The Simulator has no camera, so only "Choose a photo" is there.
        waitForValue(foodImage, "icon", "The food has a photo at the start")
        XCTAssertFalse(app.buttons["photo_take"].exists, "A device with no camera offers Take a photo")
        app.buttons["photo_choose"].tap()
        expect(app.buttons["photo_change"], "The food did not get the photo")
        XCTAssertTrue(app.buttons["photo_remove"].exists, "A food with a photo has no Remove photo")
        let first = waitForPhoto("The photo does not show")
        capture("photo-food-new")

        // After a restart, the app finds the photo in its folder, and the cards show it.
        app.terminate()
        launch(inventory: .sample, keepsStore: true, arguments: Self.pictures)
        openFood(checkingRowValue: first)
        waitForValue(foodImage, first, "The photo is not there after a restart")

        // "Change photo" makes a new photo, and its "Undo" brings the earlier photo back.
        app.buttons["photo_change"].tap()
        expect(app.staticTexts["Photo changed"], "The change has no message")
        let second = waitForPhoto(other: first, "The new photo does not show")
        capture("photo-food-changed")
        expect(app.buttons["Undo"], "The message of the change has no Undo").tap()
        waitForValue(foodImage, first, "Undo did not bring the earlier photo back")
        XCTAssertNotEqual(first, second)

        // "Remove photo" shows the icon again, and its "Undo" brings the photo back.
        app.buttons["photo_remove"].tap()
        expect(app.staticTexts["Photo removed"], "The remove has no message")
        expect(app.buttons["photo_choose"], "The food still has a photo")
        waitForValue(foodImage, "icon", "The icon does not show after the remove")
        capture("photo-food-removed")
        expect(app.buttons["Undo"], "The message of the remove has no Undo").tap()
        expect(app.buttons["photo_change"], "Undo did not bring the photo back")
        waitForValue(foodImage, first, "Undo did not bring the same photo back")
    }

    func test2APictureThatCannotBeReadKeepsThePhotoOfTheFood() throws {
        launch(inventory: .sample, arguments: ["-uiTestPicture", "unreadable"])
        openFood()
        app.buttons["photo_choose"].tap()
        expect(
            app.staticTexts["Couldn't add the photo. Select a different picture."],
            "A picture that cannot be read gave no message"
        )
        XCTAssertTrue(app.buttons["photo_choose"].exists, "The food got a photo from a picture that cannot be read")
        waitForValue(foodImage, "icon", "The food shows a photo")
    }

    func test3TheCameraIsExplainedBeforeIOSAsksAndAnAccessThatIsOffOpensSettings() throws {
        launch(inventory: .sample, arguments: Self.pictures + ["-uiTestCamera", "ask"])
        openFood()

        // The app explains the camera before iOS asks. "Continue" asks, and then the camera takes the picture.
        expect(app.buttons["photo_take"], "The device has a camera, but Take a photo is not there").tap()
        let explain = expect(app.alerts["Take a photo with the camera"], "The camera was not explained before iOS asks")
        XCTAssertTrue(explain.buttons["Not now"].exists, "The explanation cannot be closed")
        capture("photo-camera-explain")
        explain.buttons["Continue"].tap()
        expect(app.buttons["photo_change"], "The food did not get the photo of the camera")
        let first = waitForPhoto("The photo of the camera does not show")

        // "Change photo" has the two sources.
        app.buttons["photo_change"].tap()
        expect(app.buttons["Choose a photo"], "Change photo has no Choose a photo")
        XCTAssertTrue(app.buttons["Take a photo"].exists, "Change photo has no Take a photo")
        capture("photo-change-menu")
        app.buttons["Choose a photo"].tap()
        _ = waitForPhoto(other: first, "The chosen photo does not show")

        // With the camera access off, the app says so and offers the Settings app. The person can still choose.
        app.terminate()
        launch(inventory: .sample, arguments: Self.pictures + ["-uiTestCamera", "blocked"])
        openFood()
        app.buttons["photo_take"].tap()
        let blocked = expect(app.alerts["Camera access is off"], "The app did not say that the camera access is off")
        XCTAssertTrue(blocked.buttons["Open Settings"].exists, "The dialog does not open the Settings app")
        capture("photo-camera-blocked")
        blocked.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["photo_choose"].waitForExistence(timeout: 5), "Choose a photo is not there")
    }
}
