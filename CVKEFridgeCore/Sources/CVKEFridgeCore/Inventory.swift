import Foundation

// The inventory as the result of the change log. Rule 7 of `spec/rules.md`.
// The Android file `core/src/main/kotlin/com/cvke/fridge/core/Inventory.kt` in cvkefridge-android has the same
// behaviour.

/// What happened to a quantity that left a batch.
public enum Outcome: String, CaseIterable, Sendable {
    case used
    case thrownAway
}

/// A quantity that was used or thrown away. The history has the identifier of its change.
public struct HistoryEntry: Hashable, Sendable {
    public let changeId: String
    public let batchId: String
    public let productId: String
    public let quantity: Int
    public let outcome: Outcome
    public let date: CalendarDate

    public init(
        changeId: String,
        batchId: String,
        productId: String,
        quantity: Int,
        outcome: Outcome,
        date: CalendarDate
    ) {
        self.changeId = changeId
        self.batchId = batchId
        self.productId = productId
        self.quantity = quantity
        self.outcome = outcome
        self.date = date
    }
}

/// Why a change could not apply.
public enum RejectionReason: String, CaseIterable, Sendable {
    case unknownProduct
    case unknownStorageArea
    case unknownBatch
    case unknownChange
    case fixedStorageArea
    case storageAreaInUse
    case invalidQuantity
    case duplicateBatch
    case batchEnded
    case cannotUndo
}

/// A change that could not apply, and the reason.
public struct Rejection: Hashable, Sendable {
    public let changeId: String
    public let reason: RejectionReason

    public init(changeId: String, reason: RejectionReason) {
        self.changeId = changeId
        self.reason = reason
    }
}

/// The result of a replay of the change log. `products`, `storageAreas`, and `batches` are in the order of their
/// identifiers. `batches` has the active and the ended batches. `history` and `rejected` are in the order of the
/// replay.
public struct Inventory: Hashable, Sendable {
    public let products: [Product]
    public let storageAreas: [StorageArea]
    public let batches: [Batch]
    public let history: [HistoryEntry]
    public let rejected: [Rejection]

    public init(
        products: [Product],
        storageAreas: [StorageArea],
        batches: [Batch],
        history: [HistoryEntry],
        rejected: [Rejection]
    ) {
        self.products = products
        self.storageAreas = storageAreas
        self.batches = batches
        self.history = history
        self.rejected = rejected
    }

    /// The batches with a quantity above 0, in the order of their identifiers.
    public var activeBatches: [Batch] {
        batches.filter { $0.isActive }
    }

    /// The inventory that a change log gives (rule 7.1). The changes can be in any order, and the same change can be
    /// in the list more than one time.
    public static func replay(_ changes: [Change]) -> Inventory {
        // 1. Sort by instant, and then by identifier. Two changes with the same instant and identifier keep the
        //    order of the input, so that the result does not depend on the sort algorithm.
        let inOrder = changes.enumerated().sorted(by: { first, second in
            if first.element.at != second.element.at {
                return first.element.at < second.element.at
            }
            if first.element.id != second.element.id {
                return first.element.id.utf8.lexicographicallyPrecedes(second.element.id.utf8)
            }
            return first.offset < second.offset
        })

        // 2. Keep the first change of each identifier.
        var ordered: [Change] = []
        var seen = Set<String>()
        for item in inOrder {
            if seen.insert(item.element.id).inserted {
                ordered.append(item.element)
            }
        }
        var byId: [String: Change] = [:]
        for change in ordered {
            byId[change.id] = change
        }

        // 3. Find the changes that are undone (rule 7.3). An undo of an unknown change or of an undo is rejected at
        //    its own place in the replay.
        var undone = Set<String>()
        var undoRejections: [String: RejectionReason] = [:]
        for change in ordered {
            guard case .changeUndone(let targetId) = change.body else {
                continue
            }
            guard let target = byId[targetId] else {
                undoRejections[change.id] = .unknownChange
                continue
            }
            if case .changeUndone = target.body {
                undoRejections[change.id] = .cannotUndo
            } else {
                undone.insert(targetId)
            }
        }

        // 4. and 5. Start with the two fixed storage areas, and apply each change that is not undone.
        var state = ReplayState()
        var rejected: [Rejection] = []
        for change in ordered {
            if undone.contains(change.id) {
                continue
            }
            if let reason = state.apply(change, undoRejection: undoRejections[change.id]) {
                rejected.append(Rejection(changeId: change.id, reason: reason))
            }
        }

        return Inventory(
            products: state.products.values.sorted(by: { $0.id.utf8.lexicographicallyPrecedes($1.id.utf8) }),
            storageAreas: state.areas.values.sorted(by: { $0.id.utf8.lexicographicallyPrecedes($1.id.utf8) }),
            batches: state.batches.values.sorted(by: { $0.id.utf8.lexicographicallyPrecedes($1.id.utf8) }),
            history: state.history,
            rejected: rejected
        )
    }
}

