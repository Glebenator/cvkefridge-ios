import Foundation

// The form that adds food.
// The Android file `app/src/main/java/com/cvke/fridge/inventory/AddFoodForm.kt` in cvkefridge-android has the same
// behaviour. The Android form takes a `Scanned` value of the lookup. This file takes its values one by one
// (`AddFoodForm.scanned(barcode:...)`), so that it does not need the lookup.

/// Why a name in a form is not good.
public enum NameError: String, CaseIterable, Sendable {
    case empty
    case tooLong
    case inUse
}

/// An estimated expiry date and the food of the table of foods that gives it.
public struct FoodEstimate: Hashable, Sendable {
    public let food: Food
    public let expiry: ExpiryDate

    public init(food: Food, expiry: ExpiryDate) {
        self.food = food
        self.expiry = expiry
    }
}

/// What the person typed and selected in the form that adds food. The form is one value, and each change of a field
/// gives a new value.
public struct AddFoodForm: Hashable, Sendable {
    /// The start text of the quantity field.
    public static let defaultQuantity = "1"

    /// The text of the name field.
    public var name: String
    /// The food of the table of foods that gives the expiry estimate, or nil.
    public var foodId: String?
    public var category: CVKEFridgeCore.Category
    /// True after the person selected the category. A food then does not change it.
    public var categoryChosen: Bool
    /// The text of the quantity field.
    public var quantity: String
    public var unit: MeasureUnit?
    public var storageAreaId: String
    /// True when a food does not change the storage area: the person selected it, or it is the storage area of the
    /// newest batch of the product.
    public var areaKept: Bool
    /// The storage area of the form when the scan has no storage hint and the food has no usual storage kind.
    public var startAreaId: String
    /// The storage kind of the storage hint of the scan, or nil. It comes before the usual storage kind of the food,
    /// because it is about the scanned product.
    public var hintKind: StorageKind?
    public var expiry: ExpiryInput
    /// True after the person selected "Save" one time. The form then shows the problem of each field.
    public var checked: Bool
    /// The barcode of a scan, or nil. The form shows it but does not let the person change it.
    public var barcode: String?
    /// The text of the note field. A product that the person selected from the suggestions, or with "Add again", puts
    /// its note in the field.
    public var note: String
    /// True after the person typed in the note field. The form then does not change the note.
    public var noteEdited: Bool
    /// The storage text of the scan, or nil. The person cannot change it. The product gets it.
    public var storageText: String?

    /// The form with these values. `startAreaId` is `storageAreaId` when it is nil.
    public init(
        name: String = "",
        foodId: String? = nil,
        category: CVKEFridgeCore.Category = .other,
        categoryChosen: Bool = false,
        quantity: String = AddFoodForm.defaultQuantity,
        unit: MeasureUnit? = .pcs,
        storageAreaId: String = StorageArea.fridge.id,
        areaKept: Bool = false,
        startAreaId: String? = nil,
        hintKind: StorageKind? = nil,
        expiry: ExpiryInput = .suggested,
        checked: Bool = false,
        barcode: String? = nil,
        note: String = "",
        noteEdited: Bool = false,
        storageText: String? = nil
    ) {
        self.name = name
        self.foodId = foodId
        self.category = category
        self.categoryChosen = categoryChosen
        self.quantity = quantity
        self.unit = unit
        self.storageAreaId = storageAreaId
        self.areaKept = areaKept
        self.startAreaId = startAreaId ?? storageAreaId
        self.hintKind = hintKind
        self.expiry = expiry
        self.checked = checked
        self.barcode = barcode
        self.note = note
        self.noteEdited = noteEdited
        self.storageText = storageText
    }

    /// The product in the inventory with this name. The form then adds a batch to it, and makes no second product.
    public func product(_ products: [Product]) -> Product? {
        let cleaned = Names.clean(name)
        if cleaned.isEmpty {
            return nil
        }
        return products.first(where: { Names.same($0.name, cleaned) })
    }

