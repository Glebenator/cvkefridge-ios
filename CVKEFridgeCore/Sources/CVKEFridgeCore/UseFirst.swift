import Foundation

// The use-first order and the plan of a use. Rules 5 and 6 of `spec/rules.md`.
// The Android file `core/src/main/kotlin/com/cvke/fridge/core/UseFirst.kt` in cvkefridge-android has the same
// behaviour.

/// A quantity that a plan takes from one batch.
public struct Take: Hashable, Sendable {
    public let batchId: String
    public let quantity: Int

    public init(batchId: String, quantity: Int) {
        self.batchId = batchId
        self.quantity = quantity
    }
}

/// The plan to use or throw away a quantity of a product. The shortfall is the quantity that the batches could not
/// give. It is 0 when the batches had enough.
public struct UsePlan: Hashable, Sendable {
    public let takes: [Take]
    public let shortfall: Int

    public init(takes: [Take], shortfall: Int) {
        self.takes = takes
        self.shortfall = shortfall
    }
}

/// The use-first order of batches and the plan of a use.
public enum UseFirst: Sendable {
    /// The active batches in the use-first order:
    /// 1. A batch with an expiry date comes before a batch without one.
    /// 2. The earlier expiry date comes first. The source of the date has no effect.
    /// 3. Then the earlier date added comes first.
    /// 4. Then the smaller batch identifier comes first.
    public static func order(_ batches: [Batch]) -> [Batch] {
        batches.filter { $0.isActive }.sorted(by: comesBefore)
    }

    /// The plan to take a quantity of a product from its active batches, in the use-first order. A quantity of 0 or
    /// less gives an empty plan with a shortfall of 0.
    public static func plan(_ batches: [Batch], productId: String, quantity: Int) -> UsePlan {
        var takes: [Take] = []
        var left = max(quantity, 0)
        for batch in order(batches.filter { $0.productId == productId }) {
            if left == 0 {
                break
            }
            let taken = min(left, batch.quantity)
            takes.append(Take(batchId: batch.id, quantity: taken))
            left -= taken
        }
        return UsePlan(takes: takes, shortfall: left)
    }

    /// True when `first` comes before `second` in the use-first order.
    private static func comesBefore(_ first: Batch, _ second: Batch) -> Bool {
        if let firstExpiry = first.expiry, let secondExpiry = second.expiry {
            if firstExpiry.date != secondExpiry.date {
                return firstExpiry.date < secondExpiry.date
            }
        } else if first.expiry != nil {
            return true
        } else if second.expiry != nil {
            return false
        }
        if first.dateAdded != second.dateAdded {
            return first.dateAdded < second.dateAdded
        }
        return first.id.utf8.lexicographicallyPrecedes(second.id.utf8)
    }
}
