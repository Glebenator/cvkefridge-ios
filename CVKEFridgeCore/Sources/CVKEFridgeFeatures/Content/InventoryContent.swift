import Foundation

// What Home and My Fridge show.
// The Android file `app/src/main/java/com/cvke/fridge/ui/InventoryContent.kt` in cvkefridge-android has the same
// behaviour.

/// One expired or expiring batch on Home. `quantity` is a whole number of thousandths.
public struct AttentionBatch: Hashable, Sendable {
    public let id: String
    public let productId: String
    public let name: String
    public let category: CVKEFridgeCore.Category
    public let quantity: Int
    public let unit: MeasureUnit?
    public let expiry: ExpiryDate
    public let daysLeft: Int
    public let freshness: Freshness

    public init(
        id: String,
        productId: String,
        name: String,
        category: CVKEFridgeCore.Category,
        quantity: Int,
        unit: MeasureUnit?,
        expiry: ExpiryDate,
        daysLeft: Int,
        freshness: Freshness
    ) {
        self.id = id
        self.productId = productId
        self.name = name
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.expiry = expiry
        self.daysLeft = daysLeft
        self.freshness = freshness
    }
}

/// A storage area, with the number of foods in it. The number is 0 for a storage area with no food.
public struct AreaSummary: Hashable, Sendable {
    public let id: String
    public let name: String
    public let foodCount: Int

    public init(id: String, name: String, foodCount: Int) {
        self.id = id
        self.name = name
        self.foodCount = foodCount
    }
}

/// One food in one storage area: all active batches of a product there.
public struct FoodRow: Hashable, Sendable {
    /// The product and the storage area, as `productId/areaId`.
    public let key: String
    public let productId: String
    /// The batches, in the use-first order.
    public let batchIds: [String]
    public let name: String
    public let category: CVKEFridgeCore.Category
    /// The sum of the batches, in thousandths.
    public let quantity: Int
    /// The quantity of the batch to use first, in thousandths.
    public let firstQuantity: Int
    public let unit: MeasureUnit?
    public let areaId: String
    public let areaName: String
    /// The date added of the newest batch.
    public let dateAdded: CalendarDate
    /// The expiry date of the batch to use first, or nil.
    public let expiry: ExpiryDate?
    public let daysLeft: Int?
    /// The freshness of the batch to use first.
    public let freshness: Freshness
    /// The freshness of each batch. A food can have an expired batch and an expiring batch.
    public let batchFreshness: Set<Freshness>
    /// The number of different expiry dates of the batches.
    public let expiryDateCount: Int
    public let note: String?

    public init(
        key: String,
        productId: String,
        batchIds: [String],
        name: String,
        category: CVKEFridgeCore.Category,
        quantity: Int,
        firstQuantity: Int,
        unit: MeasureUnit?,
        areaId: String,
        areaName: String,
        dateAdded: CalendarDate,
        expiry: ExpiryDate?,
        daysLeft: Int?,
        freshness: Freshness,
        batchFreshness: Set<Freshness>,
        expiryDateCount: Int,
        note: String? = nil
    ) {
        self.key = key
        self.productId = productId
        self.batchIds = batchIds
        self.name = name
        self.category = category
        self.quantity = quantity
        self.firstQuantity = firstQuantity
        self.unit = unit
        self.areaId = areaId
        self.areaName = areaName
        self.dateAdded = dateAdded
        self.expiry = expiry
        self.daysLeft = daysLeft
        self.freshness = freshness
        self.batchFreshness = batchFreshness
        self.expiryDateCount = expiryDateCount
        self.note = note
    }
}

/// The filters of My Fridge.
public struct FoodFilter: Hashable, Sendable {
    /// The storage area, or nil for all.
    public var areaId: String?
    /// The category, or nil for all.
    public var category: CVKEFridgeCore.Category?
    /// The freshness values to show. A food is shown when one of its batches has one of them. The empty set shows all
    /// food.
    public var freshness: Set<Freshness>
    /// The search text.
    public var query: String

