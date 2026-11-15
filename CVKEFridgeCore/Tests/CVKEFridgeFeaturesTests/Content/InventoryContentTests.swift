import Testing
@testable import CVKEFridgeFeatures

/// The content of the screens for a given inventory and date. The same cases as the Android InventoryContentTest. The
/// freshness rules have their own tests in the core.
struct InventoryContentTests {
    private let today = CalendarDate.parse("2026-11-11")!

    private static func date(_ text: String) -> CalendarDate {
        CalendarDate.parse(text)!
    }

    private static func product(_ id: String, _ name: String, _ category: CVKEFridgeCore.Category = .other) -> ChangeBody {
        .productSaved(product: Product(id: id, name: name, category: category, unit: .pcs, barcode: nil, foodId: nil))
    }

    private static func batch(
        _ id: String,
        _ product: String,
        _ area: String,
        _ added: String,
        _ expires: String?,
        quantity: Int = 1_000
    ) -> ChangeBody {
        .batchAdded(
            batch: Batch(
                id: id,
                productId: product,
                quantity: quantity,
                storageAreaId: area,
                dateAdded: date(added),
                expiry: expires.map { ExpiryDate(date: date($0), source: .printed) }
            )
        )
    }

    private static func content(_ bodies: [ChangeBody]) -> InventoryContent {
        let changes = bodies.enumerated().map { index, body in Change(id: "c\(index)", at: index, origin: "test", body: body) }
        return InventoryContent.of(Inventory.replay(changes), today: date("2026-11-11"))
    }

    private let sample = content([
        .storageAreaSaved(id: "pantry", name: "Pantry", kind: .pantry),
        product("milk", "milk", .dairy),
        product("eggs", "Eggs"),
        product("rice", "Rice"),
        product("ham", "Ham"),
        product("jam", "Jam"),
        product("tea", "Tea"),
        batch("b1", "milk", "fridge", "2026-11-05", "2026-11-12"),
        batch("b2", "milk", "fridge", "2026-11-10", "2026-11-20", quantity: 2_000),
        batch("b3", "eggs", "fridge", "2026-11-01", "2026-11-10"),
        batch("b4", "rice", "pantry", "2026-10-01", nil),
        batch("b5", "ham", "fridge", "2026-11-09", "2026-11-14"),
        batch("b6", "jam", "pantry", "2026-11-01", "2026-11-30"),
        batch("b7", "tea", "pantry", "2026-11-01", "2026-12-30"),
        batch("b8", "milk", "freezer", "2026-11-01", "2027-02-01"),
    ])

    @Test func attentionHasTheExpiredAndTheExpiringBatchesInTheUseFirstOrder() {
        #expect(sample.attention.map(\.id) == ["b3", "b1"])
        #expect(sample.attention.map(\.freshness) == [.expired, .expiring])
        #expect(sample.attention.map(\.daysLeft) == [-1, 1])
        #expect(sample.expiredCount == 1)
        #expect(sample.expiringCount == 1)
    }

    @Test func attentionStopsAtFiveBatchesAndTheCountsAreForAllBatches() {
        let many = Self.content(
            [Self.product("milk", "Milk")]
                + (1...7).map { Self.batch("b\($0)", "milk", "fridge", "2026-11-01", $0 <= 3 ? "2026-11-0\($0)" : "2026-11-11") }
        )
        #expect(many.attention.count == InventoryContent.attentionCount)
        #expect(many.attention.map(\.id) == ["b1", "b2", "b3", "b4", "b5"])
        #expect(many.expiredCount == 3)
        #expect(many.expiringCount == 4)
    }

