import Testing
@testable import CVKEFridgeFeatures

/// The list and the summary of the history for a given change log and date. The same cases as the Android
/// HistoryContentTest.
struct HistoryContentTests {
    private let today = CalendarDate.parse("2026-11-12")!

    private static func date(_ text: String) -> CalendarDate {
        CalendarDate.parse(text)!
    }

    private func date(_ text: String) -> CalendarDate {
        Self.date(text)
    }

    private static func product(
        _ id: String,
        _ name: String,
        _ unit: MeasureUnit?,
        _ category: CVKEFridgeCore.Category = .other
    ) -> ChangeBody {
        .productSaved(product: Product(id: id, name: name, category: category, unit: unit, barcode: nil, foodId: nil))
    }

    private static func batch(_ id: String, _ product: String, _ quantity: Int) -> ChangeBody {
        .batchAdded(
            batch: Batch(
                id: id,
                productId: product,
                quantity: quantity,
                storageAreaId: "fridge",
                dateAdded: date("2026-09-01"),
                expiry: nil
            )
        )
    }

    private static func used(_ batch: String, _ quantity: Int, _ on: String) -> ChangeBody {
        .batchUsed(batchId: batch, quantity: quantity, date: date(on))
    }

    private static func thrown(_ batch: String, _ quantity: Int, _ on: String) -> ChangeBody {
        .batchThrownAway(batchId: batch, quantity: quantity, date: date(on))
    }

    /// The replay of the bodies, with the changes `c0`, `c1`, and so on, in this order.
    private static func inventory(_ bodies: [ChangeBody]) -> Inventory {
        Inventory.replay(bodies.enumerated().map { index, body in Change(id: "c\(index)", at: index, origin: "test", body: body) })
    }

    private static let log: [ChangeBody] = [
        product("milk", "Milk", .l, .dairy),
        product("spinach", "Spinach", .g, .produce),
        product("soup", "Soup", nil, .leftovers),
        batch("m1", "milk", 2_000),
        batch("m2", "milk", 1_000),
        batch("s1", "spinach", 200_000),
        batch("s2", "spinach", 200_000),
        batch("p1", "soup", 3_000),
        used("m1", 500, "2026-10-20"), // c8
        thrown("s1", 200_000, "2026-10-31"), // c9
        used("m1", 1_500, "2026-11-11"), // c10
        thrown("m2", 250, "2026-11-12"), // c11
        used("m2", 750, "2026-11-12"), // c12
        thrown("s2", 50_000, "2026-11-12"), // c13
        thrown("p1", 1_000, "2026-11-03"), // c14
    ]

    private let content = HistoryContent.of(inventory(log), today: CalendarDate.parse("2026-11-12")!)

