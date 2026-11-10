import Foundation

// A change in the change log. Rule 7 of `spec/rules.md`.
// The Android file `core/src/main/kotlin/com/cvke/fridge/core/Change.kt` in cvkefridge-android has the same types.

/// A change: its identifier, its instant in milliseconds from 1970-01-01T00:00:00Z, the identifier of the phone that
/// made it, and its body.
public struct Change: Hashable, Sendable {
    public let id: String
    public let at: Int
    public let origin: String
    public let body: ChangeBody

    public init(id: String, at: Int, origin: String, body: ChangeBody) {
        self.id = id
        self.at = at
        self.origin = origin
        self.body = body
    }
}

/// The body of a change. Each case is one type of change in rule 7.2. Quantities are whole thousandths.
public enum ChangeBody: Hashable, Sendable {
    case productSaved(product: Product)
    case productDeleted(productId: String)
    case storageAreaSaved(id: String, name: String, kind: StorageKind)
    case storageAreaDeleted(storageAreaId: String)
    case batchAdded(batch: Batch)
    case batchEdited(
        batchId: String,
        quantity: Int,
        storageAreaId: String,
        dateAdded: CalendarDate,
        expiry: ExpiryDate?
    )
    case batchUsed(batchId: String, quantity: Int, date: CalendarDate)
    case batchThrownAway(batchId: String, quantity: Int, date: CalendarDate)
    case batchDeleted(batchId: String)
    case changeUndone(changeId: String)
}
