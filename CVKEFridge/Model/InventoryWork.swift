import CVKEFridgeFeatures
import Foundation

/// The calculations of the model that can be long for a large change log. Each runs off the main actor.
enum InventoryWork {
    /// The origin of the changes that the debug build writes as a sample. No phone has this identifier.
    static let sampleOrigin = "sample"

    /// The replay of the change log.
    @concurrent static func replay(_ changes: [Change]) async -> Inventory {
        Inventory.replay(changes)
    }

    /// The content of all screens for an inventory and a date. The content of Home, My Fridge, and History is
    /// calculated together, so that History is ready when the person opens it.
    ///
    /// - Parameters:
    ///   - changes: The change log of the `inventory`.
    ///   - origin: The identifier of this phone.
    ///   - skippedChanges: The number of lines of the change log that the app did not read.
    @concurrent static func content(
        changes: [Change],
        inventory: Inventory,
        foods: FoodTable,
        foodsAvailable: Bool,
        origin: String,
        skippedChanges: Int,
        today: CalendarDate
    ) async -> FridgeContent {
        FridgeContent(
            inventory: inventory,
            changes: changes,
            overview: InventoryContent.of(inventory, today: today, sample: changes.contains { $0.origin == sampleOrigin }),
            history: HistoryContent.of(inventory, today: today),
            today: today,
            foods: foods,
            foodsAvailable: foodsAvailable,
            lastAreaId: lastAreaId(changes: changes, inventory: inventory, origin: origin),
            recent: AddAgain.recent(changes: changes, inventory: inventory),
            skippedChanges: skippedChanges
        )
    }

    /// The values of the add form for a product that the lookup found.
    @concurrent static func scanned(
        barcode: String,
        product: LookedUpProduct,
        foods: FoodTable,
        hints: StorageHints
    ) async -> Scanned {
        ScannedFoods.found(barcode: barcode, product: product, foods: foods, hints: hints)
    }

    /// The storage area of the last batch that this phone added, or nil when that storage area is not there.
    ///
    /// Only a batch that is in the inventory counts. The Android app also counts an add that the person undid, so its
    /// next form starts in the storage area of a batch that does not exist.
    static func lastAreaId(changes: [Change], inventory: Inventory, origin: String) -> String? {
        let batches = Set(inventory.batches.map(\.id))
        var last: (change: Change, areaId: String)?
        for change in changes where change.origin == origin {
            guard case .batchAdded(let batch) = change.body, batches.contains(batch.id) else {
                continue
            }
            if let current = last?.change,
               (current.at, current.id) >= (change.at, change.id) {
                continue
            }
            last = (change, batch.storageAreaId)
        }
        guard let areaId = last?.areaId, inventory.storageAreas.contains(where: { $0.id == areaId }) else {
            return nil
        }
        return areaId
    }
}
