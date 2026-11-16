import CVKEFridgeFeatures
import Foundation
import Testing
@testable import CVKEFridge

/// Actions that wait in the queue of the model: the inventory can change before they run. The fixture clock stays at
/// 12:00 of 1 May 2026.
@MainActor
struct FridgeModelActionTests {
    private static func date(_ text: String) -> CalendarDate {
        CalendarDate.parse(text)!
    }

    private static func change(_ number: Int, _ body: ChangeBody) -> Change {
        Change(id: "c\(number)", at: number, origin: "other", body: body)
    }

    private static func batch(_ id: String, _ quantity: Int, added: String, expires: String) -> ChangeBody {
        .batchAdded(batch: Batch(
            id: id,
            productId: "rice",
            quantity: quantity,
            storageAreaId: "fridge",
            dateAdded: date(added),
            expiry: ExpiryDate(date: date(expires), source: .printed)
        ))
    }

    /// Rice with two batches: A (300 g, the batch to use first) and B (500 g).
    private static let rice: [Change] = [
        change(1, .productSaved(product: Product(id: "rice", name: "Rice", category: .other, unit: .g, barcode: nil, foodId: nil))),
        change(2, batch("a", 300_000, added: "2026-04-01", expires: "2026-04-28")),
        change(3, batch("b", 500_000, added: "2026-04-02", expires: "2026-06-01")),
    ]

    private func started(_ changes: [Change]) async throws -> ModelFixture {
        let fixture = try ModelFixture(changes: changes)
        fixture.model.start()
        #expect(await eventually { fixture.model.content != nil })
        return fixture
    }

    private func quantity(_ batchId: String, _ model: FridgeModel) -> Int? {
        model.content?.inventory.batches.first(where: { $0.id == batchId })?.quantity
    }

    private func expiry(_ batchId: String, _ model: FridgeModel) -> ExpiryDate? {
        model.content?.inventory.batches.first(where: { $0.id == batchId })?.expiry
    }

    // MARK: - The swipe on a food card

    @Test func twoSwipesThatWaitInTheQueueEndOnlyTheBatchThatTheCardShowed() async throws {
        let fixture = try await started(Self.rice)
        defer { fixture.removeFolder() }
        let model = fixture.model

        // The card shows batch A as the batch to use first. Two swipes come before the card shows the change.
        model.takeWholeBatch(productId: "rice", batchId: "a", outcome: .used)
        model.takeWholeBatch(productId: "rice", batchId: "a", outcome: .used)
        // A later action shows that the queue ran the two swipes.
        model.perform(.moveExpiry(batchId: "b", date: Self.date("2026-06-05")))

        #expect(await eventually { expiry("b", model)?.date == Self.date("2026-06-05") })
        #expect(quantity("a", model) == 0)
        #expect(quantity("b", model) == 500_000)
        #expect(model.content?.inventory.history.count == 1)
        #expect(model.content?.inventory.history.first?.quantity == 300_000)
    }

    @Test func aSwipeTakesTheQuantityThatTheBatchHasWhenItRuns() async throws {
        // A used 100 g of A after the card showed 300 g. The swipe ends A with its 200 g, and B stays.
        let fixture = try await started(Self.rice + [Self.change(4, .batchUsed(batchId: "a", quantity: 100_000, date: Self.date("2026-04-30")))])
        defer { fixture.removeFolder() }
        let model = fixture.model

        model.takeWholeBatch(productId: "rice", batchId: "a", outcome: .thrownAway)

        #expect(await eventually { quantity("a", model) == 0 })
        #expect(quantity("b", model) == 500_000)
        #expect(model.content?.inventory.history.last?.quantity == 200_000)
        #expect(model.content?.inventory.history.last?.outcome == .thrownAway)
    }

    // MARK: - "Other date" of "Still good?"

    @Test func aLaterDateThatIsNotAfterTodayChangesNothing() async throws {
        // A expired on 28 April. The calendar opened on 30 April, so its first date was 1 May. After midnight, today
        // is 1 May, and 1 May is not a later date.
        let fixture = try await started(Self.rice)
        defer { fixture.removeFolder() }
        let model = fixture.model

        model.perform(.moveExpiry(batchId: "a", date: Self.date("2026-05-01")))
        // A later action shows that the queue ran the first action.
        model.perform(.moveExpiry(batchId: "b", date: Self.date("2026-06-05")))
        #expect(await eventually { expiry("b", model)?.date == Self.date("2026-06-05") })
        #expect(expiry("a", model) == ExpiryDate(date: Self.date("2026-04-28"), source: .printed))
        #expect(model.content?.changes.count == Self.rice.count + 1)
    }

    @Test func aLaterDateMustBeAfterTheExpiryDateAndAfterToday() async throws {
        let fixture = try await started(Self.rice)
        defer { fixture.removeFolder() }
        let model = fixture.model

        // B expires on 1 June: 31 May and 1 June are not later.
        model.perform(.moveExpiry(batchId: "b", date: Self.date("2026-06-01")))
        // 2 May is after today and after the expiry date of A.
        model.perform(.moveExpiry(batchId: "a", date: Self.date("2026-05-02")))
        #expect(await eventually { expiry("a", model)?.date == Self.date("2026-05-02") })
        #expect(expiry("a", model)?.source == .chosen)
        #expect(expiry("b", model) == ExpiryDate(date: Self.date("2026-06-01"), source: .printed))

        model.perform(.moveExpiry(batchId: "b", date: Self.date("2026-06-02")))
        #expect(await eventually { expiry("b", model)?.date == Self.date("2026-06-02") })
    }
}