    public init(
        areaId: String? = nil,
        category: CVKEFridgeCore.Category? = nil,
        freshness: Set<Freshness> = [],
        query: String = ""
    ) {
        self.areaId = areaId
        self.category = category
        self.freshness = freshness
        self.query = query
    }
}

/// A category in the menu of the categories, with the number of foods that its menu item shows.
public struct CategoryCount: Hashable, Sendable {
    public let category: CVKEFridgeCore.Category
    public let foodCount: Int

    public init(category: CVKEFridgeCore.Category, foodCount: Int) {
        self.category = category
        self.foodCount = foodCount
    }
}

/// What My Fridge shows for a `FoodFilter`. Each count is the number of rows that the list has when the person
/// selects that value and does not change the other filters.
public struct FilteredFoods: Hashable, Sendable {
    /// The storage area of the filter, or nil for all. It is also nil when the storage area of the filter is not
    /// there.
    public let areaId: String?
    /// The category of the filter, or nil for all. It is also nil when the category of the filter has no food in the
    /// storage area.
    public let category: CVKEFridgeCore.Category?
    /// The number of foods in the storage area, with no other filter.
    public let areaFoodCount: Int
    /// The categories that the menu shows, in the order of `Category`: each category with a count above 0, and the
    /// category of the filter.
    public let categories: [CategoryCount]
    /// The count for "All categories".
    public let allCategoriesCount: Int
    /// The count for "Expiring".
    public let expiringCount: Int
    /// The count for "Expired".
    public let expiredCount: Int
    /// The rows that agree with all filters, in the order of `InventoryContent.foods`.
    public let rows: [FoodRow]

    public init(
        areaId: String?,
        category: CVKEFridgeCore.Category?,
        areaFoodCount: Int,
        categories: [CategoryCount],
        allCategoriesCount: Int,
        expiringCount: Int,
        expiredCount: Int,
        rows: [FoodRow]
    ) {
        self.areaId = areaId
        self.category = category
        self.areaFoodCount = areaFoodCount
        self.categories = categories
        self.allCategoriesCount = allCategoriesCount
        self.expiringCount = expiringCount
        self.expiredCount = expiredCount
        self.rows = rows
    }
}

/// The sort orders of My Fridge. They are the sort orders of FridgeFriend.
public enum SortKey: String, CaseIterable, Sendable {
    case name
    case expiry
    case dateAdded
    case quantity
    case category

    /// The direction that the order starts with.
    public var ascendingFirst: Bool {
        switch self {
        case .name, .expiry, .category:
            return true
        case .dateAdded, .quantity:
            return false
        }
    }
}

/// What the two screens show, calculated from the inventory and the date of today.
public struct InventoryContent: Hashable, Sendable {
    /// The largest number of batches that Home shows.
    public static let attentionCount = 5

    /// The first expired and expiring batches, in the use-first order.
    public let attention: [AttentionBatch]
    /// The number of all expired batches.
    public let expiredCount: Int
    /// The number of all expiring batches.
    public let expiringCount: Int
    /// All storage areas: Fridge, Freezer, and then the others by name.
    public let areas: [AreaSummary]
    /// One row for each food in each storage area, in the order of `areas` and then by name.
    public let foods: [FoodRow]
    /// The number of products with an active batch.
    public let foodCount: Int
    /// True when a change in the log comes from the sample of the debug build.
    public let sample: Bool

    public init(
        attention: [AttentionBatch],
        expiredCount: Int,
        expiringCount: Int,
        areas: [AreaSummary],
        foods: [FoodRow],
        foodCount: Int,
        sample: Bool
    ) {
        self.attention = attention
        self.expiredCount = expiredCount
        self.expiringCount = expiringCount
        self.areas = areas
        self.foods = foods
        self.foodCount = foodCount
        self.sample = sample
    }

