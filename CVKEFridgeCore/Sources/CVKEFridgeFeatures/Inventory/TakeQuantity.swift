import Foundation

// The quantity that the person records as used or as thrown away.
// The Android file `app/src/main/java/com/cvke/fridge/inventory/TakeQuantity.kt` in cvkefridge-android has the same
// behaviour.

/// What the person wants to record as used or as thrown away: a product, and the batches that can give the quantity.
/// A card of My Fridge gives the batches of the product in one storage area. The screen of a food gives all batches of
/// the product, or one batch.
public struct TakeRequest: Hashable, Sendable {
    public let productId: String
    public let batchIds: [String]
    public let outcome: Outcome

    public init(productId: String, batchIds: [String], outcome: Outcome) {
        self.productId = productId
        self.batchIds = batchIds
        self.outcome = outcome
    }

    /// The action for the request with no dialog for a quantity: when the batches have only one item left (see
    /// `TakeSource.oneLeft`), the action takes that item. Nil when the person must choose a quantity, or when the
    /// batches are not in the inventory.
    public func withoutDialog(_ inventory: Inventory) -> InventoryAction.Take? {
        guard let source = TakeSource.of(inventory: inventory, request: self), source.oneLeft else {
            return nil
        }
        return InventoryAction.Take(productId: productId, batchIds: batchIds, quantity: source.available, outcome: outcome)
    }
}

/// The result of `TakeSource.check`.
public enum TakeCheck: Hashable, Sendable {
    /// The quantity, in thousandths.
    case quantity(Int)
    /// The text is not a quantity.
    case problem(QuantityProblem)
    /// The quantity is more than the batches have.
    case tooMuch
}

/// The batches of a `TakeRequest` as they are in the inventory now. `firstQuantity` is the quantity of the oldest
/// batch, in thousandths. A form starts with it. `available` is the sum of the batches, in thousandths. The person
/// cannot take more.
public struct TakeSource: Hashable, Sendable {
    /// The units that count items.
    private static let countedUnits: Set<MeasureUnit> = [.pcs, .pack, .bottle, .slice]

    public let name: String
    public let unit: MeasureUnit?
    public let firstQuantity: Int
    public let available: Int

    public init(name: String, unit: MeasureUnit?, firstQuantity: Int, available: Int) {
        self.name = name
        self.unit = unit
        self.firstQuantity = firstQuantity
        self.available = available
    }

    /// True when the batches have one item left: a quantity of 1 with no unit, or with a unit that counts items. Then
    /// there is no quantity to choose. A quantity of 1 kg, 1 l or 1 cup can be divided, so it is not one item.
    public var oneLeft: Bool {
        available == 1_000 && (unit.map { TakeSource.countedUnits.contains($0) } ?? true)
    }

    /// The quantity in the `text`, a problem of the text, or `tooMuch`.
    public func check(_ text: String) -> TakeCheck {
        switch QuantityText.parse(text) {
        case .invalid(let problem):
            return .problem(problem)
        case .value(let thousandths):
            return thousandths > available ? .tooMuch : .quantity(thousandths)
        }
    }

    /// The source for the request, or nil when the product or all of the batches are not there.
    public static func of(inventory: Inventory, request: TakeRequest) -> TakeSource? {
        guard let product = inventory.products.first(where: { $0.id == request.productId }) else {
            return nil
        }
        let wanted = Set(request.batchIds)
        let batches = UseFirst.order(
            inventory.batches.filter { $0.productId == product.id && wanted.contains($0.id) }
        )
        guard let first = batches.first else {
            return nil
        }
        return TakeSource(
            name: product.name,
            unit: product.unit,
            firstQuantity: first.quantity,
            available: batches.reduce(0) { $0 + $1.quantity }
        )
    }
}
