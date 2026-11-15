import Foundation
import Testing
@testable import CVKEFridgeCore

/// Runs each case of `spec/vectors/change-log.json` (rule 7). Each change is read with `ChangeCodec.decode`. The test
/// compares every field of every product, storage area, batch, history entry, and rejection, in order. The Android
/// test `ChangeLogVectorsTest` runs the same file.
struct ChangeLogVectorsTests {
    @Test func replayCases() throws {
        let file = try Vectors.load("change-log.json")
        for item in try Vectors.cases(file, "cases") {
            let name = try item.string("name")
            let changes = try item.objects("changes").map { try ChangeCodec.decode(Vectors.canonical($0)) }
            let inventory = Inventory.replay(changes)
            try Vectors.check(result(inventory), item.object("expect"), name)
        }
    }

    /// The inventory in the JSON shape of the `expect` values.
    private func result(_ inventory: Inventory) -> [String: Any] {
        var products: [[String: Any]] = []
        for product in inventory.products {
            products.append([
                "id": product.id,
                "name": product.name,
                "category": product.category.rawValue,
                "unit": Vectors.orNull(product.unit?.rawValue),
                "barcode": Vectors.orNull(product.barcode),
                "foodId": Vectors.orNull(product.foodId),
                "note": Vectors.orNull(product.note),
                "storageText": Vectors.orNull(product.storageText),
            ])
        }
        var areas: [[String: Any]] = []
        for area in inventory.storageAreas {
            areas.append(["id": area.id, "name": area.name, "kind": area.kind.rawValue, "fixed": area.fixed])
        }
        var batches: [[String: Any]] = []
        for batch in inventory.batches {
            batches.append([
                "id": batch.id,
                "productId": batch.productId,
                "quantity": batch.quantity,
                "storageAreaId": batch.storageAreaId,
                "dateAdded": batch.dateAdded.text,
                "expiryDate": Vectors.orNull(batch.expiry?.date.text),
                "expirySource": Vectors.orNull(batch.expiry?.source.rawValue),
            ])
        }
        var history: [[String: Any]] = []
        for entry in inventory.history {
            history.append([
                "changeId": entry.changeId,
                "batchId": entry.batchId,
                "productId": entry.productId,
                "quantity": entry.quantity,
                "outcome": entry.outcome.rawValue,
                "date": entry.date.text,
            ])
        }
        var rejected: [[String: Any]] = []
        for rejection in inventory.rejected {
            rejected.append(["changeId": rejection.changeId, "reason": rejection.reason.rawValue])
        }
        return [
            "products": products,
            "storageAreas": areas,
            "batches": batches,
            "history": history,
            "rejected": rejected,
        ]
    }
}