    @Test func foodsHaveOneRowForEachProductInEachStorageArea() throws {
        #expect(
            sample.foods.map(\.key)
                == ["eggs/fridge", "ham/fridge", "milk/fridge", "milk/freezer", "jam/pantry", "rice/pantry", "tea/pantry"]
        )
        let milk = try #require(sample.foods.first(where: { $0.key == "milk/fridge" }))
        #expect(milk.quantity == 3_000)
        #expect(milk.expiryDateCount == 2)
        #expect(milk.daysLeft == 1)
        #expect(milk.dateAdded == Self.date("2026-11-10"))
        #expect(milk.batchIds == ["b1", "b2"])
        #expect(milk.firstQuantity == 1_000)
        #expect(sample.foods.first(where: { $0.key == "rice/pantry" })?.freshness == .noExpiryDate)
    }

    @Test func countsAreForProductsWithAnActiveBatch() {
        #expect(sample.foodCount == 6)
        #expect(sample.areas.map(\.id) == ["fridge", "freezer", "pantry"])
        #expect(sample.areas.map(\.foodCount) == [3, 1, 3])
    }

    @Test func aBatchThatWasUsedCompletelyIsNotOnAScreen() {
        let used = Self.content([
            Self.product("milk", "Milk"),
            Self.batch("b1", "milk", "fridge", "2026-11-05", "2026-11-12"),
            .batchUsed(batchId: "b1", quantity: 1_000, date: today),
        ])
        #expect(used.foodCount == 0)
        #expect(used.attention == [])
        #expect(used.foods == [])
        // A storage area with no food stays in the list, so that its tab does not go away.
        #expect(used.areas.map(\.id) == ["fridge", "freezer"])
        #expect(used.areas.map(\.foodCount) == [0, 0])
    }

    @Test func filterIsForOneStorageAreaOneCategoryAndTheSearchText() {
        func keys(_ areaId: String?, _ category: CVKEFridgeCore.Category?, _ query: String) -> [String] {
            sample.filtered(FoodFilter(areaId: areaId, category: category, query: query)).rows.map(\.key)
        }
        #expect(keys(nil, nil, " MIL ") == ["milk/fridge", "milk/freezer"])
        #expect(keys("freezer", nil, "") == ["milk/freezer"])
        #expect(keys("freezer", nil, "jam") == [])
        #expect(keys(nil, .dairy, "") == ["milk/fridge", "milk/freezer"])
        #expect(keys("fridge", .dairy, "") == ["milk/fridge"])
        // The search text is also in the category, the unit, and the name of the storage area.
        #expect(keys(nil, nil, "dairy") == ["milk/fridge", "milk/freezer"])
        #expect(keys(nil, nil, "pantry") == ["jam/pantry", "rice/pantry", "tea/pantry"])
    }

    @Test func theSearchTextIsInTheWordsOfTheScreen() {
        // The Android app finds only the English key. The app gives the words of its language.
        func keys(_ query: String) -> [String] {
            sample.filtered(
                FoodFilter(query: query),
                categoryLabel: { $0 == .dairy ? "Milchprodukte" : "Sonstiges" },
                unitLabel: { $0 == .pcs ? "Stk." : $0.rawValue }
            ).rows.map(\.key)
        }
        #expect(keys("milchprodukte") == ["milk/fridge", "milk/freezer"])
        #expect(keys("dairy") == [])
        #expect(keys("stk").count == 7)
    }

    @Test func theSearchTextIsAlsoInTheNote() {
        let content = Self.content([
            .productSaved(
                product: Product(
                    id: "jam",
                    name: "Jam",
                    category: .condiment,
                    unit: nil,
                    barcode: nil,
                    foodId: nil,
                    note: "For the CAKE"
                )
            ),
            Self.product("rice", "Rice"),
            Self.batch("b1", "jam", "fridge", "2026-11-05", nil),
            Self.batch("b2", "rice", "fridge", "2026-11-05", nil),
        ])
        #expect(content.foods.first(where: { $0.productId == "jam" })?.note == "For the CAKE")
        #expect(content.filtered(FoodFilter(query: "cake")).rows.map(\.key) == ["jam/fridge"])
    }

    @Test func filterIsForTheFreshnessOfEachBatchOfAFood() throws {
        func keys(_ freshness: Set<Freshness>, areaId: String? = nil) -> [String] {
            sample.filtered(FoodFilter(areaId: areaId, freshness: freshness)).rows.map(\.key)
        }
        #expect(keys([.expiring]) == ["milk/fridge"])
        #expect(keys([.expired]) == ["eggs/fridge"])
        // The two values together show the food that has one of them.
        #expect(keys([.expiring, .expired]) == ["eggs/fridge", "milk/fridge"])
        #expect(keys([.expiring], areaId: "pantry") == [])

        // A food with an expired batch and an expiring batch is one row, and each of the two filters shows it.
        let mixed = Self.content([
            Self.product("milk", "Milk"),
            Self.batch("b1", "milk", "fridge", "2026-11-01", "2026-11-10"),
            Self.batch("b2", "milk", "fridge", "2026-11-05", "2026-11-12"),
            Self.batch("b3", "milk", "fridge", "2026-11-10", "2026-11-30"),
        ])
        try #require(mixed.foods.count == 1)
        #expect(mixed.foods[0].freshness == .expired)
        #expect(mixed.foods[0].batchFreshness == [.expired, .expiring, .fresh])
        #expect(mixed.filtered(FoodFilter(freshness: [.expiring])).rows.count == 1)
        #expect(mixed.filtered(FoodFilter(freshness: [.expired])).rows.count == 1)
    }

    @Test func aFilterValueThatIsNotThereShowsAll() {
        // No storage area has this identifier.
        let gone = sample.filtered(FoodFilter(areaId: "cellar"))
        #expect(gone.areaId == nil)
        #expect(gone.rows.count == 7)
        // The Pantry has no dairy.
        let noDairy = sample.filtered(FoodFilter(areaId: "pantry", category: .dairy))
        #expect(noDairy.areaId == "pantry")
        #expect(noDairy.category == nil)
        #expect(noDairy.rows.map(\.key) == ["jam/pantry", "rice/pantry", "tea/pantry"])
        // A storage area with no food is a storage area. It does not show all.
        let empty = Self.content([Self.product("milk", "Milk"), Self.batch("b1", "milk", "fridge", "2026-11-05", nil)])
            .filtered(FoodFilter(areaId: "freezer"))
        #expect(empty.areaId == "freezer")
        #expect(empty.areaFoodCount == 0)
        #expect(empty.rows == [])
    }

    @Test func countsAreForTheStorageAreaTheSearchTextAndTheOtherFilter() {
        func categories(_ view: FilteredFoods) -> [CategoryCount] {
            view.categories
        }

        let all = sample.filtered(FoodFilter())
        #expect(all.areaFoodCount == 7)
        #expect(all.allCategoriesCount == 7)
        #expect(categories(all) == [CategoryCount(category: .dairy, foodCount: 2), CategoryCount(category: .other, foodCount: 5)])
        #expect(all.expiringCount == 1)
        #expect(all.expiredCount == 1)

        // The menu has the categories with food in the storage area.
        let freezer = sample.filtered(FoodFilter(areaId: "freezer"))
        #expect(freezer.areaFoodCount == 1)
        #expect(categories(freezer) == [CategoryCount(category: .dairy, foodCount: 1)])
        #expect(freezer.expiringCount == 0)

        // A category count is for the selected freshness. A category with no such food is not in the menu.
        let expired = sample.filtered(FoodFilter(freshness: [.expired]))
        #expect(expired.allCategoriesCount == 1)
        #expect(categories(expired) == [CategoryCount(category: .other, foodCount: 1)])
        // The selected category stays in the menu with a count of 0.
        let expiredDairy = sample.filtered(FoodFilter(category: .dairy, freshness: [.expired]))
        #expect(
            categories(expiredDairy)
                == [CategoryCount(category: .dairy, foodCount: 0), CategoryCount(category: .other, foodCount: 1)]
        )
        // The count of a freshness chip does not change when the chip is on.
        #expect(expired.expiringCount == 1)
        #expect(expired.expiredCount == 1)

        // A freshness count is for the selected category.
        let dairy = sample.filtered(FoodFilter(category: .dairy))
        #expect(dairy.expiringCount == 1)
        #expect(dairy.expiredCount == 0)
        #expect(dairy.allCategoriesCount == 7)

        // All counts are for the search text. The number of foods in the storage area is not.
        let search = sample.filtered(FoodFilter(query: "eggs"))
        #expect(search.areaFoodCount == 7)
        #expect(search.allCategoriesCount == 1)
        #expect(categories(search) == [CategoryCount(category: .other, foodCount: 1)])
        #expect(search.expiringCount == 0)
        #expect(search.expiredCount == 1)
    }

    @Test func sortKeepsFoodWithNoExpiryDateLastInBothDirections() {
        func keys(_ key: SortKey, _ ascending: Bool) -> [String] {
            InventoryContent.sort(sample.foods, key: key, ascending: ascending).map(\.key)
        }
        #expect(
            keys(.expiry, true)
                == ["eggs/fridge", "milk/fridge", "ham/fridge", "jam/pantry", "tea/pantry", "milk/freezer", "rice/pantry"]
        )
        #expect(
            keys(.expiry, false)
                == ["milk/freezer", "tea/pantry", "jam/pantry", "ham/fridge", "milk/fridge", "eggs/fridge", "rice/pantry"]
        )
    }

    @Test func sortHasTheOtherOrdersInBothDirections() {
        func keys(_ key: SortKey, _ ascending: Bool) -> [String] {
            InventoryContent.sort(sample.foods, key: key, ascending: ascending).map(\.key)
        }
        // Rows that are equal keep the order of the storage areas.
        #expect(
            keys(.name, true)
                == ["eggs/fridge", "ham/fridge", "jam/pantry", "milk/fridge", "milk/freezer", "rice/pantry", "tea/pantry"]
        )
        #expect(keys(.name, false).first == "tea/pantry")
        #expect(keys(.quantity, false).first == "milk/fridge")
        #expect(Array(keys(.dateAdded, false).prefix(2)) == ["milk/fridge", "ham/fridge"])
        #expect(keys(.dateAdded, true).first == "rice/pantry")
        #expect(Array(keys(.category, true).prefix(2)) == ["milk/fridge", "milk/freezer"])
    }

    @Test func theSortOrdersStartInTheirDirection() {
        #expect(SortKey.allCases.filter(\.ascendingFirst) == [.name, .expiry, .category])
    }

    @Test func aNameWithAnAccentIsSortedWithItsLetter() {
        // Android puts "Éclair" after "Zucchini".
        let content = Self.content([
            Self.product("z", "Zucchini"),
            Self.product("e", "Éclair"),
            Self.product("a", "apple"),
            Self.batch("b1", "z", "fridge", "2026-11-01", nil),
            Self.batch("b2", "e", "fridge", "2026-11-01", nil),
            Self.batch("b3", "a", "fridge", "2026-11-01", nil),
        ])
        #expect(content.foods.map(\.name) == ["apple", "Éclair", "Zucchini"])
    }
}
