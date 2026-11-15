import Foundation

// The table of foods and the expiry estimate. Rule 4 of `spec/rules.md`.
// The Android file `core/src/main/kotlin/com/cvke/fridge/core/FoodTable.kt` in cvkefridge-android has the same
// behaviour.

/// A food in the table of foods. `days` has the number of days that the food can be kept in each storage kind.
/// A storage kind can be absent. `usualKind` is the storage kind where people usually keep the food when they bring it
/// home, or nil. The food can have no days for it. It gives no estimate. `common` is true for a food that people add
/// often. `aliases` has other names for the food, in lowercase. They give no estimate. `tips` has, for a storage kind,
/// a short text of the source about how to keep the food in that kind. The food can have no days for the kind. The
/// tips give no estimate.
public struct Food: Hashable, Sendable {
    public let id: String
    public let name: String
    public let subtitle: String?
    public let category: Category
    public let keywords: [String]
    public let days: [StorageKind: Int]
    public let usualKind: StorageKind?
    public let common: Bool
    public let aliases: [String]
    public let tips: [StorageKind: String]

    public init(
        id: String,
        name: String,
        subtitle: String?,
        category: Category,
        keywords: [String],
        days: [StorageKind: Int],
        usualKind: StorageKind? = nil,
        common: Bool = false,
        aliases: [String] = [],
        tips: [StorageKind: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.category = category
        self.keywords = keywords
        self.days = days
        self.usualKind = usualKind
        self.common = common
        self.aliases = aliases
        self.tips = tips
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
    /// object have no effect. `subtitle`, `keywords`, `usualKind`, `common`, `aliases`, and `tips` can be absent. It
    /// throws when the text has a different format, a category that is not known, or a `days` key, a `tips` key, or a
    /// `usualKind` that is not a storage kind.
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
            var usualKind: StorageKind? = nil
            if let key = line.usualKind {
                guard let kind = StorageKind(rawValue: key) else {
                    throw JSONFormatError("The food \(line.id) has an unknown usual storage kind: \(key)")
                }
                usualKind = kind
            }
            var tips: [StorageKind: String] = [:]
            for (key, tip) in line.tips ?? [:] {
                guard let kind = StorageKind(rawValue: key) else {
                    throw JSONFormatError("The food \(line.id) has a tip for an unknown storage kind: \(key)")
                }
                tips[kind] = tip
            }
            foods.append(
                Food(
                    id: line.id,
                    name: line.name,
                    subtitle: line.subtitle,
                    category: category,
                    keywords: line.keywords ?? [],
                    days: days,
                    usualKind: usualKind,
                    common: line.common ?? false,
                    aliases: line.aliases ?? [],
                    tips: tips
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
    let usualKind: String?
    let common: Bool?
    let aliases: [String]?
    let tips: [String: String]?
}