/// The values during a replay.
private struct ReplayState {
    var products: [String: Product] = [:]
    var areas: [String: StorageArea] = [
        StorageArea.fridge.id: StorageArea.fridge,
        StorageArea.freezer.id: StorageArea.freezer,
    ]
    var batches: [String: Batch] = [:]
    var history: [HistoryEntry] = []

    /// Applies one change (rule 7.2). It returns the reason if the change cannot apply. The checks are in the order of
    /// rule 7.2. `undoRejection` is the result of step 3 for a `changeUndone`.
    mutating func apply(_ change: Change, undoRejection: RejectionReason?) -> RejectionReason? {
        switch change.body {
        case .productSaved(let product):
            products[product.id] = product
        case .productDeleted(let productId):
            if products[productId] == nil {
                return .unknownProduct
            }
            products[productId] = nil
            batches = batches.filter { $0.value.productId != productId }
            history = history.filter { $0.productId != productId }
        case .storageAreaSaved(let areaId, let name, let kind):
            if isFixed(areaId) {
                return .fixedStorageArea
            }
            areas[areaId] = StorageArea(id: areaId, name: name, kind: kind, fixed: false)
        case .storageAreaDeleted(let areaId):
            if isFixed(areaId) {
                return .fixedStorageArea
            }
            if areas[areaId] == nil {
                return .unknownStorageArea
            }
            if batches.values.contains(where: { $0.storageAreaId == areaId && $0.isActive }) {
                return .storageAreaInUse
            }
            areas[areaId] = nil
        case .batchAdded(let batch):
            if batches[batch.id] != nil {
                return .duplicateBatch
            }
            if products[batch.productId] == nil {
                return .unknownProduct
            }
            if areas[batch.storageAreaId] == nil {
                return .unknownStorageArea
            }
            if batch.quantity <= 0 {
                return .invalidQuantity
            }
            batches[batch.id] = batch
        case .batchEdited(let batchId, let quantity, let storageAreaId, let dateAdded, let expiry):
            guard let batch = batches[batchId] else {
                return .unknownBatch
            }
            if areas[storageAreaId] == nil {
                return .unknownStorageArea
            }
            if quantity <= 0 {
                return .invalidQuantity
            }
            batches[batchId] = Batch(
                id: batch.id,
                productId: batch.productId,
                quantity: quantity,
                storageAreaId: storageAreaId,
                dateAdded: dateAdded,
                expiry: expiry
            )
        case .batchUsed(let batchId, let quantity, let date):
            return take(changeId: change.id, batchId: batchId, quantity: quantity, date: date, outcome: .used)
        case .batchThrownAway(let batchId, let quantity, let date):
            return take(changeId: change.id, batchId: batchId, quantity: quantity, date: date, outcome: .thrownAway)
        case .batchDeleted(let batchId):
            if batches[batchId] == nil {
                return .unknownBatch
            }
            batches[batchId] = nil
            history = history.filter { $0.batchId != batchId }
        case .changeUndone:
            return undoRejection
        }
        return nil
    }

    /// Takes a quantity from a batch, but not more than the batch has, and adds a history entry.
    private mutating func take(
        changeId: String,
        batchId: String,
        quantity: Int,
        date: CalendarDate,
        outcome: Outcome
    ) -> RejectionReason? {
        guard let batch = batches[batchId] else {
            return .unknownBatch
        }
        if quantity <= 0 {
            return .invalidQuantity
        }
        if batch.quantity == 0 {
            return .batchEnded
        }
        let taken = min(quantity, batch.quantity)
        batches[batchId] = Batch(
            id: batch.id,
            productId: batch.productId,
            quantity: batch.quantity - taken,
            storageAreaId: batch.storageAreaId,
            dateAdded: batch.dateAdded,
            expiry: batch.expiry
        )
        history.append(
            HistoryEntry(
                changeId: changeId,
                batchId: batch.id,
                productId: batch.productId,
                quantity: taken,
                outcome: outcome,
                date: date
            )
        )
        return nil
    }

    private func isFixed(_ areaId: String) -> Bool {
        areaId == StorageArea.fridge.id || areaId == StorageArea.freezer.id
    }
}
