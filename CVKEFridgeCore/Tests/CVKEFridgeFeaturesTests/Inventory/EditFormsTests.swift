import Testing
@testable import CVKEFridgeFeatures

/// The forms that edit a product and a batch. The same cases as the Android EditFormsTest.
struct EditFormsTests {
    private let areas = [StorageArea.fridge, StorageArea.freezer]
    private let foods = FoodTable(foods: [
        Food(
            id: "f-butter",
            name: "Butter",
            subtitle: nil,
            category: .dairy,
            keywords: ["butter"],
            days: [.fridge: 30, .freezer: 180]
        ),
    ])
    private let butter = Product(
        id: "p-butter",
        name: "Butter",
        category: .dairy,
        unit: .g,
        barcode: "4000000000001",
        foodId: "f-butter"
    )
    private let milk = Product(id: "p-milk", name: "Whole milk", category: .dairy, unit: .l, barcode: nil, foodId: nil)
    private var products: [Product] { [butter, milk] }

    private func date(_ text: String) -> CalendarDate {
        CalendarDate.parse(text)!
    }

    private func batch(_ expiry: ExpiryDate?) -> Batch {
        Batch(
            id: "b1",
            productId: "p-butter",
            quantity: 250_000,
            storageAreaId: "fridge",
            dateAdded: date("2026-11-01"),
            expiry: expiry
        )
    }

    private func changed<T>(_ value: T, _ change: (inout T) -> Void) -> T {
        var copy = value
        change(&copy)
        return copy
    }

