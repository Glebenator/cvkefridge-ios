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

    // MARK: - The photo of an add form

    @Test func anImportThatEndsAfterTheFormClosedDeletesItsFile() async throws {
        let fixture = try ModelFixture()
        defer { fixture.removeFolder() }
        let model = fixture.model

        model.makeFormPhoto(token: "form", picture: .data(Data()))
        #expect(model.formPhotos["form"] == .making)
        #expect(await eventually { await fixture.photos.waitingPrepares == 1 })

        model.discardFormPhoto(token: "form")
        let late = try #require(await fixture.photos.finishPrepare())

        #expect(await eventually { await fixture.photos.discarded == [late] })
        #expect(model.formPhotos["form"] == nil)
        #expect(model.formPhoto("form") == nil)
        #expect(model.notice == nil)
    }

    @Test func onlyTheNewestImportOfAFormGivesItsPhoto() async throws {
        let fixture = try ModelFixture()
        defer { fixture.removeFolder() }
        let model = fixture.model

        model.makeFormPhoto(token: "form", picture: .data(Data()))
        #expect(await eventually { await fixture.photos.waitingPrepares == 1 })
        model.makeFormPhoto(token: "form", picture: .data(Data()))
        #expect(await eventually { await fixture.photos.waitingPrepares == 2 })

        // The older import ends first. The form does not show it.
        let older = try #require(await fixture.photos.finishPrepare())
        #expect(await eventually { await fixture.photos.discarded == [older] })
        #expect(model.formPhotos["form"] == .making)

        let newer = try #require(await fixture.photos.finishPrepare())
        #expect(await eventually { model.formPhoto("form") == newer })
        #expect(await fixture.photos.discarded == [older])
    }

    @Test func aNewPhotoReplacesTheEarlierPhotoOfTheForm() async throws {
        let fixture = try ModelFixture()
        defer { fixture.removeFolder() }
        let model = fixture.model

        model.makeFormPhoto(token: "form", picture: .data(Data()))
        #expect(await eventually { await fixture.photos.waitingPrepares == 1 })
        let first = try #require(await fixture.photos.finishPrepare())
        #expect(await eventually { model.formPhoto("form") == first })

        model.makeFormPhoto(token: "form", picture: .data(Data()))
        #expect(await eventually { await fixture.photos.waitingPrepares == 1 })
        // The form closes while the second import runs. The two files go.
        model.discardFormPhoto(token: "form")
        let second = try #require(await fixture.photos.finishPrepare())

        #expect(await eventually { await Set(fixture.photos.discarded) == [first, second] })
        #expect(model.formPhotos["form"] == nil)
    }
}
