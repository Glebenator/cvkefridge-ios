import Foundation
import Testing
@testable import CVKEFridgeCore

/// Checks the facts of `spec/vectors/food-table.json` about `spec/foods.json`: the number of foods, the number with
/// days for each storage kind, and some foods. They prove that `FoodTable.decode` reads the whole table. The Android
/// test `FoodTableVectorsTest` checks the same facts.
struct FoodTableVectorsTests {
    @Test func theWholeTableIsRead() throws {
        let table = try FoodTable.decode(Vectors.text("foods.json"))
        let file = try Vectors.load("food-table.json")
        let expected = try file.object("expect")

        var withDays: [String: Any] = [:]
        for kind in StorageKind.allCases {
            withDays[kind.rawValue] = table.foods.filter { $0.days[kind] != nil }.count
        }

        var samples: [[String: Any]] = []
        for sample in try Vectors.cases(expected, "samples") {
            let foodId = try sample.string("foodId")
            guard let food = table.food(id: foodId) else {
                Issue.record("The table has no food \(foodId)")
                continue
            }
            var days: [String: Any] = [:]
            for (kind, count) in food.days {
                days[kind.rawValue] = count
            }
            samples.append([
                "foodId": food.id,
                "name": food.name,
                "category": food.category.rawValue,
                "days": days,
            ])
        }

        let actual: [String: Any] = ["count": table.foods.count, "withDays": withDays, "samples": samples]
        try Vectors.check(actual, expected, "food-table.json")
    }
}