    /// The food that gives the expiry estimate: the food of the product in the inventory, or the food of the form.
    public func food(products: [Product], foods: FoodTable) -> Food? {
        let id = product(products)?.foodId ?? foodId
        return id.flatMap { foods.food(id: $0) }
    }

    /// The form after the person typed in the name field. The food of the form stays while the full name is the name
    /// or an alias of the food (`isNamed`). For a different name, the form finds the food again: the food that only
    /// it has as its name or alias. With no such food, the food stays only when the full name is one of its keywords,
    /// so "Cheddar" keeps the hard cheese. A food gives its category, if the person did not select one. A change of the
    /// food gives the storage area of the food (`withUsualArea`).
    ///
    /// The Android app keeps the food while one word of the name fits it, so "Chicken soup" keeps the estimate and the
    /// storage area of raw chicken after the person selected "Chicken". This form does not.
    public func withName(_ text: String, foods: FoodTable, areas: [StorageArea]) -> AddFoodForm {
        let current = foodId.flatMap { foods.food(id: $0) }
        let food: Food?
        if let current, AddFoodForm.isNamed(current, text) {
            food = current
        } else if let only = FoodSuggestions.onlyFoodNamed(text, foods: foods) {
            food = only
        } else {
            food = current.flatMap { current in
                current.keywords.contains(where: { Names.same($0, text) }) ? current : nil
            }
        }
        var next = self
        next.name = text
        next.foodId = food?.id
        if !categoryChosen, let food {
            next.category = food.category
        }
        // A note that came from a selected product goes away with its name.
        if !noteEdited {
            next.note = ""
        }
        return next.afterFood(of: self, foods: foods, areas: areas)
    }

    /// The form after the person selected a suggestion. A change of the food gives the storage area of the food.
    public func withSuggestion(_ suggestion: Suggestion, foods: FoodTable, areas: [StorageArea]) -> AddFoodForm {
        var next = self
        switch suggestion {
        case .ofProduct(let product):
            next.name = product.name
            next.foodId = product.foodId
            if !noteEdited {
                next.note = product.note ?? ""
            }
        case .ofFood(let food, _):
            next.name = food.name
            next.foodId = food.id
            if !categoryChosen {
                next.category = food.category
            }
        }
        return next.afterFood(of: self, foods: foods, areas: areas)
    }

    private func afterFood(of before: AddFoodForm, foods: FoodTable, areas: [StorageArea]) -> AddFoodForm {
        foodId == before.foodId ? self : withUsualArea(foods: foods, areas: areas)
    }

    /// The form with the storage area for its scan and its food: an area of the storage kind of the storage hint, or
    /// of the usual storage kind of the food when the scan has no hint (`areaOfKind`). With no such area, or no kind,
    /// it is the start area. When `areaKept` is true, the form does not change.
    public func withUsualArea(foods: FoodTable, areas: [StorageArea]) -> AddFoodForm {
        if areaKept {
            return self
        }
        var next = self
        let kind = hintKind ?? foodId.flatMap { foods.food(id: $0) }?.usualKind
        next.storageAreaId = kind.flatMap { AddFoodForm.areaOfKind($0, startAreaId: startAreaId, areas: areas) }
            ?? startAreaId
        return next
    }

    /// The storage tips for the form: the storage text of the scan, or of the product in the inventory with this
    /// name, and the general advice for the food of the form. It is nil when there is nothing to show.
    public func storageAdvice(products: [Product], foods: FoodTable) -> StorageAdvice? {
        StorageAdvices.of(
            storageText: storageText ?? product(products)?.storageText,
            food: food(products: products, foods: foods)
        )
    }

    /// The form after the person typed in the note field.
    public func withNote(_ text: String) -> AddFoodForm {
        var next = self
        next.note = text
        next.noteEdited = true
        return next
    }

