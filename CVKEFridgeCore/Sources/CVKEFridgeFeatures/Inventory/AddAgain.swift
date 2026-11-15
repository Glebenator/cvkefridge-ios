import Foundation

// "Add again" and the list of recent foods of the add form.
// The Android file `app/src/main/java/com/cvke/fridge/inventory/AddAgain.kt` in cvkefridge-android has the same
// behaviour.

/// The start values of the add form for a product that the person had before. `storageAreaId` is the storage area of
/// the newest batch of the product, or nil when the product has no batch or that storage area is not there now.
/// `quantity` is the usual quantity of a batch of the product, in thousandths, or nil when it has no batch.
public struct AgainValues: Hashable, Sendable {
    public let storageAreaId: String?
    public let quantity: Int?

    public init(storageAreaId: String?, quantity: Int?) {
        self.storageAreaId = storageAreaId
        self.quantity = quantity
    }
}

/// A product of the list of recent foods. `at` is the instant of the last add, use, or throw away of the product, in
/// milliseconds from 1970-01-01T00:00:00Z. `changeId` is the identifier of that change, or nil when it is not known.
public struct RecentFood: Hashable, Sendable {
    public let product: Product
    public let at: Int
    public let changeId: String?

    public init(product: Product, at: Int, changeId: String? = nil) {
        self.product = product
        self.at = at
        self.changeId = changeId
    }
}

/// "Add again": a new batch of a product that the person had before, with the values of the earlier batches. The core
/// keeps a product when all its batches end, so the new batch goes to the same product, and the app makes no second
/// product. The form does not copy a date of an earlier batch: the date added is today, and the expiry date is the
/// estimated date from today, or no date when the food has no estimate.
///
/// The shared specification has no rule for this yet. These are the smallest rules that work.
public enum AddAgain {
    /// The largest number of products in the list of recent foods of the add form.
    public static let recentCount = 5

    /// The largest number of products that `recent` gives. The person can hide some of them.
    private static let recentKept = 30

    /// The start values for a new batch of the product.
    ///
    /// - Parameter changes: The change log of the `inventory`. The order of its `batchAdded` changes decides which of
    ///   two batches of one date added is newer. With no change of a batch, the larger identifier is newer. The
    ///   Android app uses only the identifier, which is random, so the "newest" batch of one day was random.
    public static func values(inventory: Inventory, productId: String, changes: [Change] = []) -> AgainValues {
        let batches = inventory.batches.filter { $0.productId == productId }
        if batches.isEmpty {
            return AgainValues(storageAreaId: nil, quantity: nil)
        }
        let areas = Set(inventory.storageAreas.map(\.id))
        var taken: [String: Int] = [:]
        for entry in inventory.history {
            taken[entry.batchId, default: 0] += entry.quantity
        }
        let order = addOrder(changes)
        let newestFirst = batches.sorted(by: { isNewer($0, $1, order: order) })
        let newestArea = newestFirst[0].storageAreaId
        return AgainValues(
            storageAreaId: areas.contains(newestArea) ? newestArea : nil,
            quantity: usualQuantity(newestFirst: newestFirst.map { $0.quantity + (taken[$0.id] ?? 0) })
        )
    }

    /// The quantity that the most batches had when they were added. With the same number of batches, the quantity of
    /// the newer batch wins.
    ///
    /// - Parameter newestFirst: The quantity of each batch when it was added, the newest batch first.
    public static func usualQuantity(newestFirst: [Int]) -> Int? {
        var counts: [Int: Int] = [:]
        for quantity in newestFirst {
            counts[quantity, default: 0] += 1
        }
        guard let most = counts.values.max() else {
            return nil
        }
        return newestFirst.first(where: { counts[$0] == most })
    }