    /// The rows and the counts for `filter`. The search text is compared with the name, the category, the unit, the
    /// name of the storage area, and the note. Case has no effect.
    ///
    /// The Android app compares the search text with the key of the category and of the unit, for example "dairy".
    /// That works only in English. Give the words that the screen shows in `categoryLabel` and `unitLabel`. The
    /// default is the key, as on Android.
    public func filtered(
        _ filter: FoodFilter,
        categoryLabel: (CVKEFridgeCore.Category) -> String = { $0.rawValue },
        unitLabel: (MeasureUnit) -> String = { $0.rawValue }
    ) -> FilteredFoods {
        let area = areas.first(where: { $0.id == filter.areaId })
        let inArea = area.map { area in foods.filter { $0.areaId == area.id } } ?? foods
        let category = filter.category.flatMap { wanted in inArea.contains(where: { $0.category == wanted }) ? wanted : nil }
        let text = filter.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let found = inArea.filter { row in
            if text.isEmpty {
                return true
            }
            let words = [row.name, categoryLabel(row.category), row.unit.map(unitLabel), row.areaName, row.note]
            return words.contains(where: { word in word?.range(of: text, options: .caseInsensitive) != nil })
        }
        // The counts of one filter are for the rows that agree with the search text and with the other filter.
        let withFreshness = found.filter { row in
            filter.freshness.isEmpty || !row.batchFreshness.isDisjoint(with: filter.freshness)
        }
        let withCategory = found.filter { category == nil || $0.category == category }
        // A category with a count of 0 gives an empty list, so the menu does not have it. The selected category stays.
        let categories = CVKEFridgeCore.Category.allCases
            .map { entry in CategoryCount(category: entry, foodCount: withFreshness.filter { $0.category == entry }.count) }
            .filter { $0.foodCount > 0 || $0.category == category }
        return FilteredFoods(
            areaId: area?.id,
            category: category,
            areaFoodCount: inArea.count,
            categories: categories,
            allCategoriesCount: withFreshness.count,
            expiringCount: withCategory.filter { $0.batchFreshness.contains(.expiring) }.count,
            expiredCount: withCategory.filter { $0.batchFreshness.contains(.expired) }.count,
            rows: withFreshness.filter { category == nil || $0.category == category }
        )
    }

    /// The content of the `inventory` for the date `today`. `sample` is true when a change in the log comes from the
    /// sample of the debug build.
    public static func of(_ inventory: Inventory, today: CalendarDate, sample: Bool = false) -> InventoryContent {
        var products: [String: Product] = [:]
        for product in inventory.products {
            products[product.id] = product
        }
        let areas = inventory.storageAreas.sorted(by: areaComesBefore)
        var areaNames: [String: String] = [:]
        var areaIndex: [String: Int] = [:]
        for (index, area) in areas.enumerated() {
            areaNames[area.id] = area.name
            areaIndex[area.id] = index
        }
        // A batch is on a screen only with its product and its storage area.
        let active = inventory.activeBatches.filter { products[$0.productId] != nil && areaNames[$0.storageAreaId] != nil }

        let useFirst = UseFirst.order(active).compactMap { batch -> AttentionBatch? in
            guard let expiry = batch.expiry, let product = products[batch.productId] else {
                return nil
            }
            let daysLeft = today.daysUntil(expiry.date)
            let freshness = Freshness.of(daysLeft: daysLeft)
            guard freshness == .expired || freshness == .expiring else {
                return nil
            }
            return AttentionBatch(
                id: batch.id,
                productId: product.id,
                name: product.name,
                category: product.category,
                quantity: batch.quantity,
                unit: product.unit,
                expiry: expiry,
                daysLeft: daysLeft,
                freshness: freshness
            )
        }

        var groups: [String: [Batch]] = [:]
        var groupOrder: [String] = []
        for batch in active {
            let key = "\(batch.productId)/\(batch.storageAreaId)"
            if groups[key] == nil {
                groupOrder.append(key)
            }
            groups[key, default: []].append(batch)
        }
        let foods = groupOrder.compactMap { key -> FoodRow? in
            guard let batches = groups[key], let product = products[batches[0].productId],
                  let areaId = batches.first?.storageAreaId, let areaName = areaNames[areaId]
            else {
                return nil
            }
            let ordered = UseFirst.order(batches)
            let first = ordered[0]
            let daysLeft = Freshness.daysLeft(today: today, expiryDate: first.expiry?.date)
            return FoodRow(
                key: key,
                productId: product.id,
                batchIds: ordered.map(\.id),
                name: product.name,
                category: product.category,
                quantity: batches.reduce(0) { $0 + $1.quantity },
                firstQuantity: first.quantity,
                unit: product.unit,
                areaId: areaId,
                areaName: areaName,
                dateAdded: batches.map(\.dateAdded).max() ?? first.dateAdded,
                expiry: first.expiry,
                daysLeft: daysLeft,
                freshness: Freshness.of(daysLeft: daysLeft),
                batchFreshness: Set(
                    batches.map { Freshness.of(daysLeft: Freshness.daysLeft(today: today, expiryDate: $0.expiry?.date)) }
                ),
                expiryDateCount: Set(batches.compactMap { $0.expiry?.date }).count,
                note: product.note
            )
        }.sorted(by: { first, second in
            let firstArea = areaIndex[first.areaId] ?? Int.max
            let secondArea = areaIndex[second.areaId] ?? Int.max
            if firstArea != secondArea {
                return firstArea < secondArea
            }
            let names = Names.order(first.name, second.name)
            if names != .orderedSame {
                return names == .orderedAscending
            }
            return first.key.utf8.lexicographicallyPrecedes(second.key.utf8)
        })

        return InventoryContent(
            attention: Array(useFirst.prefix(attentionCount)),
            expiredCount: useFirst.filter { $0.freshness == .expired }.count,
            expiringCount: useFirst.filter { $0.freshness == .expiring }.count,
            areas: areas.map { area in
                AreaSummary(id: area.id, name: area.name, foodCount: foods.filter { $0.areaId == area.id }.count)
            },
            foods: foods,
            foodCount: Set(active.map(\.productId)).count,
            sample: sample
        )
    }