    /// The form after the person selected a storage area. A food then does not change it.
    public func withArea(_ id: String) -> AddFoodForm {
        var next = self
        next.storageAreaId = id
        next.areaKept = true
        return next
    }

    /// The suggestions for the name. A name that is complete has none: the name of a product, or the name or an alias
    /// of the food of the form.
    public func suggestions(products: [Product], foods: FoodTable) -> [Suggestion] {
        if product(products) != nil {
            return []
        }
        if let food = foodId.flatMap({ foods.food(id: $0) }), AddFoodForm.isNamed(food, name) {
            return []
        }
        return FoodSuggestions.find(name, products: products, foods: foods)
    }

    /// The estimated date for the food in the storage area, for a batch that is added `today`.
    public func estimate(
        products: [Product],
        areas: [StorageArea],
        foods: FoodTable,
        today: CalendarDate
    ) -> ExpiryDate? {
        guard let food = food(products: products, foods: foods),
              let area = areas.first(where: { $0.id == storageAreaId })
        else {
            return nil
        }
        return foods.estimate(foodId: food.id, kind: area.kind, dateAdded: today)
    }

    /// The estimated date and the food that gives it, so that the form can show the food of the estimate. Nil when
    /// the form has no estimate.
    public func estimated(
        products: [Product],
        areas: [StorageArea],
        foods: FoodTable,
        today: CalendarDate
    ) -> FoodEstimate? {
        guard let food = food(products: products, foods: foods),
              let expiry = estimate(products: products, areas: areas, foods: foods, today: today)
        else {
            return nil
        }
        return FoodEstimate(food: food, expiry: expiry)
    }

    /// True when the full `name` is the name or an alias of the `food`. Case and extra spaces have no effect.
    public static func isNamed(_ food: Food, _ name: String) -> Bool {
        Names.same(food.name, name) || food.aliases.contains(where: { Names.same($0, name) })
    }

    /// The problem of the name, or nil.
    public func nameError() -> NameError? {
        let cleaned = Names.clean(name)
        if cleaned.isEmpty {
            return .empty
        }
        if cleaned.count > Names.maxFoodLength {
            return .tooLong
        }
        return nil
    }

    /// The problem of the quantity, or nil.
    ///
    /// - Parameter locale: The locale of the quantity text (`QuantityText.parse(_:locale:)`). Nil reads it as Android
    ///   does (`QuantityText.parse(_:)`).
    public func quantityError(locale: Locale? = nil) -> QuantityProblem? {
        QuantityText.parse(quantity, optionalLocale: locale).problem
    }

    /// The action that saves the form, or nil when a field has a problem. The note of a new product is the cleaned
    /// text of the note field (`Notes.clean`). For a product in the inventory, a note replaces its note, and an empty
    /// note field keeps its note: the add form does not remove a note.
    ///
    /// - Parameter locale: The locale of the quantity text, as in `quantityError(locale:)`.
    public func action(
        products: [Product],
        areas: [StorageArea],
        foods: FoodTable,
        today: CalendarDate,
        locale: Locale? = nil
    ) -> InventoryAction.AddFood? {
        guard let quantity = QuantityText.parse(quantity, optionalLocale: locale).thousandths, nameError() == nil,
              areas.contains(where: { $0.id == storageAreaId })
        else {
            return nil
        }
        let existing = product(products)
        return InventoryAction.AddFood(
            productId: existing?.id,
            name: existing?.name ?? Names.clean(name),
            category: existing?.category ?? category,
            unit: existing != nil ? existing?.unit : unit,
            foodId: existing != nil ? existing?.foodId : foodId,
            quantity: quantity,
            storageAreaId: storageAreaId,
            expiry: ExpiryChoice.expiry(
                expiry,
                suggested: estimate(products: products, areas: areas, foods: foods, today: today)
            ),
            barcode: barcode,
            note: Notes.clean(note),
            storageText: storageText
        )
    }

