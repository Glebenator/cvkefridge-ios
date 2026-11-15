import Testing
@testable import CVKEFridgeFeatures

/// The changes that the phone adds to the change log. The same cases as the Android NewChangesTest.
struct NewChangesTests {
    private let today = CalendarDate.parse("2026-11-12")!
    private let product = ChangeBody.productSaved(
        product: Product(id: "p1", name: "Rice", category: .other, unit: nil, barcode: nil, foodId: nil)
    )
    private var batch: ChangeBody {
        .batchAdded(
            batch: Batch(id: "b1", productId: "p1", quantity: 1_000, storageAreaId: "fridge", dateAdded: today, expiry: nil)
        )
    }

    /// Identifiers where the second is smaller than the first, as a random identifier can be.
    private func ids() -> () -> String {
        var count = 0
        return {
            defer { count += 1 }
            return "id-\(9 - count)"
        }
    }

    @Test func theChangesOfOneActionStayInTheirOrderInTheReplay() {
        let changes = NewChanges.stamp([product, batch], log: [], now: 500, origin: "phone", newId: ids())
        #expect(changes.map(\.at) == [500, 501])
        #expect(changes.map(\.origin) == ["phone", "phone"])
        #expect(changes.map(\.id) == ["id-9", "id-8"])
        let inventory = Inventory.replay(changes)
        #expect(inventory.rejected.isEmpty)
        #expect(inventory.batches.map(\.id) == ["b1"])
    }

    @Test func aChangeIsAfterTheLogWhenTheClockWentBack() {
        let log = [Change(id: "c1", at: 900, origin: "phone", body: product)]
        let changes = NewChanges.stamp([batch], log: log, now: 100, origin: "phone", newId: ids())
        #expect(changes.map(\.at) == [901])
        #expect(Inventory.replay(log + changes).rejected.isEmpty)
    }

    @Test func theReasonIsThatOfTheNewChangeThatTheReplayRejects() {
        let log = [
            Change(id: "c1", at: 1, origin: "phone", body: product),
            Change(id: "c0", at: 2, origin: "phone", body: .batchDeleted(batchId: "gone")),
        ]
        let before = Inventory.replay(log)
        let good = NewChanges.stamp([batch], log: log, now: 10, origin: "phone", newId: ids())
        #expect(NewChanges.rejection(previous: before, next: Inventory.replay(log + good)) == nil)

        let bad = NewChanges.stamp(
            [.batchUsed(batchId: "b1", quantity: 1_000, date: today)],
            log: log,
            now: 10,
            origin: "phone",
            newId: ids()
        )
        #expect(NewChanges.rejection(previous: before, next: Inventory.replay(log + bad)) == .unknownBatch)
    }
}
