import Foundation

// The forms that edit a product and a batch.
// The Android file `app/src/main/java/com/cvke/fridge/inventory/EditForms.kt` in cvkefridge-android has the same
// behaviour.

/// What the person typed and selected in the form that edits a product.
public struct ProductForm: Hashable, Sendable {
    public var name: String
    public var category: CVKEFridgeCore.Category
    public var unit: MeasureUnit?
    /// The text of the note field. An empty text or only spaces saves no note.
    public var note: String
    /// True after the person selected "Save" one time. The form then shows the problem of the name.
    public var checked: Bool

    public init(name: String, category: CVKEFridgeCore.Category, unit: MeasureUnit?, note: String = "", checked: Bool = false) {
        self.name = name
        self.category = category
        self.unit = unit
        self.note = note
        self.checked = checked
    }

    /// The form that shows the product as it is.
    public static func of(_ product: Product) -> ProductForm {
        ProductForm(name: product.name, category: product.category, unit: product.unit, note: product.note ?? "")
    }

    /// What a save of the form does to the quantities of the active batches of the product (see `UnitConversion`).
    /// With `.keepsNumbers`, ask the person before the save: 500 g becomes 500 of the new unit. The result is
    /// `.unchanged` when the unit stays or the product has no active batch.
    public func unitChange(product: Product, inventory: Inventory) -> UnitChange {
        guard inventory.activeBatches.contains(where: { $0.productId == product.id }) else {
            return .unchanged
        }
        return UnitConversion.change(from: product.unit, to: unit)
    }

    /// The problem of the name. Two products cannot have the same name, because the add form finds a product by its
    /// name.
    public func nameError(product: Product, products: [Product]) -> NameError? {
        let cleaned = Names.clean(name)
        if cleaned.isEmpty {
            return .empty
        }
        if cleaned.count > Names.maxFoodLength {
            return .tooLong
        }
        if products.contains(where: { $0.id != product.id && Names.same($0.name, cleaned) }) {
            return .inUse
        }
        return nil
    }

    /// The action that saves the form, or nil when the name has a problem. The other values of the product, for
    /// example its barcode and its storage text, stay.
    ///
    /// The food of the table of foods follows the name, with the rule of the add form (`AddFoodForm.withName`):
    /// - A name that did not change keeps the food of the product, also when the table of foods does not have it.
    /// - A new name keeps the food while the full name is the name or an alias of the food (`AddFoodForm.isNamed`).
    /// - If not, a name that only one food has as its name or alias gets that food.
    /// - If not, the food stays only when the full name is one of its keywords, so "Cheddar" keeps the hard cheese.
    /// - Each other name has no food.
    ///
    /// The Android app keeps the food while one word of the new name fits it (`FoodSuggestions.fits`), so a change of
    /// "Chicken" to "Chicken soup" keeps the estimate of raw chicken. It also removes the food of a product with no
    /// change of the name, when the table of foods cannot be read.
    public func action(product: Product, products: [Product], foods: FoodTable) -> InventoryAction.SaveProduct? {
        if nameError(product: product, products: products) != nil {
            return nil
        }
        let cleaned = Names.clean(name)
        return InventoryAction.SaveProduct(
            product: Product(
                id: product.id,
                name: cleaned,
                category: category,
                unit: unit,
                barcode: product.barcode,
                foodId: ProductForm.foodId(of: product, renamed: cleaned, foods: foods),
                note: Notes.clean(note),
                storageText: product.storageText
            )
        )
    }

    /// The food of the table of foods for the `product` with the new `name`. See `action(product:products:foods:)`.
    private static func foodId(of product: Product, renamed name: String, foods: FoodTable) -> String? {
        if Names.same(product.name, name) {
            return product.foodId
        }
        let current = product.foodId.flatMap { foods.food(id: $0) }
        if let current, AddFoodForm.isNamed(current, name) {
            return current.id
        }
        if let only = FoodSuggestions.onlyFoodNamed(name, foods: foods) {
            return only.id
        }
        if let current, current.keywords.contains(where: { Names.same($0, name) }) {
            return current.id
        }
        return nil
    }
}