    @Test func theEntriesAreNewestFirstWithTheirProducts() {
        // The later date first. On one date, the later change first.
        #expect(content.lines.map(\.changeId) == ["c13", "c12", "c11", "c10", "c14", "c9", "c8"])
        #expect(
            content.lines.first == HistoryLine(
                changeId: "c13",
                batchId: "s2",
                productId: "spinach",
                name: "Spinach",
                category: .produce,
                unit: .g,
                quantity: 50_000,
                outcome: .thrownAway,
                date: today
            )
        )
    }

    @Test func aDeleteAndAnUndoRemoveTheirEntries() {
        let changes = Self.log + [
            .batchDeleted(batchId: "s1"),
            .productDeleted(productId: "soup"),
            .changeUndone(changeId: "c13"),
        ]
        let lines = HistoryContent.lines(Self.inventory(changes))
        #expect(lines.map(\.changeId) == ["c12", "c11", "c10", "c8"])
    }

    @Test func eachDayHasOneHeaderWithTodayAndYesterday() {
        let rows = content.items(.all)
        #expect(
            rows.map(\.key) == [
                "day-2026-11-12", "c13", "c12", "c11", "day-2026-11-11", "c10", "day-2026-11-03", "c14",
                "day-2026-10-31", "c9", "day-2026-10-20", "c8",
            ]
        )
        let days = rows.compactMap { row -> DayName? in
            if case .day(_, let name) = row {
                return name
            }
            return nil
        }
        #expect(days == [.today, .yesterday, .date, .date, .date])
        // The entries know their day, for VoiceOver.
        let c10 = rows.compactMap { row -> DayName? in
            if case .entry(let line, let day) = row, line.changeId == "c10" {
                return day
            }
            return nil
        }
        #expect(c10 == [.yesterday])
    }

    @Test func theFilterKeepsOneOutcomeAndOnlyTheDaysWithAnEntry() {
        #expect(content.items(.used).map(\.key) == ["day-2026-11-12", "c12", "day-2026-11-11", "c10", "day-2026-10-20", "c8"])
        #expect(
            content.items(.thrownAway).map(\.key)
                == ["day-2026-11-12", "c13", "c11", "day-2026-11-03", "c14", "day-2026-10-31", "c9"]
        )
    }

    @Test func aDateAfterTodayIsADate() {
        #expect(HistoryContent.dayName(date("2026-11-13"), today: today) == .date)
        #expect(HistoryContent.dayName(date("2026-11-10"), today: today) == .date)
    }

    @Test func thePeriodsAreCalendarMonths() {
        #expect(HistoryPeriod.thisMonth.contains(date("2026-11-01"), today: today))
        #expect(HistoryPeriod.thisMonth.contains(date("2026-11-30"), today: today))
        #expect(!HistoryPeriod.thisMonth.contains(date("2026-10-31"), today: today))
        #expect(!HistoryPeriod.thisMonth.contains(date("2025-11-12"), today: today))
        #expect(HistoryPeriod.lastMonth.contains(date("2026-10-01"), today: today))
        #expect(!HistoryPeriod.lastMonth.contains(date("2026-09-30"), today: today))
        // In January, the last month is December of the year before.
        let january = date("2027-01-05")
        #expect(HistoryPeriod.lastMonth.contains(date("2026-12-31"), today: january))
        #expect(!HistoryPeriod.lastMonth.contains(date("2027-12-31"), today: january))
        #expect(HistoryPeriod.all.contains(date("2001-01-01"), today: today))
    }

    @Test func theSummaryCountsBatchesAndAddsQuantitiesForEachUnit() {
        let month = content.summary(.thisMonth)
        // Milk m1 was used and m2 was partly used: two batches. M2 was also partly thrown away, so it counts there too.
        #expect(month.used == OutcomeTotal(batchCount: 2, quantities: [QuantityTotal(unit: .l, quantity: 2_250)]))
        // The litres, the grams, and the soup with no unit are three sums. The sum with no unit is last.
        #expect(
            month.thrownAway == OutcomeTotal(
                batchCount: 3,
                quantities: [
                    QuantityTotal(unit: .g, quantity: 50_000),
                    QuantityTotal(unit: .l, quantity: 250),
                    QuantityTotal(unit: nil, quantity: 1_000),
                ]
            )
        )

        let last = content.summary(.lastMonth)
        #expect(last.used == OutcomeTotal(batchCount: 1, quantities: [QuantityTotal(unit: .l, quantity: 500)]))
        #expect(last.thrownAway == OutcomeTotal(batchCount: 1, quantities: [QuantityTotal(unit: .g, quantity: 200_000)]))

        let all = content.summary(.all)
        #expect(all.used == OutcomeTotal(batchCount: 2, quantities: [QuantityTotal(unit: .l, quantity: 2_750)]))
        #expect(all.thrownAway.batchCount == 4)
    }

    @Test func theProductsThrownAwayMostOftenComeFirst() {
        // Spinach has two batches thrown away. Soup and milk have one each: milk was thrown away last.
        #expect(
            content.summary(.all).mostThrownAway == [
                ThrownAwayProduct(productId: "spinach", name: "Spinach", category: .produce, batchCount: 2),
                ThrownAwayProduct(productId: "milk", name: "Milk", category: .dairy, batchCount: 1),
                ThrownAwayProduct(productId: "soup", name: "Soup", category: .leftovers, batchCount: 1),
            ]
        )
        // In the last month, only the first batch of spinach was thrown away.
        #expect(content.summary(.lastMonth).mostThrownAway.map(\.productId) == ["spinach"])

        // Two thrown-away entries of one batch count as one batch. With the same number and date, the name decides.
        let lines = HistoryContent.lines(
            Self.inventory([
                Self.product("b", "banana", .pcs),
                Self.product("a", "Apple", .pcs),
                Self.product("c", "Cherry", .pcs),
                Self.product("d", "Date", .pcs),
                Self.batch("b1", "b", 5_000),
                Self.batch("a1", "a", 5_000),
                Self.batch("c1", "c", 5_000),
                Self.batch("d1", "d", 5_000),
                Self.thrown("b1", 1_000, "2026-11-01"),
                Self.thrown("b1", 1_000, "2026-11-01"),
                Self.thrown("a1", 1_000, "2026-11-01"),
                Self.thrown("c1", 1_000, "2026-11-01"),
                Self.thrown("d1", 1_000, "2026-11-01"),
            ])
        )
        #expect(HistoryContent.mostThrownAway(lines, limit: 3).map(\.name) == ["Apple", "banana", "Cherry"])
    }

    @Test func anEmptyHistoryHasNoRowsAndAnEmptySummary() {
        let empty = HistoryContent.of(
            Self.inventory([Self.product("milk", "Milk", .l), Self.batch("m1", "milk", 1_000)]),
            today: today
        )
        #expect(empty.items(.all) == [])
        for period in HistoryPeriod.allCases {
            let summary = empty.summary(period)
            #expect(summary.isEmpty)
            #expect(summary.used == OutcomeTotal(batchCount: 0, quantities: []))
            #expect(summary.mostThrownAway == [])
        }
        // A period with no entry is empty also when the history has entries.
        #expect(HistoryContent.summary(content.lines, period: .thisMonth, today: date("2027-03-01")).isEmpty)
    }
}
