import Foundation

// What a scan gives the add form. The Android file `app/src/main/java/com/cvke/fridge/lookup/Scanned.kt` in
// cvkefridge-android has the same behaviour. Android keeps the keys of the category, the unit, and the storage kind
// as text for its back stack. Here they are the types of the core.

/// Where the values of a scan come from.
public enum ScanSource: String, Hashable, Sendable, CaseIterable {
    /// Open Food Facts had the product.
    case found
    /// Open Food Facts has no product with a name for the barcode.
    case notFound
    /// The lookup failed, and the person adds the food by hand. The barcode stays.
    case notLookedUp
    /// A product in the inventory has the barcode. The app did not use the network.
    case inInventory
}

/// What a scan gives the add form.
public struct Scanned: Hashable, Sendable {
    /// The barcode in the form of `Barcodes`.
    public let barcode: String
    public let source: ScanSource
    /// The name for the inventory, or empty.
    public let name: String
    /// The category, or nil for the start value of the form.
    public let category: CVKEFridgeCore.Category?
    /// The food of the table of foods that gives the expiry estimate, or nil.
    public let foodId: String?
    /// The quantity of the package in thousandths, or nil for the start value of the form.
    public let quantity: Int?
    /// The unit of `quantity`, or nil.
    public let unit: MeasureUnit?
    /// The storage kind of the storage hint of the product, or nil.
    public let storageKind: StorageKind?
    /// The storage text of the product in the form that the app saves, or nil.
    public let storageText: String?

    public init(
        barcode: String,
        source: ScanSource,
        name: String = "",
        category: CVKEFridgeCore.Category? = nil,
        foodId: String? = nil,
        quantity: Int? = nil,
        unit: MeasureUnit? = nil,
        storageKind: StorageKind? = nil,
        storageText: String? = nil
    ) {
        self.barcode = barcode
        self.source = source
        self.name = name
        self.category = category
        self.foodId = foodId
        self.quantity = quantity
        self.unit = unit
        self.storageKind = storageKind
        self.storageText = storageText
    }
}

/// Makes the values of the add form from a scan.
public enum ScannedFoods {
    /// The values for a product that Open Food Facts found: the name (`ProductNames`), the category of the tags
    /// (`ProductCategories`), the food that the name clearly names (`FoodMatch`), and the quantity of the package when
    /// it is reliable (`PackQuantity`). With no category from the tags, the category of the food, and then none. The
    /// storage kind is the storage hint of the storage text and the tags of the product (`StorageHints`).
    ///
    /// - Parameters:
    ///   - maxNameLength: The largest number of characters in the name of a food (`Names.MAX_FOOD_LENGTH` of
    ///     Android).
    ///   - cleanStorageText: Makes the storage text that the app saves (`StorageTexts.clean` of Android).
    public static func found(
        barcode: String,
        product: LookedUpProduct,
        foods: FoodTable,
        hints: StorageHints,
        maxNameLength: Int,
        cleanStorageText: (String?) -> String?
    ) -> Scanned {
        let tagCategory = ProductCategories.of(product.categories)
        let food = FoodMatch.find(product.name, category: tagCategory, foods: foods)
        let pack = product.quantity.flatMap(PackQuantity.parse)
        return Scanned(
            barcode: barcode,
            source: .found,
            name: ProductNames.of(product, maxLength: maxNameLength),
            category: tagCategory ?? food?.category,
            foodId: food?.id,
            quantity: pack?.quantity,
            unit: pack?.unit,
            storageKind: hints.of(storageText: product.storageText, tags: product.categories)?.kind,
            storageText: cleanStorageText(product.storageText)
        )
    }

    /// The product in the inventory with the barcode, or nil. A product with an ended batch is also in the inventory:
    /// the person can add a new batch to it. A barcode in storage that is not in the form of `Barcodes` is compared
    /// in that form.
    public static func productWithBarcode(_ products: [Product], barcode: String) -> Product? {
        products.first { product in
            guard let stored = product.barcode else {
                return false
            }
            return (Barcodes.normalize(stored) ?? stored) == barcode
        }
    }
}
