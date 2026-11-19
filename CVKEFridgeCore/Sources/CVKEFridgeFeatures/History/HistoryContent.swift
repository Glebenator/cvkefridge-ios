import Foundation

// What the history shows.
// The Android file `app/src/main/java/com/cvke/fridge/history/HistoryContent.kt` in cvkefridge-android has the same
// behaviour.

/// One use or one throw away of a batch, as the history shows it: the history entry of the core with the name, the
/// category, and the unit of its product now. `changeId` is the change of the entry. It is different for each entry.
/// `quantity` is the quantity that was taken, in thousandths.
public struct HistoryLine: Hashable, Sendable {
    public let changeId: String
    public let batchId: String
    public let productId: String
    public let name: String
    public let category: CVKEFridgeCore.Category
    public let unit: MeasureUnit?
    public let quantity: Int
    public let outcome: Outcome
    public let date: CalendarDate

    public init(
        changeId: String,
        batchId: String,
        productId: String,
        name: String,
        category: CVKEFridgeCore.Category,
        unit: MeasureUnit?,
        quantity: Int,
        outcome: Outcome,
        date: CalendarDate
    ) {
        self.changeId = changeId
        self.batchId = batchId
        self.productId = productId
        self.name = name
        self.category = category
        self.unit = unit
        self.quantity = quantity
        self.outcome = outcome
        self.date = date
    }
}

/// The entries that the list of the history shows.
public enum HistoryFilter: String, CaseIterable, Sendable {
    case all
    case used
    case thrownAway

    /// True when the list shows an entry with this outcome.
    public func accepts(_ outcome: Outcome) -> Bool {
        switch self {
        case .all:
            return true
        case .used:
            return outcome == .used
        case .thrownAway:
            return outcome == .thrownAway
        }
    }
}

/// How the list names a day: "Today", "Yesterday", or the date.
public enum DayName: String, CaseIterable, Sendable {
    case today
    case yesterday
    case date
}

/// One row of the list of the history: the header of a day, or one entry of that day.
public enum HistoryItem: Hashable, Sendable {
    case day(date: CalendarDate, name: DayName)
    /// One entry. `day` is the name of its day, for VoiceOver.
    case entry(line: HistoryLine, day: DayName)

    /// A key that is different for each row of the list.
    public var key: String {
        switch self {
        case .day(let date, _):
            return "day-\(date.text)"
        case .entry(let line, _):
            return line.changeId
        }
    }
}

/// The time of the summary: a calendar month in the time zone of the device, or all of the history. The months follow
/// the calendar, so that two summaries do not count the same entry.
public enum HistoryPeriod: String, CaseIterable, Sendable {
    case thisMonth
    case lastMonth
    case all

    /// True when the `date` is in the period, for the date `today`.
    public func contains(_ date: CalendarDate, today: CalendarDate) -> Bool {
        switch self {
        case .thisMonth:
            return date.year == today.year && date.month == today.month
        case .lastMonth:
            let year = today.month == 1 ? today.year - 1 : today.year
            let month = today.month == 1 ? 12 : today.month - 1
            return date.year == year && date.month == month
        case .all:
            return true
        }
    }
}

/// The sum of quantities in one unit. A sum never adds two units: 1 l and 500 g are two sums. `unit` is nil for the
/// products that have no unit. `quantity` is in thousandths.
public struct QuantityTotal: Hashable, Sendable {
    public let unit: MeasureUnit?
    public let quantity: Int

    public init(unit: MeasureUnit?, quantity: Int) {
        self.unit = unit
        self.quantity = quantity
    }
}

/// What one outcome came to in a period. `batchCount` is the number of batches with an entry of the outcome. A batch
/// with two entries counts one time. A batch that was partly used and partly thrown away counts for each of the two
/// outcomes. `quantities` has the quantities of the entries, one sum for each unit, in the order of the units.
public struct OutcomeTotal: Hashable, Sendable {
    public let batchCount: Int
    public let quantities: [QuantityTotal]

    public init(batchCount: Int, quantities: [QuantityTotal]) {
        self.batchCount = batchCount
        self.quantities = quantities
    }
}