    /// The form for a product that the person had before: the storage area of its newest batch and its usual
    /// quantity, when they are known, and the estimated date. A date of an earlier batch is never used.
    ///
    /// - Parameter decimalSeparator: The decimal sign of the locale, for the quantity text.
    public func again(_ values: AgainValues, decimalSeparator: String) -> AddFoodForm {
        var next = self
        next.storageAreaId = values.storageAreaId ?? storageAreaId
        next.areaKept = areaKept || values.storageAreaId != nil
        if let quantity = values.quantity {
            next.quantity = QuantityText.format(quantity, decimalSeparator: decimalSeparator)
        }
        next.expiry = .suggested
        return next
    }

    /// The empty form for the next food. It keeps the storage area.
    public func next() -> AddFoodForm {
        AddFoodForm(storageAreaId: storageAreaId)
    }

    /// The form after a scan, with the values of the scan. A value that the scan does not have keeps the start value
    /// of the form. The quantity of a package needs its unit. Everything stays editable, and the expiry date starts
    /// as the estimated date.
    ///
    /// The values are the values of a `Scanned` of the lookup. A key that is not known has the start value.
    ///
    /// - Parameters:
    ///   - categoryKey: The key of the category, or nil.
    ///   - quantity: The quantity of the package in thousandths, or nil.
    ///   - unitKey: The key of the unit of `quantity`, or nil.
    ///   - storageKindKey: The key of the storage kind of the storage hint of the product, or nil.
    ///   - decimalSeparator: The decimal sign of the locale, for the quantity text.
    public static func scanned(
        barcode: String,
        name: String = "",
        categoryKey: String? = nil,
        foodId: String? = nil,
        quantity: Int? = nil,
        unitKey: String? = nil,
        storageKindKey: String? = nil,
        storageText: String? = nil,
        storageAreaId: String,
        decimalSeparator: String
    ) -> AddFoodForm {
        let unit = unitKey.flatMap(MeasureUnit.init(rawValue:))
        let pack = unit != nil ? quantity : nil
        return AddFoodForm(
            name: name,
            foodId: foodId,
            category: categoryKey.flatMap(CVKEFridgeCore.Category.init(rawValue:)) ?? .other,
            quantity: pack.map { QuantityText.format($0, decimalSeparator: decimalSeparator) } ?? defaultQuantity,
            unit: pack != nil ? unit : .pcs,
            storageAreaId: storageAreaId,
            hintKind: storageKindKey.flatMap(StorageKind.init(rawValue:)),
            barcode: barcode,
            storageText: storageText
        )
    }

    /// The form that adds a batch to a product that the person had before ("Add again"). `startArea` is the storage
    /// area when the product has no known storage area.
    public static func again(
        product: Product,
        values: AgainValues,
        startArea: String,
        decimalSeparator: String
    ) -> AddFoodForm {
        AddFoodForm(
            name: product.name,
            foodId: product.foodId,
            category: product.category,
            unit: product.unit,
            storageAreaId: startArea,
            note: product.note ?? ""
        ).again(values, decimalSeparator: decimalSeparator)
    }

    /// The storage area of a new form: the storage area of the last batch that the person added, then the storage
    /// area of the tab that was open, and then the Fridge. A storage area that is not there has no effect.
    public static func startArea(lastUsedId: String?, openTabId: String?, areas: [StorageArea]) -> String {
        [lastUsedId, openTabId].compactMap { $0 }.first(where: { id in areas.contains(where: { $0.id == id }) })
            ?? StorageArea.fridge.id
    }

    /// The storage area for a food of the usual storage kind `kind`: the start area if it has that kind, then the
    /// fixed area of that kind, and then the first area of that kind. It is nil when no area has that kind.
    public static func areaOfKind(_ kind: StorageKind, startAreaId: String, areas: [StorageArea]) -> String? {
        let ofKind = areas.filter { $0.kind == kind }
        return (ofKind.first(where: { $0.id == startAreaId }) ?? ofKind.first(where: { $0.fixed }) ?? ofKind.first)?.id
    }
}
