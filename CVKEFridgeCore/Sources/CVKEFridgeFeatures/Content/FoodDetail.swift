import Foundation

// What the screen of a food shows.
// The Android file `app/src/main/java/com/cvke/fridge/ui/FoodDetail.kt` in cvkefridge-android has the same behaviour.

/// One active batch on the screen of a food. `quantity` is in thousandths.
public struct BatchLine: Hashable, Sendable {
    public let id: String
    public let quantity: Int
    public let areaName: String
    public let dateAdded: CalendarDate
    public let expiry: ExpiryDate?
    public let daysLeft: Int?
    public let freshness: Freshness

    public init(
        id: String,
        quantity: Int,
        areaName: String,
        dateAdded: CalendarDate,
        expiry: ExpiryDate?,
        daysLeft: Int?,
        freshness: Freshness
    ) {
        self.id = id
        self.quantity = quantity
        self.areaName = areaName
        self.dateAdded = dateAdded
        self.expiry = expiry
        self.daysLeft = daysLeft
        self.freshness = freshness
    }
}

/// What the screen of a food shows: the product, and its active batches in the use-first order. `total` is the sum of
/// the batches, in thousandths.
public struct FoodDetail: Hashable, Sendable {
    public let product: Product
    public let batches: [BatchLine]
    public let total: Int

    public init(product: Product, batches: [BatchLine], total: Int) {
        self.product = product
        self.batches = batches
        self.total = total
    }

    /// The detail of the product for the date `today`, or nil when the product is not in the inventory.
    public static func of(_ inventory: Inventory, productId: String, today: CalendarDate) -> FoodDetail? {
        guard let product = inventory.products.first(where: { $0.id == productId }) else {
            return nil
        }
        var areaNames: [String: String] = [:]
        for area in inventory.storageAreas {
            areaNames[area.id] = area.name
        }
        // A batch is on a screen only with its storage area, as on My Fridge.
        let batches = UseFirst.order(
            inventory.batches.filter { $0.productId == productId && areaNames[$0.storageAreaId] != nil }
        )
        return FoodDetail(
            product: product,
            batches: batches.map { batch in
                let daysLeft = Freshness.daysLeft(today: today, expiryDate: batch.expiry?.date)
                return BatchLine(
                    id: batch.id,
                    quantity: batch.quantity,
                    areaName: areaNames[batch.storageAreaId] ?? "",
                    dateAdded: batch.dateAdded,
                    expiry: batch.expiry,
                    daysLeft: daysLeft,
                    freshness: Freshness.of(daysLeft: daysLeft)
                )
            },
            total: batches.reduce(0) { $0 + $1.quantity }
        )
    }
}
