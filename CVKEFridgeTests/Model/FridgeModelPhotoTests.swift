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

    @Test func aFormThatClosesWhileANewPhotoReplacesTheEarlierPhotoLeavesNoPhoto() async throws {
        let fixture = try ModelFixture()
        defer { fixture.removeFolder() }
        let model = fixture.model

        model.makeFormPhoto(token: "form", picture: .data(Data()))
        #expect(await eventually { await fixture.photos.waitingPrepares == 1 })
        let first = try #require(await fixture.photos.finishPrepare())
        #expect(await eventually { model.formPhoto("form") == first })

        // The second import deletes the first photo, and that delete waits. The form closes in that time.
        await fixture.photos.holdDiscards()
        model.makeFormPhoto(token: "form", picture: .data(Data()))
        #expect(await eventually { await fixture.photos.waitingPrepares == 1 })
        let second = try #require(await fixture.photos.finishPrepare())
        #expect(await eventually { await fixture.photos.waitingDiscards == 1 })
        model.discardFormPhoto(token: "form")
        await fixture.photos.releaseDiscards()

        #expect(await eventually { await Set(fixture.photos.discarded) == [first, second] })
        #expect(model.formPhotos["form"] == nil)
    }

    // MARK: - A picture that loads before the app makes the photo

    @Test func theFormIsBusyWhileThePictureLoads() async throws {
        let fixture = try ModelFixture()
        defer { fixture.removeFolder() }
        let model = fixture.model

        let load = model.startFormPhoto(token: "form")
        // "Save" is off while the picture loads, for example from iCloud.
        #expect(model.formPhotos["form"] == .making)

        model.makeFormPhoto(token: "form", load: load, picture: .data(Data()))
        #expect(await eventually { await fixture.photos.waitingPrepares == 1 })
        #expect(model.formPhotos["form"] == .making)
        let photo = try #require(await fixture.photos.finishPrepare())
        #expect(await eventually { model.formPhoto("form") == photo })
    }

    @Test func aPictureThatLoadsAfterTheNextEntryStartedDoesNotGoToTheNextEntry() async throws {
        let fixture = try ModelFixture()
        defer { fixture.removeFolder() }
        let model = fixture.model

        let late = model.startFormPhoto(token: "form")
        // "Save and add another" starts the next entry with the same token. The form drops its photo.
        model.discardFormPhoto(token: "form")
        #expect(model.formPhotos["form"] == nil)

        // The picture of the earlier entry arrives. Nothing occurs.
        model.makeFormPhoto(token: "form", load: late, picture: .data(Data()))
        #expect(model.formPhotos["form"] == nil)

        // The next entry gets a picture of its own. The late picture of the earlier entry still does nothing.
        let next = model.startFormPhoto(token: "form")
        model.makeFormPhoto(token: "form", load: late, picture: .data(Data()))
        #expect(model.formPhotos["form"] == .making)
        model.makeFormPhoto(token: "form", load: next, picture: .data(Data()))
        #expect(await eventually { await fixture.photos.waitingPrepares == 1 })
        let photo = try #require(await fixture.photos.finishPrepare())
        #expect(await eventually { model.formPhoto("form") == photo })
        #expect(await fixture.photos.waitingPrepares == 0)
    }

    // MARK: - The photo of a save

    private let milk = InventoryAction.AddFood(
        productId: nil,
        name: "Milk",
        category: .dairy,
        unit: .l,
        foodId: nil,
        quantity: 1_000,
        storageAreaId: "fridge",
        expiry: nil
    )

    /// A started model with a form that has a ready photo.
    private func formWithPhoto(_ fixture: ModelFixture) async throws -> PreparedPhoto {
        let model = fixture.model
        model.start()
        #expect(await eventually { model.content != nil })
        model.makeFormPhoto(token: "form", picture: .data(Data()))
        #expect(await eventually { await fixture.photos.waitingPrepares == 1 })
        let photo = try #require(await fixture.photos.finishPrepare())
        #expect(await eventually { model.formPhoto("form") == photo })
        return photo
    }

    @Test func aFormThatClosesWhileItsSaveWaitsKeepsThePhotoOfTheSave() async throws {
        let fixture = try ModelFixture()
        defer { fixture.removeFolder() }
        let model = fixture.model
        let photo = try await formWithPhoto(fixture)

        model.perform(.addFood(milk), formToken: "form", photo: photo)
        // The person closes the form before the write ran.
        model.discardFormPhoto(token: "form")

        #expect(await eventually { model.formWrite("form") == .saved })
        let productId = try #require(model.content?.inventory.products.first?.id)
        #expect(await eventually { await fixture.photos.adopted[productId] == photo })
        #expect(model.photos[productId] != nil)
        #expect(await !fixture.photos.discarded.contains(photo))
    }

    @Test func aSaveThatFailsGivesThePhotoBackToTheFormOrDeletesItWhenTheFormClosed() async throws {
        let fixture = try ModelFixture()
        defer { fixture.removeFolder() }
        let model = fixture.model
        let photo = try await formWithPhoto(fixture)

        // A storage area that is not there: the core refuses the add. The form keeps its photo.
        var refused = milk
        refused.storageAreaId = "no-area"
        model.perform(.addFood(refused), formToken: "form", photo: photo)
        #expect(await eventually { model.formWrite("form") == .failed(.unknownStorageArea) })
        #expect(model.formPhoto("form") == photo)
        #expect(await !fixture.photos.discarded.contains(photo))

        // The same, but the form closes while the write waits: the photo goes.
        model.formWriteRead("form")
        model.perform(.addFood(refused), formToken: "form", photo: photo)
        model.discardFormPhoto(token: "form")
        #expect(await eventually { await fixture.photos.discarded == [photo] })
    }

    @Test func aPhotoThatTheSavedFoodCouldNotGetStaysVisibleWithTryAgain() async throws {
        let fixture = try ModelFixture()
        defer { fixture.removeFolder() }
        let model = fixture.model
        let photo = try await formWithPhoto(fixture)
        await fixture.photos.failAdopts(2)

        model.perform(.addFood(milk), formToken: "form", photo: photo)
        #expect(await eventually { model.formWrite("form") == .saved })
        let productId = try #require(model.content?.inventory.products.first?.id)

        // The food is added, and the message says that the photo is not. It is not replaced by "Milk added".
        #expect(await eventually { await fixture.photos.failedAdopts == 1 })
        var notice = try #require(model.notice)
        #expect(notice.text == .photoNotAdded(name: "Milk"))
        #expect(notice.action == .tryAgain)
        #expect(model.photos[productId] == nil)
        #expect(await !fixture.photos.discarded.contains(photo))

        // "Try again" fails one more time: a new message, and the prepared photo stays for it.
        model.noticeAction(notice)
        model.noticeShown(notice.id)
        #expect(await eventually { await fixture.photos.failedAdopts == 2 && model.notice != nil })
        notice = try #require(model.notice)
        #expect(notice.text == .photoNotAdded(name: "Milk"))
        #expect(await !fixture.photos.discarded.contains(photo))

        // The next "Try again" works.
        model.noticeAction(notice)
        model.noticeShown(notice.id)
        #expect(await eventually { await fixture.photos.adopted[productId] == photo })
        #expect(await eventually { model.photos[productId] != nil })
    }

    @Test func aPhotoThatTheSavedFoodCouldNotGetGoesWhenItsMessageCloses() async throws {
        let fixture = try ModelFixture()
        defer { fixture.removeFolder() }
        let model = fixture.model
        let photo = try await formWithPhoto(fixture)
        await fixture.photos.failAdopts(1)

        model.perform(.addFood(milk), formToken: "form", photo: photo)
        #expect(await eventually {
            if case .photoNotAdded = model.notice?.text { true } else { false }
        })
        let notice = try #require(model.notice)
        model.noticeShown(notice.id)
        #expect(await eventually { await fixture.photos.discarded == [photo] })
    }
}
