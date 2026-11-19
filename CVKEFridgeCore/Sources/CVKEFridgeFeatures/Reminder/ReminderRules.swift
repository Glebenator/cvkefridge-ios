import Foundation

// Which batches go into the daily reminder. The Android file
// `app/src/main/java/com/cvke/fridge/reminder/ReminderRules.kt` in cvkefridge-android has the same behaviour.

/// One food in a reminder: a product with the batch that needs attention first.
public struct ReminderFood: Hashable, Sendable {
    public let productId: String
    public let name: String
    /// The days left of that batch: -1 for a batch that expired yesterday, 0 for today.
    public let daysLeft: Int
    /// True when the expiry date of that batch is an estimated date.
    public let estimated: Bool

    public init(productId: String, name: String, daysLeft: Int, estimated: Bool) {
        self.productId = productId
        self.name = name
        self.daysLeft = daysLeft
        self.estimated = estimated
    }
}

/// Which batches go into the daily reminder. The shared specification has no rule for reminders yet, so these are
/// the smallest rules that work. They must go into `spec/` of the cvkefridge repository, so that the two apps give the
/// same reminder for the same inventory.
///
/// 1. A batch is in the reminder of a date when it is active, it has an expiry date, and its days left on that date
///    are from -`expiredDays` to the lead time. With the default lead time, these are the batches that are expiring
///    (rule 3 of `spec/rules.md`), and the batches that expired yesterday.
/// 2. An expired batch is in the reminder only on the first day after its expiry date. After that day, Home and My
///    Fridge show it, and the reminder does not name it again each day. A batch that the person adds with an old date
///    is then not in a reminder.
/// 3. The reminder has one entry for each product, not one for each batch: the batch with the fewest days left, then
///    the batch that is first in the use-first order.
/// 4. The entries are in the order of their days left, then of their names (case has no effect), then of the product
///    identifiers.
public enum ReminderRules {
    /// The number of days after its expiry date that an expired batch is in the reminder.
    public static let expiredDays = 1

    /// The lead times that the person can select, in days before the expiry date. They stop at the last day that is
    /// "expiring" in the core rules, because a tap on the reminder opens My Fridge with the filters "Expiring" and
    /// "Expired". A longer lead time would name food that this list does not show.
    public static let leadDayChoices: ClosedRange<Int> = 0...Freshness.expiringWithinDays

    /// The lead time before the person selects one: all batches that are expiring.
    public static let defaultLeadDays = Freshness.expiringWithinDays

    /// The foods of the reminder of `today`, for a lead time of `leadDays` days. A lead time out of range uses the
    /// nearest choice. The list is empty when nothing needs a reminder.
    public static func foods(_ inventory: Inventory, today: CalendarDate, leadDays: Int) -> [ReminderFood] {
        let lead = min(max(leadDays, leadDayChoices.lowerBound), leadDayChoices.upperBound)
        var products: [String: Product] = [:]
        for product in inventory.products {
            products[product.id] = product
        }
        let areas = Set(inventory.storageAreas.map(\.id))
        // A batch is in a reminder only with its product and its storage area, as on the screens.
        let batches = inventory.activeBatches.filter { products[$0.productId] != nil && areas.contains($0.storageAreaId) }
        var seen = Set<String>()
        var foods: [ReminderFood] = []
        for batch in UseFirst.order(batches) {
            guard let expiry = batch.expiry, let product = products[batch.productId] else {
                continue
            }
            let daysLeft = today.daysUntil(expiry.date)
            guard daysLeft >= -expiredDays, daysLeft <= lead else {
                continue
            }
            // The use-first order puts the earlier expiry date first, so the first entry of a product is its first
            // batch.
            guard seen.insert(product.id).inserted else {
                continue
            }
            foods.append(
                ReminderFood(
                    productId: product.id,
                    name: product.name,
                    daysLeft: daysLeft,
                    estimated: expiry.source == .estimated
                )
            )
        }
        return foods.sorted { first, second in
            if first.daysLeft != second.daysLeft {
                return first.daysLeft < second.daysLeft
            }
            let names = compareIgnoringCase(first.name, second.name)
            if names != 0 {
                return names < 0
            }
            return first.productId.utf8.lexicographicallyPrecedes(second.productId.utf8)
        }
    }

    /// The order of Java's `String.CASE_INSENSITIVE_ORDER`, by Unicode scalars: each scalar is changed to upper case
    /// and then to lower case before the compare. The result is negative, 0, or positive.
    static func compareIgnoringCase(_ first: String, _ second: String) -> Int {
        var left = first.unicodeScalars.makeIterator()
        var right = second.unicodeScalars.makeIterator()
        while true {
            switch (left.next(), right.next()) {
            case (nil, nil):
                return 0
            case (nil, _):
                return -1
            case (_, nil):
                return 1
            case (let a?, let b?):
                if a == b {
                    continue
                }
                let foldedA = folded(a)
                let foldedB = folded(b)
                if foldedA != foldedB {
                    return foldedA.unicodeScalars.lexicographicallyPrecedes(foldedB.unicodeScalars) { $0.value < $1.value }
                        ? -1 : 1
                }
            }
        }
    }

    private static func folded(_ scalar: Unicode.Scalar) -> String {
        scalar.properties.uppercaseMapping.lowercased()
    }
}
