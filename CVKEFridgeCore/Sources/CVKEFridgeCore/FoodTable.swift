import Foundation

// The table of foods and the expiry estimate. Rule 4 of `spec/rules.md`.
// The Android file `core/src/main/kotlin/com/cvke/fridge/core/FoodTable.kt` in cvkefridge-android has the same
// behaviour.

/// A food in the table of foods. `days` has the number of days that the food can be kept in each storage kind.
/// A storage kind can be absent.
public struct Food: Hashable, Sendable {
    public let id: String
    public let name: String
    public let subtitle: String?
    public let category: Category
    public let keywords: [String]
    public let days: [StorageKind: Int]

    public init(
        id: String,
        name: String,
        subtitle: String?,
        category: Category,
        keywords: [String],
        days: [StorageKind: Int]
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.category = category
        self.keywords = keywords
        self.days = days
    }
}

/// The table of foods, in the format of `spec/foods.json`.
public struct FoodTable: Equatable, Sendable {
    public let foods: [Food]

    public init(foods: [Food]) {
        self.foods = foods
    }

    /// The food with this identifier, or nil. If the identifier is in the table two times, it is the first food.
    public func food(id: String) -> Food? {
        foods.first(where: { $0.id == id })
    }

    /// The estimated expiry date: the date added plus the days of the food for the storage kind. Nil if the food is
    /// not in the table, if it has no days for that kind, or if the date is not in the years 1 to 9999.
    /// The category of the food has no effect.
    public func estimate(foodId: String, kind: StorageKind, dateAdded: CalendarDate) -> ExpiryDate? {
        guard let days = food(id: foodId)?.days[kind], let date = dateAdded.plusDays(days) else {
            return nil
        }
        return ExpiryDate(date: date, source: .estimated)
    }

    /// The table in a JSON text in the format of `spec/foods.json`: an object with a `foods` list. Other keys of the
    /// object have no effect. `subtitle` and `keywords` can be absent. It throws when the text has a different
    /// format, a category that is not known, or a `days` key that is not a storage kind.
    public static func decode(_ text: String) throws -> FoodTable {
        let file = try JSONDecoder().decode(FoodFile.self, from: Data(text.utf8))
        var foods: [Food] = []
        for line in file.foods {
            guard let category = Category(rawValue: line.category) else {
                throw JSONFormatError("The food \(line.id) has an unknown category: \(line.category)")
            }
            var days: [StorageKind: Int] = [:]
            for (key, count) in line.days {
                guard let kind = StorageKind(rawValue: key) else {
                    throw JSONFormatError("The food \(line.id) has an unknown storage kind: \(key)")
                }
                days[kind] = count
            }
            foods.append(
                Food(
                    id: line.id,
                    name: line.name,
                    subtitle: line.subtitle,
                    category: category,
                    keywords: line.keywords ?? [],
                    days: days
                )
            )
        }
        return FoodTable(foods: foods)
    }
}

/// The JSON shape of `spec/foods.json`.
private struct FoodFile: Decodable {
    let foods: [FoodLine]
}

/// The JSON shape of one food.
private struct FoodLine: Decodable {
    let id: String
    let name: String
    let subtitle: String?
    let category: String
    let keywords: [String]?
    let days: [String: Int]
}