    /// The rows in a sort order. Rows that are equal keep their order. A row with no expiry date is last in both
    /// directions of `SortKey.expiry`.
    ///
    /// - Parameter categoryLabel: The words of a category on the screen. The category order follows them. The
    ///   default is the key of the category, as on Android.
    public static func sort(
        _ foods: [FoodRow],
        key: SortKey,
        ascending: Bool,
        categoryLabel: (CVKEFridgeCore.Category) -> String = { $0.rawValue }
    ) -> [FoodRow] {
        /// The order of two rows: below 0 when the first comes first, 0 when they are equal.
        func compare(_ first: FoodRow, _ second: FoodRow) -> Int {
            func directed(_ result: Int) -> Int {
                ascending ? result : -result
            }
            func of<T: Comparable>(_ a: T, _ b: T) -> Int {
                a < b ? -1 : (a > b ? 1 : 0)
            }
            switch key {
            case .name:
                return directed(Names.order(first.name, second.name).rawValue)
            case .category:
                return directed(Names.order(categoryLabel(first.category), categoryLabel(second.category)).rawValue)
            case .quantity:
                return directed(of(first.quantity, second.quantity))
            case .dateAdded:
                return directed(of(first.dateAdded, second.dateAdded))
            case .expiry:
                switch (first.expiry?.date, second.expiry?.date) {
                case (nil, nil):
                    return 0
                case (nil, _):
                    return 1
                case (_, nil):
                    return -1
                case (let a?, let b?):
                    return directed(of(a, b))
                }
            }
        }
        return foods.enumerated()
            .sorted(by: { first, second in
                let result = compare(first.element, second.element)
                return result != 0 ? result < 0 : first.offset < second.offset
            })
            .map(\.element)
    }

    /// The order of the storage areas: Fridge, Freezer, and then the others by name and identifier.
    private static func areaComesBefore(_ first: StorageArea, _ second: StorageArea) -> Bool {
        func rank(_ area: StorageArea) -> Int {
            switch area.id {
            case StorageArea.fridge.id:
                return 0
            case StorageArea.freezer.id:
                return 1
            default:
                return 2
            }
        }
        if rank(first) != rank(second) {
            return rank(first) < rank(second)
        }
        let names = Names.order(first.name, second.name)
        if names != .orderedSame {
            return names == .orderedAscending
        }
        return first.id.utf8.lexicographicallyPrecedes(second.id.utf8)
    }
}