    /// The products that the person added, used, or threw away last, the newest first, with a product in the
    /// inventory also. A change that was undone or that the core rejected does not count. Not more than 30 products.
    public static func recent(changes: [Change], inventory: Inventory) -> [RecentFood] {
        var batchProduct: [String: String] = [:]
        for batch in inventory.batches {
            batchProduct[batch.id] = batch.productId
        }
        var takenProduct: [String: String] = [:]
        for entry in inventory.history {
            takenProduct[entry.changeId] = entry.productId
        }
        let rejected = Set(inventory.rejected.map(\.changeId))
        var products: [String: Product] = [:]
        for product in inventory.products {
            products[product.id] = product
        }
        // The last change of each product. With the same instant, the later change in the log is the last.
        var last: [String: (at: Int, changeId: String)] = [:]
        for change in changes where !rejected.contains(change.id) {
            // An add that was undone has no batch in the inventory.
            let productId: String?
            if case .batchAdded(let batch) = change.body {
                productId = batchProduct[batch.id]
            } else {
                productId = takenProduct[change.id]
            }
            if let productId, products[productId] != nil, change.at >= (last[productId]?.at ?? change.at) {
                last[productId] = (change.at, change.id)
            }
        }
        return last
            .sorted(by: { first, second in
                if first.value.at != second.value.at {
                    return first.value.at > second.value.at
                }
                return first.key.utf8.lexicographicallyPrecedes(second.key.utf8)
            })
            .prefix(recentKept)
            .compactMap { entry in
                products[entry.key].map { RecentFood(product: $0, at: entry.value.at, changeId: entry.value.changeId) }
            }
    }

    /// The recent foods that the add form shows: not a product that the person removed from the list, unless it was
    /// added, used, or thrown away after that. Not more than `limit`.
    ///
    /// - Parameter hidden: The instant when the person removed each product from the list, by the identifier of the
    ///   product. `RecentSettings` keeps it.
    public static func shown(_ recent: [RecentFood], hidden: [String: Int], limit: Int = recentCount) -> [Product] {
        Array(
            recent
                .filter { food in hidden[food.product.id].map { food.at > $0 } ?? true }
                .prefix(max(limit, 0))
                .map(\.product)
        )
    }

    /// The recent foods that the add form shows: not a product that the person removed from the list
    /// (`RecentSettings.hides`), unless it was added, used, or thrown away after that. Not more than `limit`.
    public static func shown(_ recent: [RecentFood], settings: RecentSettings, limit: Int = recentCount) -> [Product] {
        Array(recent.filter { !settings.hides($0) }.prefix(max(limit, 0)).map(\.product))
    }

    /// True when the product has an active batch.
    public static func inStock(inventory: Inventory, productId: String) -> Bool {
        inventory.activeBatches.contains(where: { $0.productId == productId })
    }

    /// The place of the `batchAdded` change of each batch in the order of the replay: the instant, and then the place
    /// in the log. The phone gives each new change an instant after all earlier changes (`NewChanges.stamp`), so a
    /// larger place is a later add. The first change of an identifier counts, as in the replay.
    static func addOrder(_ changes: [Change]) -> [String: Int] {
        let inOrder = changes.enumerated().sorted(by: { first, second in
            first.element.at != second.element.at ? first.element.at < second.element.at : first.offset < second.offset
        })
        var seen = Set<String>()
        var order: [String: Int] = [:]
        for (place, item) in inOrder.enumerated() where seen.insert(item.element.id).inserted {
            if case .batchAdded(let batch) = item.element.body, order[batch.id] == nil {
                order[batch.id] = place
            }
        }
        return order
    }

    /// The newest batch first: the later date added, then the later `batchAdded` change, and then the larger
    /// identifier, so that the order is fixed. A batch with a known change comes before a batch with none.
    private static func isNewer(_ first: Batch, _ second: Batch, order: [String: Int]) -> Bool {
        if first.dateAdded != second.dateAdded {
            return first.dateAdded > second.dateAdded
        }
        switch (order[first.id], order[second.id]) {
        case let (firstPlace?, secondPlace?) where firstPlace != secondPlace:
            return firstPlace > secondPlace
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        default:
            return second.id.utf8.lexicographicallyPrecedes(first.id.utf8)
        }
    }
}
