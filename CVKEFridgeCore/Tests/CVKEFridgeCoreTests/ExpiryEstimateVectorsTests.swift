import Foundation
import Testing
@testable import CVKEFridgeCore

/// Runs each case of `spec/vectors/expiry-estimate.json` (rule 4). The table of foods comes from the `foods` in that
/// file. The Android test `ExpiryEstimateVectorsTest` runs the same file.
struct ExpiryEstimateVectorsTests {
    @Test func estimateCases() throws {
        let table = try FoodTable.decode(Vectors.text("vectors/expiry-estimate.json"))
        #expect(!table.foods.isEmpty, "The vector file has a table of foods")
        let file = try Vectors.load("expiry-estimate.json")
        for item in try Vectors.cases(file, "cases") {
            let foodId = try item.string("foodId")
            let kindText = try item.string("storageKind")
            guard let kind = StorageKind(rawValue: kindText) else {
                throw VectorError("\(kindText) is not a storage kind")
            }
            let dateAdded = try Vectors.date(item.string("dateAdded"))
            let estimate = table.estimate(foodId: foodId, kind: kind, dateAdded: dateAdded)
            let actual: [String: Any] = [
                "expiryDate": Vectors.orNull(estimate?.date.text),
                "expirySource": Vectors.orNull(estimate?.source.rawValue),
            ]
            try Vectors.check(actual, item.object("expect"), "\(foodId) in \(kindText), added \(dateAdded.text)")
        }
    }
}