/// A product, with the number of its batches that were thrown away in a period.
public struct ThrownAwayProduct: Hashable, Sendable {
    public let productId: String
    public let name: String
    public let category: CVKEFridgeCore.Category
    public let batchCount: Int

    public init(productId: String, name: String, category: CVKEFridgeCore.Category, batchCount: Int) {
        self.productId = productId
        self.name = name
        self.category = category
        self.batchCount = batchCount
    }
}

/// The summary of a period: what was used, what was thrown away, and the products that were thrown away most often.
/// It has counts and quantities only. The app does not calculate money or other values that it does not have.
public struct HistorySummary: Hashable, Sendable {
    public let used: OutcomeTotal
    public let thrownAway: OutcomeTotal
    public let mostThrownAway: [ThrownAwayProduct]

    public init(used: OutcomeTotal, thrownAway: OutcomeTotal, mostThrownAway: [ThrownAwayProduct]) {
        self.used = used
        self.thrownAway = thrownAway
        self.mostThrownAway = mostThrownAway
    }

    /// True when nothing was used or thrown away in the period.
    public var isEmpty: Bool {
        used.batchCount == 0 && thrownAway.batchCount == 0
    }
}

/// What the history shows, calculated from the inventory and the date of today. The history of the core has an entry
/// for each use and each throw away. A delete removes the entries of the deleted batch or product, and an undo removes
/// the entry of the undone change, so they are not here.
public struct HistoryContent: Hashable, Sendable {
    /// The largest number of products in the list of the products that were thrown away most often.
    public static let mostThrownAwayCount = 3

    /// All entries, the newest first: the later date first, and on one date the later change first.
    public let lines: [HistoryLine]
    private let itemsByFilter: [HistoryFilter: [HistoryItem]]
    private let summaries: [HistoryPeriod: HistorySummary]

    private init(
        lines: [HistoryLine],
        itemsByFilter: [HistoryFilter: [HistoryItem]],
        summaries: [HistoryPeriod: HistorySummary]
    ) {
        self.lines = lines
        self.itemsByFilter = itemsByFilter
        self.summaries = summaries
    }

    /// The rows of the list for the `filter`.
    public func items(_ filter: HistoryFilter) -> [HistoryItem] {
        itemsByFilter[filter] ?? []
    }

    /// The summary of the `period`.
    public func summary(_ period: HistoryPeriod) -> HistorySummary {
        summaries[period] ?? HistorySummary(
            used: OutcomeTotal(batchCount: 0, quantities: []),
            thrownAway: OutcomeTotal(batchCount: 0, quantities: []),
            mostThrownAway: []
        )
    }

    /// The content of the history of the `inventory` for the date `today`. The list and the summaries are calculated
    /// one time, so call this function off the main actor for a long history.
    public static func of(_ inventory: Inventory, today: CalendarDate) -> HistoryContent {
        let lines = lines(inventory)
        var itemsByFilter: [HistoryFilter: [HistoryItem]] = [:]
        for filter in HistoryFilter.allCases {
            itemsByFilter[filter] = items(lines, filter: filter, today: today)
        }
        var summaries: [HistoryPeriod: HistorySummary] = [:]
        for period in HistoryPeriod.allCases {
            summaries[period] = summary(lines, period: period, today: today)
        }
        return HistoryContent(lines: lines, itemsByFilter: itemsByFilter, summaries: summaries)
    }

    /// The entries of the history with their products, the newest first. An entry with no product is not shown.
    public static func lines(_ inventory: Inventory) -> [HistoryLine] {
        var products: [String: Product] = [:]
        for product in inventory.products {
            products[product.id] = product
        }
        // The history of the core is in the order of the replay. On one date, a later change comes first.
        return inventory.history.enumerated()
            .compactMap { index, entry -> (index: Int, line: HistoryLine)? in
                guard let product = products[entry.productId] else {
                    return nil
                }
                let line = HistoryLine(
                    changeId: entry.changeId,
                    batchId: entry.batchId,
                    productId: product.id,
                    name: product.name,
                    category: product.category,
                    unit: product.unit,
                    quantity: entry.quantity,
                    outcome: entry.outcome,
                    date: entry.date
                )
                return (index, line)
            }
            .sorted(by: { first, second in
                if first.line.date != second.line.date {
                    return first.line.date > second.line.date
                }
                return first.index > second.index
            })
            .map(\.line)
    }

