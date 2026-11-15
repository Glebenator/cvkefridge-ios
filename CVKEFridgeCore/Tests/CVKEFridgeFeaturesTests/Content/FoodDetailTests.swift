import Testing
@testable import CVKEFridgeFeatures

/// What the screen of a food shows. Android has no test file for it: its device tests show the screen.
struct FoodDetailTests {
    private static func date(_ text: String) -> CalendarDate {
        CalendarDate.parse(text)!
    }

    private let inventory = Inventory.replay(
        [
            ChangeBody.storageAreaSaved(id: "cellar", name: "Cellar", kind: .pantry),
            .productSaved(product: Product(id: "milk", name: "Milk", category: .dairy, unit: .l, barcode: nil, foodId: nil)),
            .batchAdded(
                batch: Batch(
                    id: "b1",
                    productId: "milk",
                    quantity: 2_000,
                    storageAreaId: "fridge",
                    dateAdded: date("2026-11-05"),
                    expiry: ExpiryDate(date: date("2026-11-20"), source: .printed)
                )
            ),
            .batchAdded(
                batch: Batch(
                    id: "b2",
                    productId: "milk",
                    quantity: 1_000,
                    storageAreaId: "cellar",
                    dateAdded: date("2026-11-01"),
                    expiry: ExpiryDate(date: date("2026-11-12"), source: .estimated)
                )
            ),
            .batchAdded(
                batch: Batch(
                    id: "b3",
                    productId: "milk",
                    quantity: 500,
                    storageAreaId: "fridge",
                    dateAdded: date("2026-11-01"),
                    expiry: nil
                )
            ),
            .batchUsed(batchId: "b3", quantity: 500, date: date("2026-11-02")),
        ].enumerated().map { index, body in Change(id: "c\(index)", at: index, origin: "test", body: body) }
    )

    @Test func theActiveBatchesAreInTheUseFirstOrder() throws {
        let detail = try #require(FoodDetail.of(inventory, productId: "milk", today: Self.date("2026-11-11")))
        #expect(detail.product.name == "Milk")
        #expect(detail.batches.map(\.id) == ["b2", "b1"])
        #expect(detail.batches.map(\.areaName) == ["Cellar", "Fridge"])
        #expect(detail.batches.map(\.daysLeft) == [1, 9])
        #expect(detail.batches.map(\.freshness) == [.expiring, .fresh])
        #expect(detail.total == 3_000)
    }

    @Test func aProductThatIsNotThereHasNoDetail() {
        #expect(FoodDetail.of(inventory, productId: "none", today: Self.date("2026-11-11")) == nil)
    }
}
