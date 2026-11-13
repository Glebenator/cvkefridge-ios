import Foundation

// A batch of a product and its expiry date. Rules 1 and 5 of `spec/rules.md`.
// The Android file `core/src/main/kotlin/com/cvke/fridge/core/Batch.kt` in cvkefridge-android has the same types.

/// Where an expiry date comes from.
public enum ExpirySource: String, CaseIterable, Sendable {
    /// The date on the package, which the person entered.
    case printed
    /// The date from the table of foods.
    case estimated
    /// A later date that the person selected because the food is still good.
    case chosen
}

/// An expiry date and its source. A batch has both, or none of the two.
public struct ExpiryDate: Hashable, Sendable {
    public let date: CalendarDate
    public let source: ExpirySource

    public init(date: CalendarDate, source: ExpirySource) {
        self.date = date
        self.source = source
    }
}

/// A quantity of a product in a storage area. The quantity is a whole number of thousandths: `1500` is 1.5.
public struct Batch: Hashable, Sendable {
    public let id: String
    public let productId: String
    public let quantity: Int
    public let storageAreaId: String
    public let dateAdded: CalendarDate
    public let expiry: ExpiryDate?

    public init(
        id: String,
        productId: String,
        quantity: Int,
        storageAreaId: String,
        dateAdded: CalendarDate,
        expiry: ExpiryDate?
    ) {
        self.id = id
        self.productId = productId
        self.quantity = quantity
        self.storageAreaId = storageAreaId
        self.dateAdded = dateAdded
        self.expiry = expiry
    }

    /// True when the quantity is above 0. A batch with a quantity of 0 is ended.
    public var isActive: Bool {
        quantity > 0
    }
}
