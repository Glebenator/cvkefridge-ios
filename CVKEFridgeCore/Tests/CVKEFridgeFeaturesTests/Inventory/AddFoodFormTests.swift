import Testing
@testable import CVKEFridgeFeatures

/// The form that adds food: the food of a name, the estimated date, and what the form saves. The same cases as the
/// Android AddFoodFormTest. The Android test makes a `Scanned` value. This test gives the same values to
/// `AddFoodForm.scanned`.
struct AddFoodFormTests {
    private let today = CalendarDate.parse("2026-11-12")!
    private let pantry = StorageArea(id: "pantry-1", name: "Pantry", kind: .pantry, fixed: false)
    private var areas: [StorageArea] { [StorageArea.fridge, StorageArea.freezer, pantry] }

    private let butter = Food(
        id: "f-butter",
        name: "Butter",
        subtitle: nil,
        category: .dairy,
        keywords: ["butter"],
        days: [.fridge: 30, .freezer: 180],
        usualKind: .fridge
    )
    private let hardCheese = Food(
        id: "f-hard",
        name: "Cheese",
        subtitle: "hard such as cheddar",
        category: .dairy,
        keywords: ["cheese", "cheddar"],
        days: [.fridge: 180]
    )
    private let softCheese = Food(
        id: "f-soft",
        name: "Cheese",
        subtitle: "soft such as brie",
        category: .dairy,
        keywords: ["cheese", "brie"],
        days: [.fridge: 7]
    )
    private let peanutButter = Food(
        id: "f-peanut",
        name: "Peanut butter",
        subtitle: nil,
        category: .condiment,
        keywords: ["peanut butter"],
        days: [.pantry: 180],
        usualKind: .pantry
    )
    private var foods: FoodTable { FoodTable(foods: [butter, hardCheese, softCheese, peanutButter]) }

    private let milk = Product(id: "p-milk", name: "Whole milk", category: .dairy, unit: .l, barcode: nil, foodId: nil)
    private var products: [Product] { [milk] }

    private func date(_ text: String) -> CalendarDate {
        CalendarDate.parse(text)!
    }

    private func estimated(_ text: String) -> ExpiryDate {
        ExpiryDate(date: date(text), source: .estimated)
    }

    private func changed<T>(_ value: T, _ change: (inout T) -> Void) -> T {
        var copy = value
        change(&copy)
        return copy
    }

    @Test func aNameOfOneFoodGetsThatFoodAndItsCategory() {
        let form = AddFoodForm().withName("butter", foods: foods, areas: areas)
        #expect(form.foodId == "f-butter")
        #expect(form.category == .dairy)
        // The date is the estimate for the Fridge. It is not today.
        #expect(form.estimate(products: products, areas: areas, foods: foods, today: today) == estimated("2026-12-12"))
    }

    @Test func aNameOfMoreThanOneFoodGetsAFoodOnlyFromASuggestion() {
        let typed = AddFoodForm().withName("Cheese", foods: foods, areas: areas)
        #expect(typed.foodId == nil)
        #expect(typed.estimate(products: products, areas: areas, foods: foods, today: today) == nil)
        let suggested = typed.suggestions(products: products, foods: foods).map { suggestion -> String in
            if case .ofFood(let food, _) = suggestion {
                return food.id
            }
            return "product"
        }
        #expect(suggested == ["f-hard", "f-soft"])

        let selected = typed.withSuggestion(.ofFood(softCheese, alias: nil), foods: foods, areas: areas)
        #expect(selected.name == "Cheese")
        #expect(selected.estimate(products: products, areas: areas, foods: foods, today: today) == estimated("2026-11-19"))
        // The name is complete, so the list of suggestions closes.
        #expect(selected.suggestions(products: products, foods: foods) == [])
    }

    @Test func theFoodStaysWhileTheNameFitsIt() {
        let selected = AddFoodForm().withSuggestion(.ofFood(hardCheese, alias: nil), foods: foods, areas: areas)
        #expect(selected.withName("Cheddar", foods: foods, areas: areas).foodId == "f-hard")
        #expect(selected.withName("Bread", foods: foods, areas: areas).foodId == nil)
        #expect(selected.withName("", foods: foods, areas: areas).foodId == nil)
    }

