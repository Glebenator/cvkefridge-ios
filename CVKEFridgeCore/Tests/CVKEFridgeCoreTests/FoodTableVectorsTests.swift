import Foundation
import Testing
@testable import CVKEFridgeCore

/// Checks the facts of `spec/vectors/food-table.json` about `spec/foods.json`: the number of foods, the number with
/// days for each storage kind, the number with each usual storage kind, and some foods. They prove that `FoodTable.decode` reads the whole table. The Android
/// test `FoodTableVectorsTest` checks the same facts.
struct FoodTableVectorsTests {
    @Test func theWholeTableIsRead() throws {
        let table = try FoodTable.decode(Vectors.text("foods.json"))
        let file = try Vectors.load("food-table.json")
        let expected = try file.object("expect")

        var withDays: [String: Any] = [:]
        var withUsualKind: [String: Any] = [:]
        var withTips: [String: Any] = [:]
        for kind in StorageKind.allCases {
            withDays[kind.rawValue] = table.foods.filter { $0.days[kind] != nil }.count
            withUsualKind[kind.rawValue] = table.foods.filter { $0.usualKind == kind }.count
            withTips[kind.rawValue] = table.foods.filter { $0.tips[kind] != nil }.count
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
            var tips: [String: Any] = [:]
            for (kind, tip) in food.tips {
                tips[kind.rawValue] = tip
            }
            samples.append([
                "foodId": food.id,
                "name": food.name,
                "category": food.category.rawValue,
                "days": days,
                "usualKind": Vectors.orNull(food.usualKind?.rawValue),
                "common": food.common,
                "aliases": food.aliases,
                "tips": tips,
            ])
        }

        let actual: [String: Any] = [
            "count": table.foods.count,
            "withDays": withDays,
            "withUsualKind": withUsualKind,
            "common": table.foods.filter { $0.common }.count,
            "aliases": table.foods.reduce(0) { $0 + $1.aliases.count },
            "withTips": withTips,
            "samples": samples,
        ]
        try Vectors.check(actual, expected, "food-table.json")
    }

    @Test func aUsualKindThatIsNotAStorageKindIsAnError() {
        let text = #"{"foods":[{"id":"a","name":"A","category":"dairy","days":{},"usualKind":"shelf"}]}"#
        #expect(throws: (any Error).self) { try FoodTable.decode(text) }
    }

    @Test func aTipsKeyThatIsNotAStorageKindIsAnError() {
        let text = #"{"foods":[{"id":"a","name":"A","category":"dairy","days":{},"tips":{"shelf":"Dry."}}]}"#
        #expect(throws: (any Error).self) { try FoodTable.decode(text) }
    }

    @Test func theUsualKindCanBeAbsent() throws {
        let text = #"{"foods":[{"id":"a","name":"A","category":"dairy","days":{"fridge":3}}]}"#
        let food = try FoodTable.decode(text).food(id: "a")
        #expect(food?.usualKind == nil)
        #expect(food?.common == false)
        #expect(food?.aliases == [])
        #expect(food?.tips == [:])
    }
}
