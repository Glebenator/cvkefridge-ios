import CVKEFridgeFeatures
import Foundation
import Testing
@testable import CVKEFridge

/// The photo files that the model keeps and deletes: the cleanup after a load, and the photo of an add form.
@MainActor
struct FridgeModelPhotoTests {
    // MARK: - The cleanup after a load

    @Test func aLogWithLinesThatTheAppDidNotReadDeletesNoPhoto() async throws {
        // A line that a later version of the app can read. It can have a product with a photo.
        let fixture = try ModelFixture(changeLogText: "{\"not\":\"a change\"}\n")
        defer { fixture.removeFolder() }
        fixture.model.start()

        // The message about the lines comes after the cleanup.
        let announced = await eventually {
            if case .changesNotRead(count: 1) = fixture.model.notice?.text { true } else { false }
        }
        #expect(announced)
        #expect(await fixture.photos.cleanCalls.isEmpty)
    }

    @Test func aLogThatTheAppReadCompletelyCleansThePhotos() async throws {
        let fixture = try ModelFixture()
        defer { fixture.removeFolder() }
        fixture.model.start()

        let cleaned = await eventually { await !fixture.photos.cleanCalls.isEmpty }
        #expect(cleaned)
        #expect(await fixture.photos.cleanCalls.first == [])
    }
}
