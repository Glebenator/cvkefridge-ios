import CVKEFridgeFeatures
import Foundation

// The names of the values that the person selects: categories, units, storage kinds, storage areas, sort orders, and
// the filters of History.

extension CVKEFridgeCore.Category {
    /// The name of the category: "Produce", "Dairy".
    var label: String {
        switch self {
        case .produce: String(localized: "Produce")
        case .dairy: String(localized: "Dairy")
        case .meat: String(localized: "Meat")
        case .condiment: String(localized: "Condiment")
        case .beverage: String(localized: "Beverage")
        case .bakery: String(localized: "Bakery")
        case .leftovers: String(localized: "Leftovers")
        case .other: String(localized: "Other")
        }
    }
}

extension StorageKind {
    /// The name of the storage kind: "Pantry", "Fridge", "Freezer".
    var label: String {
        switch self {
        case .pantry: String(localized: "Pantry")
        case .fridge: String(localized: "Fridge")
        case .freezer: String(localized: "Freezer")
        }
    }
}

extension SortKey {
    /// The name of the sort order: "Name", "Expiry".
    var label: String {
        switch self {
        case .name: String(localized: "Name")
        case .expiry: String(localized: "Expiry")
        case .dateAdded: String(localized: "Date added")
        case .quantity: String(localized: "Quantity")
        case .category: String(localized: "Category")
        }
    }
}

extension Outcome {
    /// What happened to the food: "Used" or "Thrown away".
    var label: String {
        switch self {
        case .used: String(localized: "Used")
        case .thrownAway: String(localized: "Thrown away")
        }
    }
}

extension HistoryFilter {
    /// The name of the filter of History: "All", "Used", "Thrown away".
    var label: String {
        switch self {
        case .all: String(localized: "All")
        case .used: String(localized: "Used")
        case .thrownAway: String(localized: "Thrown away")
        }
    }
}

extension HistoryPeriod {
    /// The name of the period of the summary: "This month", "Last month", "All time".
    var label: String {
        switch self {
        case .thisMonth: String(localized: "This month")
        case .lastMonth: String(localized: "Last month")
        case .all: String(localized: "All time")
        }
    }
}

extension Wording {
    /// The name of a unit in a list of units: "pcs", "pack". Nil is "No unit".
    static func unitName(_ unit: MeasureUnit?) -> String {
        switch unit {
        case nil: String(localized: "No unit")
        case .pcs: String(localized: "pcs", comment: "The name of a unit in a list of units.")
        case .g: String(localized: "g", comment: "The name of a unit in a list of units.")
        case .kg: String(localized: "kg", comment: "The name of a unit in a list of units.")
        case .ml: String(localized: "ml", comment: "The name of a unit in a list of units.")
        case .l: String(localized: "l", comment: "The name of a unit in a list of units.")
        case .pack: String(localized: "pack", comment: "The name of a unit in a list of units.")
        case .bottle: String(localized: "bottle", comment: "The name of a unit in a list of units.")
        case .slice: String(localized: "slice", comment: "The name of a unit in a list of units.")
        case .cup: String(localized: "cup", comment: "The name of a unit in a list of units.")
        }
    }

    /// The name of a storage area on a screen. The two fixed storage areas have their names in the language of the
    /// person. The name of each other storage area is the text of the person. The search of My Fridge compares the
    /// search text with this name: give it to `InventoryContent.filtered` as `areaLabel`.
    ///
    /// - Parameters:
    ///   - id: The identifier of the storage area.
    ///   - name: The name of the storage area in the inventory.
    static func areaName(id: String, name: String) -> String {
        switch id {
        case StorageArea.fridge.id: StorageKind.fridge.label
        case StorageArea.freezer.id: StorageKind.freezer.label
        default: name
        }
    }

    /// The name of a storage area on a screen. See `areaName(id:name:)`.
    static func name(of area: StorageArea) -> String {
        areaName(id: area.id, name: area.name)
    }

    /// The name of the tab of all storage areas of My Fridge.
    static var allAreas: String {
        String(localized: "All", comment: "The tab of all storage areas.")
    }

    /// The header of a day of History: "Today", "Yesterday", or the date with the day of the week.
    static func day(_ name: DayName, date: CalendarDate) -> String {
        switch name {
        case .today: String(localized: "Today")
        case .yesterday: String(localized: "Yesterday")
        case .date: longDate(date)
        }
    }

    /// The words that the search of My Fridge compares with the search text, for a category. Give it to
    /// `InventoryContent.filtered` and `InventoryContent.sort`.
    static func categoryLabel(_ category: CVKEFridgeCore.Category) -> String {
        category.label
    }

    /// The words that the search of My Fridge compares with the search text, for a unit.
    static func unitLabel(_ unit: MeasureUnit) -> String {
        unitName(unit)
    }
}

extension StorageArea {
    /// The name of the storage area on a screen. See `Wording.areaName(id:name:)`.
    var displayName: String {
        Wording.name(of: self)
    }
}

extension AreaSummary {
    /// The name of the storage area on a screen. See `Wording.areaName(id:name:)`.
    var displayName: String {
        Wording.areaName(id: id, name: name)
    }
}

extension FoodRow {
    /// The name of the storage area of the row on a screen. See `Wording.areaName(id:name:)`.
    var areaDisplayName: String {
        Wording.areaName(id: areaId, name: areaName)
    }
}
