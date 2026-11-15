import Foundation

// A product, its category, and its unit. Rule 1 of `spec/rules.md`.
// The Android file `core/src/main/kotlin/com/cvke/fridge/core/Product.kt` in cvkefridge-android has the same types.

/// The category of a product.
public enum Category: String, CaseIterable, Sendable {
    case produce
    case dairy
    case meat
    case condiment
    case beverage
    case bakery
    case leftovers
    case other
}

/// The unit of a product. The glossary term is "unit". The code name is `MeasureUnit`, because Foundation has a type
/// `Unit`.
public enum MeasureUnit: String, CaseIterable, Sendable {
    case pcs
    case g
    case kg
    case ml
    case l
    case pack
    case bottle
    case slice
    case cup
}

/// A product. All batches of a product have its unit. A product can have no unit, no barcode, and no food.
public struct Product: Hashable, Sendable {
    public let id: String
    public let name: String
    public let category: Category
    public let unit: MeasureUnit?
    public let barcode: String?
    /// The identifier of a food in the table of foods.
    public let foodId: String?
    /// The text that the person wrote about the product. The core keeps it as it is.
    public let note: String?
    /// The text on the package about how to keep the product. It comes from the product lookup. The core keeps it as
    /// it is.
    public let storageText: String?

    public init(
        id: String,
        name: String,
        category: Category,
        unit: MeasureUnit?,
        barcode: String?,
        foodId: String?,
        note: String? = nil,
        storageText: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.unit = unit
        self.barcode = barcode
        self.foodId = foodId
        self.note = note
        self.storageText = storageText
    }
}