    // Correction of AddFoodForm.kt:70: after the person selected "Chicken", "Chicken soup" kept the estimate and the
    // storage area of raw chicken, because one word of the name fits the food.
    @Test func aLongerNameFindsItsFoodAgain() {
        let chicken = Food(
            id: "f-chicken",
            name: "Chicken",
            subtitle: "whole",
            category: .meat,
            keywords: ["chicken", "whole"],
            days: [.fridge: 1, .freezer: 360],
            usualKind: .freezer,
            aliases: ["whole chicken"]
        )
        let soup = Food(
            id: "f-soup",
            name: "Soup",
            subtitle: nil,
            category: .leftovers,
            keywords: ["soup"],
            days: [.fridge: 3],
            usualKind: .fridge,
            aliases: ["chicken soup"]
        )
        let table = FoodTable(foods: [chicken, soup, butter])
        let selected = AddFoodForm(storageAreaId: "pantry-1")
            .withSuggestion(.ofFood(chicken, alias: nil), foods: table, areas: areas)
        #expect(selected.foodId == "f-chicken")
        #expect(selected.storageAreaId == "freezer")

        // The name of the food, with other case and spaces, and an alias keep the food.
        #expect(selected.withName(" CHICKEN ", foods: table, areas: areas).foodId == "f-chicken")
        #expect(selected.withName("Whole chicken", foods: table, areas: areas).foodId == "f-chicken")
        // A name that is the name or an alias of one other food gets that food, with its storage area.
        let typed = selected.withName("Chicken soup", foods: table, areas: areas)
        #expect(typed.foodId == "f-soup")
        #expect(typed.storageAreaId == "fridge")
        #expect(typed.estimated(products: products, areas: areas, foods: table, today: today)
            == FoodEstimate(food: soup, expiry: estimated("2026-11-15")))
        // A name of no food has no food, no estimate, and the start area.
        let other = selected.withName("Chicken stew", foods: table, areas: areas)
        #expect(other.foodId == nil)
        #expect(other.storageAreaId == "pantry-1")
        #expect(other.estimated(products: products, areas: areas, foods: table, today: today) == nil)
        // The form shows the food of the estimate.
        #expect(selected.estimated(products: products, areas: areas, foods: table, today: today)?.food == chicken)
    }

    @Test func aCategoryThatThePersonSelectedStays() {
        let form = AddFoodForm(category: .leftovers, categoryChosen: true).withName("Butter", foods: foods, areas: areas)
        #expect(form.category == .leftovers)
    }

    @Test func aChangeOfTheStorageAreaGivesANewEstimateAndKeepsAPrintedDate() {
        let form = AddFoodForm().withName("Butter", foods: foods, areas: areas)
        let frozen = changed(form) { $0.storageAreaId = "freezer" }
        #expect(
            ExpiryChoice.expiry(
                frozen.expiry,
                suggested: frozen.estimate(products: products, areas: areas, foods: foods, today: today)
            ) == estimated("2027-05-11")
        )
        // The table has no days for butter in a pantry.
        #expect(
            changed(form) { $0.storageAreaId = "pantry-1" }
                .estimate(products: products, areas: areas, foods: foods, today: today) == nil
        )

        let printed = changed(form) {
            $0.expiry = .printed(date("2026-11-20"))
            $0.storageAreaId = "freezer"
        }
        #expect(
            printed.action(products: products, areas: areas, foods: foods, today: today)?.expiry
                == ExpiryDate(date: date("2026-11-20"), source: .printed)
        )
    }

    @Test func theNameOfAProductInTheInventoryAddsABatchToIt() throws {
        let form = AddFoodForm(category: .other, quantity: "1,5", unit: .pcs)
            .withName("  whole   MILK ", foods: foods, areas: areas)
        let action = try #require(form.action(products: products, areas: areas, foods: foods, today: today))
        #expect(action.productId == "p-milk")
        #expect(action.name == "Whole milk")
        #expect(action.unit == .l)
        #expect(action.category == .dairy)
        #expect(action.quantity == 1_500)
        #expect(form.suggestions(products: products, foods: foods) == [])
    }

    @Test func aNewFoodSavesTheCleanNameAndTheValuesOfTheForm() throws {
        let form = AddFoodForm(quantity: "250", unit: .g, storageAreaId: "pantry-1")
            .withName(" Peanut  butter ", foods: foods, areas: areas)
        let action = try #require(form.action(products: products, areas: areas, foods: foods, today: today))
        #expect(action.productId == nil)
        #expect(action.name == "Peanut butter")
        #expect(action.foodId == "f-peanut")
        #expect(action.category == .condiment)
        #expect(action.expiry == estimated("2027-05-11"))
        let none = changed(form) { $0.expiry = .noExpiryDate }
        #expect(none.action(products: products, areas: areas, foods: foods, today: today) != nil)
        #expect(none.action(products: products, areas: areas, foods: foods, today: today)?.expiry == nil)
    }

    @Test func theNoteOfASelectedProductIsInTheFieldUntilTheNameChanges() {
        let jam = Product(
            id: "p-jam",
            name: "Jam",
            category: .condiment,
            unit: nil,
            barcode: nil,
            foodId: nil,
            note: "For the cake"
        )
        let all = [milk, jam]
        let selected = AddFoodForm().withName("ja", foods: foods, areas: areas)
            .withSuggestion(.ofProduct(jam), foods: foods, areas: areas)
        #expect(selected.note == "For the cake")
        // Another name removes the note of the product. A note that the person typed stays.
        #expect(selected.withName("Jams", foods: foods, areas: areas).note == "")
        let typed = selected.withNote("Opened").withName("Jams", foods: foods, areas: areas)
        #expect(typed.note == "Opened")
        #expect(typed.withSuggestion(.ofProduct(jam), foods: foods, areas: areas).note == "Opened")
        // "Add again" also puts the note in the field.
        #expect(
            AddFoodForm.again(
                product: jam,
                values: AgainValues(storageAreaId: nil, quantity: nil),
                startArea: "fridge",
                decimalSeparator: "."
            ).note == "For the cake"
        )

        // The action has the cleaned note, or nil for an empty field.
        #expect(
            AddFoodForm(name: "Jam", note: " Opened \n").action(products: all, areas: areas, foods: foods, today: today)?
                .note == "Opened"
        )
        let empty = AddFoodForm(name: "Jam", note: "  ").action(products: all, areas: areas, foods: foods, today: today)
        #expect(empty != nil)
        #expect(empty?.note == nil)
    }

    @Test func aFormWithAProblemSavesNothing() {
        #expect(AddFoodForm(name: "  ").nameError() == .empty)
        #expect(AddFoodForm(name: String(repeating: "a", count: 81)).nameError() == .tooLong)
        #expect(AddFoodForm(name: String(repeating: "a", count: 80)).nameError() == nil)
        #expect(AddFoodForm(name: " ").action(products: products, areas: areas, foods: foods, today: today) == nil)
        #expect(
            AddFoodForm(name: "Rice", quantity: "0").action(products: products, areas: areas, foods: foods, today: today)
                == nil
        )
        #expect(AddFoodForm(name: "Rice", quantity: "0").quantityError() == .notPositive)
        #expect(
            AddFoodForm(name: "Rice", storageAreaId: "gone")
                .action(products: products, areas: areas, foods: foods, today: today) == nil
        )
    }

    @Test func theNextFormKeepsOnlyTheStorageArea() {
        let form = AddFoodForm(quantity: "3", checked: true).withName("Butter", foods: foods, areas: areas).withArea("freezer")
        #expect(form.next() == AddFoodForm(storageAreaId: "freezer"))
    }

    @Test func theFirstStorageAreaIsTheLastOneUsedThenTheOpenTabThenTheFridge() {
        #expect(AddFoodForm.startArea(lastUsedId: "pantry-1", openTabId: "freezer", areas: areas) == "pantry-1")
        #expect(AddFoodForm.startArea(lastUsedId: nil, openTabId: "freezer", areas: areas) == "freezer")
        #expect(AddFoodForm.startArea(lastUsedId: "deleted", openTabId: "freezer", areas: areas) == "freezer")
        #expect(AddFoodForm.startArea(lastUsedId: nil, openTabId: nil, areas: areas) == "fridge")
    }

    @Test func aFoodSelectsAnAreaOfItsUsualStorageKindAndANameWithNoFoodGoesBackToTheStartArea() {
        // The last batch went to the freezer. Butter goes to the fridge, and peanut butter to the pantry.
        let start = AddFoodForm(storageAreaId: "freezer")
        let withButter = start.withName("Butter", foods: foods, areas: areas)
        #expect(withButter.storageAreaId == "fridge")
        #expect(start.withSuggestion(.ofFood(peanutButter, alias: nil), foods: foods, areas: areas).storageAreaId == "pantry-1")
        #expect(withButter.withName("Bread", foods: foods, areas: areas).storageAreaId == "freezer")
        // Cheese has no usual storage kind.
        #expect(start.withSuggestion(.ofFood(softCheese, alias: nil), foods: foods, areas: areas).storageAreaId == "freezer")
    }

    @Test func theStartAreaStaysWhenItHasTheUsualKindAndAKindWithNoAreaKeepsTheStartArea() {
        let garage = StorageArea(id: "garage", name: "Garage fridge", kind: .fridge, fixed: false)
        let withGarage = areas + [garage]
        #expect(AddFoodForm(storageAreaId: "garage").withName("Butter", foods: foods, areas: withGarage).storageAreaId == "garage")
        #expect(AddFoodForm(storageAreaId: "freezer").withName("Butter", foods: foods, areas: withGarage).storageAreaId == "fridge")
        // The fixed area of a kind comes before an area that the person made.
        #expect(AddFoodForm.areaOfKind(.fridge, startAreaId: "pantry-1", areas: [garage, StorageArea.fridge]) == "fridge")
        // No pantry: peanut butter stays in the start area.
        let noPantry = [StorageArea.fridge, StorageArea.freezer]
        #expect(
            AddFoodForm(storageAreaId: "freezer").withName("Peanut butter", foods: foods, areas: noPantry).storageAreaId
                == "freezer"
        )
    }

    @Test func anAreaThatThePersonSelectedStaysWhenTheFoodChanges() {
        let form = AddFoodForm().withArea("freezer").withName("Peanut butter", foods: foods, areas: areas)
        #expect(form.storageAreaId == "freezer")
        #expect(form.withName("Butter", foods: foods, areas: areas).storageAreaId == "freezer")
    }

    @Test func aScanWithAFoodGetsTheAreaOfItsUsualStorageKind() {
        let form = AddFoodForm.scanned(
            barcode: "1",
            name: "Skippy",
            categoryKey: "condiment",
            foodId: "f-peanut",
            storageAreaId: "fridge",
            decimalSeparator: "."
        )
        #expect(form.withUsualArea(foods: foods, areas: areas).storageAreaId == "pantry-1")
    }

    @Test func theStorageHintOfAScanComesBeforeTheUsualStorageKindOfTheFood() {
        // The name gives peanut butter, which is usually in the pantry. The scan says that this product is frozen.
        let form = AddFoodForm.scanned(
            barcode: "1",
            name: "Peanut butter ice",
            categoryKey: "other",
            foodId: "f-peanut",
            storageKindKey: "freezer",
            storageAreaId: "fridge",
            decimalSeparator: "."
        ).withUsualArea(foods: foods, areas: areas)
        #expect(form.storageAreaId == "freezer")
        // The hint stays when the person changes the name, and when the name has no food.
        #expect(form.withName("Butter", foods: foods, areas: areas).storageAreaId == "freezer")
        #expect(form.withName("Bread", foods: foods, areas: areas).storageAreaId == "freezer")
        // An area that the person selected stays.
        #expect(form.withArea("pantry-1").withName("Butter", foods: foods, areas: areas).storageAreaId == "pantry-1")
        // A hint for a kind with no storage area keeps the start area.
        let noPantry = [StorageArea.fridge, StorageArea.freezer]
        let cereal = AddFoodForm.scanned(
            barcode: "2",
            name: "Cereal",
            storageKindKey: "pantry",
            storageAreaId: "freezer",
            decimalSeparator: "."
        )
        #expect(cereal.withUsualArea(foods: foods, areas: noPantry).storageAreaId == "freezer")
        // The next form has no hint.
        #expect(form.next().hintKind == nil)
    }

    @Test func theStorageTextOfAScanGoesIntoTheActionAndTheFormHasTheStorageTips() throws {
        let form = AddFoodForm.scanned(
            barcode: "1",
            name: "Président Butter",
            categoryKey: "dairy",
            foodId: "f-butter",
            storageText: "Keep at max. 7°C.",
            storageAreaId: "fridge",
            decimalSeparator: "."
        )
        #expect(form.action(products: products, areas: areas, foods: foods, today: today)?.storageText == "Keep at max. 7°C.")
        let advice = try #require(form.storageAdvice(products: products, foods: foods))
        #expect(advice.packageText == "Keep at max. 7°C.")
        #expect(advice.general?.foodName == "Butter")
        #expect(advice.general?.kinds.map(\.kind) == [.fridge, .freezer])

        // A typed name of a food of the table has the general advice only. A name with no food has no tips.
        let typed = AddFoodForm().withName("Butter", foods: foods, areas: areas)
        #expect(typed.storageAdvice(products: products, foods: foods)?.packageText == nil)
        #expect(typed.storageAdvice(products: products, foods: foods)?.general?.foodName == "Butter")
        #expect(AddFoodForm().withName("Mystery", foods: foods, areas: areas).storageAdvice(products: products, foods: foods) == nil)
        // The form shows the storage text of a product in the inventory with the name.
        let saved = Product(
            id: milk.id,
            name: milk.name,
            category: milk.category,
            unit: milk.unit,
            barcode: nil,
            foodId: nil,
            storageText: "Store cold."
        )
        #expect(
            AddFoodForm().withName("Whole milk", foods: foods, areas: areas)
                .storageAdvice(products: [saved], foods: foods)?.packageText == "Store cold."
        )
        // The next form has no storage text.
        #expect(form.next().storageText == nil)
    }

    @Test func aScanFillsInTheFormAndTheBarcodeGoesIntoTheAction() {
        func nutella(quantity: Int, unitKey: String, separator: String, area: String) -> AddFoodForm {
            AddFoodForm.scanned(
                barcode: "3017620422003",
                name: "Nutella",
                categoryKey: "condiment",
                foodId: nil,
                quantity: quantity,
                unitKey: unitKey,
                storageAreaId: area,
                decimalSeparator: separator
            )
        }
        let form = nutella(quantity: 400_000, unitKey: "g", separator: ",", area: "pantry-1")
        #expect(
            form == AddFoodForm(
                name: "Nutella",
                category: .condiment,
                quantity: "400",
                unit: .g,
                storageAreaId: "pantry-1",
                barcode: "3017620422003"
            )
        )
        #expect(form.action(products: products, areas: areas, foods: foods, today: today)?.barcode == "3017620422003")
        // The quantity has the decimal sign of the locale.
        #expect(nutella(quantity: 1_500, unitKey: "l", separator: ",", area: "fridge").quantity == "1,5")
        // The next form has no barcode.
        #expect(form.next().barcode == nil)
    }

    @Test func aScanWithNoValuesKeepsTheStartValuesAndTheBarcode() {
        let notFound = AddFoodForm.scanned(barcode: "5449000000996", storageAreaId: "fridge", decimalSeparator: ".")
        #expect(notFound == AddFoodForm(storageAreaId: "fridge", barcode: "5449000000996"))
        // A quantity with no unit is not reliable.
        #expect(
            AddFoodForm.scanned(barcode: "1", name: "Rice", quantity: 500_000, storageAreaId: "fridge", decimalSeparator: ".")
                .quantity == "1"
        )
        // A key that is not known keeps the start value.
        let unknown = AddFoodForm.scanned(
            barcode: "1",
            categoryKey: "sweets",
            quantity: 500_000,
            unitKey: "oz",
            storageKindKey: "cellar",
            storageAreaId: "fridge",
            decimalSeparator: "."
        )
        #expect(unknown == AddFoodForm(storageAreaId: "fridge", barcode: "1"))
    }

    @Test func theFoodOfAScanGivesTheEstimatedDate() {
        let scanned = AddFoodForm.scanned(
            barcode: "1",
            name: "Président Butter",
            categoryKey: "dairy",
            foodId: "f-butter",
            storageAreaId: "fridge",
            decimalSeparator: "."
        )
        #expect(scanned.estimate(products: products, areas: areas, foods: foods, today: today) == estimated("2026-12-12"))
        #expect(scanned.action(products: products, areas: areas, foods: foods, today: today)?.expiry == estimated("2026-12-12"))
    }

    @Test func suggestionsHaveProductsFirstAndThenFoodsByHowWellTheNameAgrees() {
        let buns = Product(id: "p-buns", name: "Burger buns", category: .bakery, unit: nil, barcode: nil, foodId: nil)
        let found = FoodSuggestions.find("bu", products: [buns], foods: foods)
        let names = found.map { suggestion -> String in
            switch suggestion {
            case .ofProduct(let product):
                return product.name
            case .ofFood(let food, _):
                return food.name
            }
        }
        #expect(names == ["Burger buns", "Butter", "Peanut butter"])
        #expect(FoodSuggestions.find("b", products: products, foods: foods) == [])
    }

    /// A change log with milk in the pantry: two batches of 2 l and one newer batch of 1 l.
    private var milkInventory: Inventory {
        func batch(_ id: String, _ quantity: Int, _ area: String, _ added: String) -> ChangeBody {
            .batchAdded(
                batch: Batch(id: id, productId: milk.id, quantity: quantity, storageAreaId: area, dateAdded: date(added), expiry: nil)
            )
        }
        let bodies: [ChangeBody] = [
            .storageAreaSaved(id: pantry.id, name: pantry.name, kind: pantry.kind),
            .productSaved(product: milk),
            batch("b-1", 2_000, "fridge", "2026-11-01"),
            batch("b-2", 2_000, "fridge", "2026-11-03"),
            batch("b-3", 1_000, pantry.id, "2026-11-05"),
        ]
        return Inventory.replay(bodies.enumerated().map { Change(id: "c-\($0.offset)", at: $0.offset, origin: "phone", body: $0.element) })
    }

    private func start(productId: String? = nil, openAreaId: String? = nil, scan: Scanned? = nil, again: Bool = false) -> AddFoodForm {
        AddFoodForm.start(
            productId: productId,
            openAreaId: openAreaId,
            scan: scan,
            again: again,
            inventory: milkInventory,
            foods: foods,
            lastAreaId: "freezer",
            decimalSeparator: ","
        )
    }

    @Test func theScanOfTheLookupGivesTheSameFormAsItsValues() {
        let scan = Scanned(
            barcode: "3017620422003",
            source: .found,
            name: "Président Butter",
            category: .dairy,
            foodId: "f-butter",
            quantity: 250_000,
            unit: .g,
            storageKind: .fridge,
            storageText: "Keep cold"
        )
        let form = AddFoodForm.scanned(scan, storageAreaId: "freezer", decimalSeparator: ".")
        #expect(
            form == AddFoodForm.scanned(
                barcode: "3017620422003",
                name: "Président Butter",
                categoryKey: "dairy",
                foodId: "f-butter",
                quantity: 250_000,
                unitKey: "g",
                storageKindKey: "fridge",
                storageText: "Keep cold",
                storageAreaId: "freezer",
                decimalSeparator: "."
            )
        )
    }

    @Test func theStartFormIsEmptyInTheLastUsedAreaAndThenInTheOpenArea() {
        #expect(start() == AddFoodForm(storageAreaId: "freezer"))
        #expect(start(openAreaId: pantry.id) == AddFoodForm(storageAreaId: "freezer"))
        let noLast = AddFoodForm.start(
            productId: nil, openAreaId: pantry.id, scan: nil, again: false,
            inventory: milkInventory, foods: foods, lastAreaId: nil, decimalSeparator: "."
        )
        #expect(noLast == AddFoodForm(storageAreaId: pantry.id))
    }

    @Test func addAgainStartsWithTheNewestAreaAndTheUsualQuantity() {
        let form = start(productId: milk.id, again: true)
        #expect(form.name == "Whole milk")
        #expect(form.storageAreaId == pantry.id)
        #expect(form.areaKept)
        #expect(form.quantity == "2")
        #expect(form.unit == .l)
        #expect(form.expiry == .suggested)
        #expect(form.barcode == nil)
    }

    // Correction of AddFoodScreen.kt:159: a scan of a barcode that the inventory has gets the values of "Add again".
    @Test func aScanOfAProductInTheInventoryStartsAsAddAgainWithTheBarcode() {
        let scan = Scanned(barcode: "5449000000996", source: .inInventory, storageKind: .freezer)
        let form = start(productId: milk.id, scan: scan)
        #expect(form.name == "Whole milk")
        #expect(form.barcode == "5449000000996")
        #expect(form.quantity == "2")
        // The storage area of the newest batch comes before the storage hint.
        #expect(form.storageAreaId == pantry.id)
        #expect(form.hintKind == .freezer)
    }

    @Test func aScanOfANewProductStartsWithTheValuesOfTheScanInTheAreaOfItsHint() {
        let scan = Scanned(
            barcode: "3017620422003", source: .found, name: "Skippy", category: .condiment, foodId: "f-peanut",
            quantity: 1_500, unit: .kg
        )
        let form = start(scan: scan)
        #expect(form.name == "Skippy")
        #expect(form.quantity == "1,5")
        #expect(form.unit == .kg)
        // Peanut butter is usually in the pantry.
        #expect(form.storageAreaId == pantry.id)
        // A product that is not in the inventory has no effect.
        #expect(start(productId: "p-gone", scan: scan) == form)
    }
}