    /// The rows of the list: for each day with an entry for the `filter`, its header and then its entries.
    public static func items(_ lines: [HistoryLine], filter: HistoryFilter, today: CalendarDate) -> [HistoryItem] {
        var rows: [HistoryItem] = []
        var day: CalendarDate? = nil
        for line in lines where filter.accepts(line.outcome) {
            let name = dayName(line.date, today: today)
            if line.date != day {
                rows.append(.day(date: line.date, name: name))
                day = line.date
            }
            rows.append(.entry(line: line, day: name))
        }
        return rows
    }

    /// "Today" and "Yesterday" for these two dates. A date after today, for example after a change of the clock, is a
    /// date.
    public static func dayName(_ date: CalendarDate, today: CalendarDate) -> DayName {
        switch today.daysUntil(date) {
        case 0:
            return .today
        case -1:
            return .yesterday
        default:
            return .date
        }
    }

    /// The summary of the lines in the `period`, for the date `today`.
    public static func summary(_ lines: [HistoryLine], period: HistoryPeriod, today: CalendarDate) -> HistorySummary {
        let inPeriod = lines.filter { period.contains($0.date, today: today) }
        return HistorySummary(
            used: total(inPeriod, outcome: .used),
            thrownAway: total(inPeriod, outcome: .thrownAway),
            mostThrownAway: mostThrownAway(inPeriod, limit: mostThrownAwayCount)
        )
    }

    /// The batches and the quantities of the entries with the `outcome`.
    public static func total(_ lines: [HistoryLine], outcome: Outcome) -> OutcomeTotal {
        let matching = lines.filter { $0.outcome == outcome }
        return OutcomeTotal(batchCount: Set(matching.map(\.batchId)).count, quantities: totals(matching))
    }

    /// One sum for each unit, in the order of `MeasureUnit`. The sum of the products with no unit is last.
    public static func totals(_ lines: [HistoryLine]) -> [QuantityTotal] {
        var sums: [MeasureUnit?: Int] = [:]
        for line in lines {
            sums[line.unit, default: 0] += line.quantity
        }
        let units: [MeasureUnit?] = MeasureUnit.allCases.map { $0 } + [nil]
        return units.compactMap { unit in sums[unit].map { QuantityTotal(unit: unit, quantity: $0) } }
    }

    /// The products with the most batches that were thrown away, not more than `limit`. With the same number, the
    /// product that was thrown away last comes first, and then the name decides.
    public static func mostThrownAway(_ lines: [HistoryLine], limit: Int) -> [ThrownAwayProduct] {
        var groups: [String: [HistoryLine]] = [:]
        var order: [String] = []
        for line in lines where line.outcome == .thrownAway {
            if groups[line.productId] == nil {
                order.append(line.productId)
            }
            groups[line.productId, default: []].append(line)
        }
        let products = order.compactMap { id -> (product: ThrownAwayProduct, newest: CalendarDate)? in
            guard let group = groups[id], var newest = group.first else {
                return nil
            }
            // The first line with the latest date, as `maxBy` of Kotlin.
            for line in group where line.date > newest.date {
                newest = line
            }
            let product = ThrownAwayProduct(
                productId: id,
                name: newest.name,
                category: newest.category,
                batchCount: Set(group.map(\.batchId)).count
            )
            return (product, newest.date)
        }
        return products
            .sorted(by: { first, second in
                if first.product.batchCount != second.product.batchCount {
                    return first.product.batchCount > second.product.batchCount
                }
                if first.newest != second.newest {
                    return first.newest > second.newest
                }
                let names = Names.order(first.product.name, second.product.name)
                if names != .orderedSame {
                    return names == .orderedAscending
                }
                return first.product.productId.utf8.lexicographicallyPrecedes(second.product.productId.utf8)
            })
            .prefix(max(limit, 0))
            .map(\.product)
    }
}
