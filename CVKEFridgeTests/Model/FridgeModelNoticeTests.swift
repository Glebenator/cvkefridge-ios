import CVKEFridgeFeatures
import Foundation
import Testing
@testable import CVKEFridge

/// Two corrections of Android defects in the model (plan, section 7): the photo of a deleted product stays while its
/// "Undo" is on the screen (item 20), and one form token saves one time (item 21). The fixture clock stays at 12:00
/// of 1 May 2026.
@MainActor
struct FridgeModelNoticeTests {
    private static func date(_ text: String) -> CalendarDate {
        CalendarDate.parse(text)!
    }

    private static func change(_ number: Int, _ body: ChangeBody) -> Change {
        Change(id: "c\(number)", at: number, origin: "other", body: body)
    }

    private static func product(_ id: String, _ name: String) -> ChangeBody {
        .productSaved(product: Product(id: id, name: name, category: .other, unit: .g, barcode: nil, foodId: nil))
    }

    private static func batch(_ id: String, _ productId: String, expires: String) -> ChangeBody {
        .batchAdded(batch: Batch(
            id: id,
            productId: productId,
            quantity: 100_000,
            storageAreaId: "fridge",
            dateAdded: date("2026-04-01"),
            expiry: ExpiryDate(date: date(expires), source: .printed)
        ))
    }

    /// Rice and tea, with one batch each.
    private static let foods: [Change] = [
        change(1, product("rice", "Rice")),
        change(2, batch("a", "rice", expires: "2026-06-01")),
        change(3, product("tea", "Tea")),
        change(4, batch("b", "tea", expires: "2026-07-01")),
    ]

    private func started() async throws -> ModelFixture {
        let fixture = try ModelFixture(changes: Self.foods)
        fixture.model.start()
        #expect(await eventually { fixture.model.content != nil })
        #expect(await eventually { await !fixture.photos.cleanCalls.isEmpty })
        return fixture
    }

    // MARK: - Item 20: the photo of a deleted product

    @Test func theCleanupOfAnEarlierMessageKeepsThePhotoThatANewerUndoNeeds() async throws {
        let fixture = try await started()
        defer { fixture.removeFolder() }
        let model = fixture.model

        // The delete of tea, then the delete of rice. The message of the second delete replaces the first message.
        // The close of the first message cleans the photos: the photo of tea goes, because its "Undo" is gone.
        model.perform(.deleteProduct(productId: "tea"))
        #expect(await eventually { model.notice?.text == .message(.foodDeleted(name: "Tea")) })
        let calls = await fixture.photos.cleanCalls.count
        model.perform(.deleteProduct(productId: "rice"))
        #expect(await eventually { model.notice?.text == .message(.foodDeleted(name: "Rice")) })
        #expect(await eventually { await fixture.photos.cleanCalls.count > calls })
        #expect(model.content?.inventory.products.isEmpty == true)
        // Rice is not in the inventory, but its photo stays for the "Undo" on the screen.
        #expect(await fixture.photos.cleanCalls.last == ["rice"])

        // "Undo" brings rice back, with its photo. Tea stays deleted.
        let delete = try #require(model.notice)
        model.noticeAction(delete)
        model.noticeShown(delete.id)
        #expect(await eventually { model.content?.inventory.products.map(\.id) == ["rice"] })
        #expect(await eventually { await fixture.photos.cleanCalls.count > calls + 1 })
        #expect(await fixture.photos.cleanCalls.last == ["rice"])
    }

    @Test func thePhotoOfADeletedProductGoesWhenItsMessageCloses() async throws {
        let fixture = try await started()
        defer { fixture.removeFolder() }
        let model = fixture.model

        model.perform(.deleteProduct(productId: "rice"))
        #expect(await eventually { model.notice?.text == .message(.foodDeleted(name: "Rice")) })
        let delete = try #require(model.notice)
        model.noticeShown(delete.id)
        #expect(await eventually { await fixture.photos.cleanCalls.last == ["tea"] })
    }

    // MARK: - Item 21: one token saves one time

    private static let milk = InventoryAction.addFood(InventoryAction.AddFood(
        productId: nil,
        name: "Milk",
        category: .dairy,
        unit: .l,
        foodId: nil,
        quantity: 1_000,
        storageAreaId: "fridge",
        expiry: nil
    ))

    @Test func oneTokenSavesOneTime() async throws {
        let fixture = try await started()
        defer { fixture.removeFolder() }
        let model = fixture.model

        // Two fast taps on "Save": the second does nothing.
        #expect(model.perform(Self.milk, formToken: "form"))
        #expect(!model.perform(Self.milk, formToken: "form"))
        #expect(await eventually { model.formWrite("form") == .saved })
        // Until the form read its result, the token does not save again.
        #expect(!model.perform(Self.milk, formToken: "form"))
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.content?.inventory.products.filter { $0.name == "Milk" }.count == 1)

        // "Save and add another" reads the result, and the token saves the next food.
        model.formWriteRead("form")
        #expect(model.formWrite("form") == nil)
        #expect(model.perform(Self.milk, formToken: "form"))
        #expect(await eventually { model.formWrite("form") == .saved })
        #expect(model.content?.inventory.batches.filter { $0.productId != "rice" && $0.productId != "tea" }.count == 2)
    }

    @Test func eachFormGetsTheResultOfItsOwnSave() async throws {
        let fixture = try await started()
        defer { fixture.removeFolder() }
        let model = fixture.model

        var refused = Self.milk
        if case .addFood(var add) = refused {
            add.storageAreaId = "no-area"
            refused = .addFood(add)
        }
        model.perform(refused, formToken: "first")
        model.perform(Self.milk, formToken: "second")
        #expect(await eventually { model.formWrite("second") == .saved })
        #expect(model.formWrite("first") == .failed(.unknownStorageArea))

        // A failed save can save again with its token.
        #expect(model.perform(Self.milk, formToken: "first"))
        #expect(await eventually { model.formWrite("first") == .saved })
        #expect(model.formWrite("second") == .saved)
    }
}
