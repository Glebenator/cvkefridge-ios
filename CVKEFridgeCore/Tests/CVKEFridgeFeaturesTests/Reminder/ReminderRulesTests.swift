import CVKEFridgeFeatures
import Testing

/// Which batches go into the reminder of a date (see `ReminderRules`). The Android test `ReminderRulesTest` has the
/// same cases.
struct ReminderRulesTests {
    private typealias I = ReminderInventory
    private let today = I.date("2026-11-12")

    private func foods(_ inventory: Inventory, leadDays: Int = ReminderRules.defaultLeadDays) -> [ReminderFood] {
        ReminderRules.foods(inventory, today: today, leadDays: leadDays)
    }

    @Test func theDefaultLeadTimeIsTheExpiringRuleOfTheCore() {
        #expect(ReminderRules.defaultLeadDays == Freshness.expiringWithinDays)
        #expect(ReminderRules.leadDayChoices == 0...Freshness.expiringWithinDays)
    }

    @Test func aBatchIsInTheReminderFromTheDayAfterItsExpiryDateToTheLeadTime() {
        let dates = ["2026-11-09", "2026-11-10", "2026-11-11", "2026-11-12", "2026-11-13", "2026-11-14", "2026-11-15"]
        let all = I.inventory(dates.map { I.product("p\($0)") } + dates.map { I.batch("b\($0)", "p\($0)", expires: $0) })
        // Expired yesterday (-1), today (0), tomorrow (1), and in 2 days. Not 2 or 3 days ago, not in 3 days.
        #expect(foods(all).map(\.daysLeft) == [-1, 0, 1, 2])
        #expect(foods(all).map(\.productId) == ["p2026-11-11", "p2026-11-12", "p2026-11-13", "p2026-11-14"])
        // A shorter lead time stops earlier. The batch that expired yesterday stays.
        #expect(foods(all, leadDays: 1).map(\.daysLeft) == [-1, 0, 1])
        #expect(foods(all, leadDays: 0).map(\.daysLeft) == [-1, 0])
    }

    @Test func anExpiredBatchIsOnlyInTheReminderOfTheFirstDayAfterItsExpiryDate() {
        let milk = I.inventory(I.product("milk"), I.batch("b1", "milk", expires: "2026-11-11"))
        #expect(ReminderRules.foods(milk, today: I.date("2026-11-12"), leadDays: 2).map(\.daysLeft) == [-1])
        #expect(ReminderRules.foods(milk, today: I.date("2026-11-13"), leadDays: 2).isEmpty)
        #expect(ReminderRules.foods(milk, today: I.date("2026-12-01"), leadDays: 2).isEmpty)
    }

    @Test func aBatchWithNoExpiryDateOrNoQuantityIsNotInTheReminder() {
        let inventory = I.inventory(
            I.product("rice"),
            I.product("milk"),
            I.batch("b1", "rice", expires: nil),
            I.batch("b2", "milk", expires: "2026-11-12"),
            .batchUsed(batchId: "b2", quantity: 1000, date: today)
        )
        #expect(foods(inventory).isEmpty)
    }

    @Test func aProductWithSeveralBatchesIsOneFoodWithItsFirstBatch() {
        let inventory = I.inventory(
            I.product("milk", "Whole milk"),
            I.batch("b1", "milk", expires: "2026-11-14"),
            I.batch("b2", "milk", expires: "2026-11-12", source: .estimated),
            I.batch("b3", "milk", expires: "2026-11-11", area: "freezer"),
            I.batch("b4", "milk", expires: "2026-11-30")
        )
        #expect(foods(inventory) == [ReminderFood(productId: "milk", name: "Whole milk", daysLeft: -1, estimated: false)])
        // After the expired batch is used, the batch that expires today is first. Its date is an estimate.
        let used = I.inventory(
            I.product("milk", "Whole milk"),
            I.batch("b1", "milk", expires: "2026-11-14"),
            I.batch("b2", "milk", expires: "2026-11-12", source: .estimated)
        )
        #expect(foods(used) == [ReminderFood(productId: "milk", name: "Whole milk", daysLeft: 0, estimated: true)])
    }

    @Test func theFoodsAreInTheOrderOfTheirDaysLeftAndThenOfTheirNames() {
        let inventory = I.inventory(
            I.product("a", "yoghurt"),
            I.product("b", "Apples"),
            I.product("c", "bread"),
            I.product("d", "Cheese"),
            I.batch("b1", "a", expires: "2026-11-13"),
            I.batch("b2", "b", expires: "2026-11-13"),
            I.batch("b3", "c", expires: "2026-11-12"),
            I.batch("b4", "d", expires: "2026-11-11")
        )
        #expect(foods(inventory).map(\.name) == ["Cheese", "bread", "Apples", "yoghurt"])
    }

    @Test func aLeadTimeOutOfRangeUsesTheNearestChoice() {
        let inventory = I.inventory(I.product("milk"), I.batch("b1", "milk", expires: "2026-11-15"))
        #expect(foods(inventory, leadDays: 10).isEmpty)
        #expect(foods(inventory, leadDays: -3).isEmpty)
    }
}