    @Test func aProductKeepsItsOtherValuesAndItsFoodWhileTheNameFits() throws {
        let saved = try #require(
            ProductForm(name: " Salted  butter ", category: .other, unit: .pack)
                .action(product: butter, products: products, foods: foods)
        ).product
        #expect(
            saved == Product(
                id: "p-butter",
                name: "Salted butter",
                category: .other,
                unit: .pack,
                barcode: "4000000000001",
                foodId: "f-butter"
            )
        )
        #expect(
            ProductForm(name: "Margarine", category: .dairy, unit: .g)
                .action(product: butter, products: products, foods: foods)?.product.foodId == nil
        )
        #expect(
            ProductForm(name: "butter", category: .dairy, unit: nil)
                .action(product: milk, products: [milk], foods: foods)?.product.foodId == "f-butter"
        )
    }

    @Test func theNoteIsSavedWithoutSpacesAtTheEndsAndAnEmptyNoteIsRemoved() throws {
        let withNote = Product(
            id: butter.id,
            name: butter.name,
            category: butter.category,
            unit: butter.unit,
            barcode: butter.barcode,
            foodId: butter.foodId,
            note: "Opened"
        )
        #expect(ProductForm.of(withNote).note == "Opened")
        #expect(ProductForm.of(butter).note == "")
        func saved(_ note: String) -> String? {
            ProductForm(name: "Butter", category: .dairy, unit: .g, note: note)
                .action(product: withNote, products: products, foods: foods)?.product.note
        }
        #expect(saved("  For the cake,\nnot for toast \n") == "For the cake,\nnot for toast")
        #expect(saved("   \n ") == nil)
        #expect(saved("") == nil)
        // The other values of the form do not change the note.
        let renamed = changed(ProductForm.of(withNote)) { $0.name = "Salted butter" }
        #expect(try #require(renamed.action(product: withNote, products: products, foods: foods)).product.note == "Opened")
    }

    @Test func aProductCannotGetTheNameOfAnotherProduct() {
        #expect(
            ProductForm(name: "whole MILK", category: .dairy, unit: nil).nameError(product: butter, products: products)
                == .inUse
        )
        #expect(ProductForm(name: "BUTTER", category: .dairy, unit: nil).nameError(product: butter, products: products) == nil)
        #expect(ProductForm(name: " ", category: .dairy, unit: nil).nameError(product: butter, products: products) == .empty)
        #expect(
            ProductForm(name: "Whole milk", category: .dairy, unit: nil)
                .action(product: butter, products: products, foods: foods) == nil
        )
    }

    @Test func anEstimatedDateFollowsTheStorageAreaAndTheDateAdded() {
        // The estimated date of the batch is not the date of the table. It stays while the two values stay.
        let original = batch(ExpiryDate(date: date("2026-11-20"), source: .estimated))
        let form = BatchForm.of(original, decimalSeparator: ".")
        #expect(form.quantity == "250")
        #expect(
            changed(form) { $0.quantity = "100" }.action(batch: original, product: butter, areas: areas, foods: foods)?
                .expiry == original.expiry
        )

        let frozen = changed(form) { $0.storageAreaId = "freezer" }
            .action(batch: original, product: butter, areas: areas, foods: foods)
        #expect(frozen?.expiry == ExpiryDate(date: date("2027-04-30"), source: .estimated))
        let later = changed(form) { $0.dateAdded = date("2026-11-05") }
            .action(batch: original, product: butter, areas: areas, foods: foods)
        #expect(later?.expiry == ExpiryDate(date: date("2026-12-05"), source: .estimated))
        // The product has no food, so there is no new estimate. The estimated date of the batch stays.
        #expect(
            changed(form) { $0.storageAreaId = "freezer" }
                .action(batch: original, product: milk, areas: areas, foods: foods)?.expiry == original.expiry
        )
    }

    @Test func aPrintedDateAndNoExpiryDateStay() {
        let printed = batch(ExpiryDate(date: date("2026-11-20"), source: .printed))
        #expect(
            changed(BatchForm.of(printed, decimalSeparator: ".")) { $0.storageAreaId = "freezer" }
                .action(batch: printed, product: butter, areas: areas, foods: foods)?.expiry == printed.expiry
        )

        let none = batch(nil)
        let form = BatchForm.of(none, decimalSeparator: ".")
        #expect(
            changed(form) { $0.storageAreaId = "freezer" }
                .action(batch: none, product: butter, areas: areas, foods: foods)?.expiry == nil
        )
        // The person can select the estimated date for a batch that has no expiry date.
        #expect(
            changed(form) { $0.expiry = .suggested }
                .action(batch: none, product: butter, areas: areas, foods: foods)?.expiry
                == ExpiryDate(date: date("2026-12-01"), source: .estimated)
        )
    }

    @Test func aBatchFormWithAProblemSavesNothing() {
        let original = batch(nil)
        let form = BatchForm.of(original, decimalSeparator: ",")
        #expect(changed(form) { $0.quantity = "" }.action(batch: original, product: butter, areas: areas, foods: foods) == nil)
        #expect(
            changed(form) { $0.storageAreaId = "gone" }.action(batch: original, product: butter, areas: areas, foods: foods)
                == nil
        )
        #expect(
            changed(form) { $0.quantity = "1,5" }.action(batch: original, product: butter, areas: areas, foods: foods)?
                .quantity == 1_500
        )
        #expect(changed(form) { $0.quantity = "" }.quantityError() == .empty)
    }

    @Test func aChosenDateStaysAChosenDate() {
        let chosen = batch(ExpiryDate(date: date("2026-11-25"), source: .chosen))
        let form = BatchForm.of(chosen, decimalSeparator: ".")
        #expect(form.expiry == .chosen(date("2026-11-25")))
        #expect(form.action(batch: chosen, product: butter, areas: areas, foods: foods)?.expiry == chosen.expiry)
    }

    // The form tells before the save what a new unit does to the numbers, so that it can ask the person.
    @Test func theFormTellsWhatANewUnitDoesToTheQuantities() {
        let inventory = Inventory.replay([
            Change(id: "c0", at: 0, origin: "test", body: .productSaved(product: butter)),
            Change(id: "c1", at: 1, origin: "test", body: .batchAdded(batch: batch(nil))),
        ])
        let form = ProductForm.of(butter)
        #expect(form.unitChange(product: butter, inventory: inventory) == .unchanged)
        #expect(changed(form) { $0.unit = .kg }.unitChange(product: butter, inventory: inventory) == .converts)
        #expect(changed(form) { $0.unit = .pack }.unitChange(product: butter, inventory: inventory) == .keepsNumbers)
        #expect(changed(form) { $0.unit = nil }.unitChange(product: butter, inventory: inventory) == .keepsNumbers)
        // A product with no active batch has no number to keep.
        let empty = Inventory.replay([Change(id: "c0", at: 0, origin: "test", body: .productSaved(product: butter))])
        #expect(changed(form) { $0.unit = .pack }.unitChange(product: butter, inventory: empty) == .unchanged)
    }
}
