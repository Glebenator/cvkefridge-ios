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

    /// The action that saves the form, or nil when the name has a problem. The product keeps its food of the table
    /// of foods while the new name fits that food. If not, a name that only one food has gets that food. The other
    /// values of the product, for example its barcode and its storage text, stay.
    public func action(product: Product, products: [Product], foods: FoodTable) -> InventoryAction.SaveProduct? {
        if nameError(product: product, products: products) != nil {
            return nil
        }
        let cleaned = Names.clean(name)
        let kept = product.foodId.flatMap { foods.food(id: $0) }.flatMap { food in
            Names.same(product.name, cleaned) || FoodSuggestions.fits(food, name: cleaned) ? food : nil
        }
        let foodId = kept?.id ?? FoodSuggestions.onlyFoodNamed(cleaned, foods: foods)?.id
        return InventoryAction.SaveProduct(
            product: Product(
                id: product.id,
                name: cleaned,
                category: category,
                unit: unit,
                barcode: product.barcode,
                foodId: foodId,
                note: Notes.clean(note),
                storageText: product.storageText
            )
        )
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

    /// The problem of the quantity, or nil.
    public func quantityError() -> QuantityProblem? {
        QuantityText.parse(quantity).problem
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
    public func action(
        batch: Batch,
        product: Product,
        areas: [StorageArea],
        foods: FoodTable
    ) -> InventoryAction.EditBatch? {
        guard let typed = QuantityText.parse(quantity).thousandths,
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