/// What the person typed and selected in the form that edits a batch.
public struct BatchForm: Hashable, Sendable {
    /// The text of the quantity field.
    public var quantity: String
    public var storageAreaId: String
    public var dateAdded: CalendarDate
    public var expiry: ExpiryInput
    /// True after the person selected "Save" one time. The form then shows the problem of each field.
    public var checked: Bool

    public init(
        quantity: String,
        storageAreaId: String,
        dateAdded: CalendarDate,
        expiry: ExpiryInput,
        checked: Bool = false
    ) {
        self.quantity = quantity
        self.storageAreaId = storageAreaId
        self.dateAdded = dateAdded
        self.expiry = expiry
        self.checked = checked
    }

    /// The form that shows the batch as it is.
    ///
    /// - Parameter decimalSeparator: The decimal sign of the locale, for the quantity text.
    public static func of(_ batch: Batch, decimalSeparator: String) -> BatchForm {
        BatchForm(
            quantity: QuantityText.format(batch.quantity, decimalSeparator: decimalSeparator),
            storageAreaId: batch.storageAreaId,
            dateAdded: batch.dateAdded,
            expiry: ExpiryInput.of(batch.expiry)
        )
    }

    /// The form that shows the batch as it is, with the quantity in the number format of the `locale`
    /// (`QuantityText.format(_:locale:)`).
    public static func of(_ batch: Batch, locale: Locale) -> BatchForm {
        BatchForm(
            quantity: QuantityText.format(batch.quantity, locale: locale),
            storageAreaId: batch.storageAreaId,
            dateAdded: batch.dateAdded,
            expiry: ExpiryInput.of(batch.expiry)
        )
    }

    /// The problem of the quantity, or nil.
    ///
    /// - Parameter locale: The locale of the quantity text (`QuantityText.parse(_:locale:)`). Nil reads it as Android
    ///   does (`QuantityText.parse(_:)`).
    public func quantityError(locale: Locale? = nil) -> QuantityProblem? {
        QuantityText.parse(quantity, optionalLocale: locale).problem
    }

    /// The estimated date that the form can use. A change of the storage area or of the date added gives a new
    /// estimate (see `ExpiryChoice.suggestionForEdit`).
    public func suggested(batch: Batch, product: Product, areas: [StorageArea], foods: FoodTable) -> ExpiryDate? {
        let kind = areas.first(where: { $0.id == storageAreaId })?.kind
        var estimate: ExpiryDate? = nil
        if let kind, let foodId = product.foodId {
            estimate = foods.estimate(foodId: foodId, kind: kind, dateAdded: dateAdded)
        }
        return ExpiryChoice.suggestionForEdit(
            original: batch,
            storageAreaId: storageAreaId,
            dateAdded: dateAdded,
            estimate: estimate
        )
    }

    /// The action that saves the form, or nil when a field has a problem.
    ///
    /// - Parameter locale: The locale of the quantity text, as in `quantityError(locale:)`.
    public func action(
        batch: Batch,
        product: Product,
        areas: [StorageArea],
        foods: FoodTable,
        locale: Locale? = nil
    ) -> InventoryAction.EditBatch? {
        guard let typed = QuantityText.parse(quantity, optionalLocale: locale).thousandths,
              areas.contains(where: { $0.id == storageAreaId })
        else {
            return nil
        }
        return InventoryAction.EditBatch(
            batchId: batch.id,
            quantity: typed,
            storageAreaId: storageAreaId,
            dateAdded: dateAdded,
            expiry: ExpiryChoice.expiry(
                expiry,
                suggested: suggested(batch: batch, product: product, areas: areas, foods: foods)
            )
        )
    }
}
