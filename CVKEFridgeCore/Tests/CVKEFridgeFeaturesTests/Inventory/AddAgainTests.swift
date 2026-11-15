import Testing
@testable import CVKEFridgeFeatures

/// The values of "Add again" and the list of recent foods, from a change log. The same cases as the Android
/// AddAgainTest.
struct AddAgainTests {
    private let today = CalendarDate.parse("2026-11-12")!
    private let inventoryLog: [Change]
    private let inventory: Inventory
    private let foods = FoodTable(foods: [
        Food(
            id: "f-milk",
            name: "Milk",
            subtitle: nil,
            category: .dairy,
            keywords: [],
            days: [.fridge: 7, .freezer: 90],
            usualKind: .fridge
        ),
    ])

    private static func date(_ text: String) -> CalendarDate {
        CalendarDate.parse(text)!
    }

    private func date(_ text: String) -> CalendarDate {
        Self.date(text)
    }

    private static func product(_ id: String, _ name: String, _ unit: MeasureUnit?, foodId: String? = nil) -> ChangeBody {
        .productSaved(product: Product(id: id, name: name, category: .dairy, unit: unit, barcode: nil, foodId: foodId))
    }

    private static func batch(_ id: String, _ product: String, _ quantity: Int, _ area: String, _ added: String) -> ChangeBody {
        .batchAdded(
            batch: Batch(
                id: id,
                productId: product,
                quantity: quantity,
                storageAreaId: area,
                dateAdded: date(added),
                expiry: ExpiryDate(date: date(added), source: .printed)
            )
        )
    }

    /// The changes `c0`, `c1`, and so on, with the instants 0, 1, and so on.
    private static func log(_ bodies: [ChangeBody]) -> [Change] {
        bodies.enumerated().map { index, body in Change(id: "c\(index)", at: index, origin: "test", body: body) }
    }

    init() {
        inventoryLog = Self.log([
            .storageAreaSaved(id: "cellar", name: "Cellar", kind: .pantry),
            Self.product("milk", "Milk", .l, foodId: "f-milk"),
            Self.product("jam", "Jam", nil),
            Self.product("soup", "Soup", .ml),
            Self.product("tea", "Tea", .pack),
            Self.product("salt", "Salt", .g),
            Self.batch("m1", "milk", 1_000, "fridge", "2026-10-01"),
            Self.batch("m2", "milk", 2_000, "fridge", "2026-10-10"),
            Self.batch("m3", "milk", 1_000, "freezer", "2026-11-01"),
            Self.batch("j1", "jam", 500, "cellar", "2026-10-20"),
            Self.batch("s1", "soup", 1_000, "fridge", "2026-11-05"),
            Self.batch("t1", "tea", 1_000, "cellar", "2026-10-01"),
            Self.batch("t2", "tea", 2_000, "fridge", "2026-10-02"),
            .batchUsed(batchId: "m1", quantity: 400, date: Self.date("2026-10-05")),
            .batchThrownAway(batchId: "m1", quantity: 600, date: Self.date("2026-10-06")),
            .batchUsed(batchId: "m2", quantity: 2_000, date: Self.date("2026-10-15")),
            .batchThrownAway(batchId: "j1", quantity: 500, date: Self.date("2026-10-25")),
            .batchUsed(batchId: "t1", quantity: 1_000, date: Self.date("2026-10-08")),
            .batchUsed(batchId: "t2", quantity: 2_000, date: Self.date("2026-10-09")),
            // The storage area can go when no active batch is in it.
            .storageAreaDeleted(storageAreaId: "cellar"),
            .batchUsed(batchId: "s1", quantity: 400, date: Self.date("2026-11-06")),
            .batchUsed(batchId: "m3", quantity: 1_000, date: Self.date("2026-11-03")),
        ])
        inventory = Inventory.replay(inventoryLog)
    }

    private func product(_ id: String) throws -> Product {
        try #require(inventory.products.first(where: { $0.id == id }))
    }

    @Test func theNewestBatchGivesTheStorageAreaAndTheMostCommonQuantityWins() {
        // The batches of milk had 1 l, 2 l, and 1 l when they were added. A use and a throw away do not change that.
        #expect(AddAgain.values(inventory: inventory, productId: "milk") == AgainValues(storageAreaId: "freezer", quantity: 1_000))
        // A batch that is still active counts with the quantity that it had at the start.
        #expect(AddAgain.values(inventory: inventory, productId: "soup") == AgainValues(storageAreaId: "fridge", quantity: 1_000))
    }

    @Test func withTheSameNumberOfBatchesTheNewerQuantityWins() {
        #expect(AddAgain.values(inventory: inventory, productId: "tea") == AgainValues(storageAreaId: "fridge", quantity: 2_000))
        #expect(AddAgain.usualQuantity(newestFirst: [3_000, 1_000, 1_000, 3_000]) == 3_000)
    }

    @Test func aStorageAreaThatIsNotThereAndAProductWithNoBatchGiveNoValue() {
        #expect(AddAgain.values(inventory: inventory, productId: "jam") == AgainValues(storageAreaId: nil, quantity: 500))
        #expect(AddAgain.values(inventory: inventory, productId: "salt") == AgainValues(storageAreaId: nil, quantity: nil))
        #expect(AddAgain.usualQuantity(newestFirst: []) == nil)
    }

    @Test func theRecentFoodsAreTheProductsThatWereAddedUsedOrThrownAwayLastFirst() {
        // Milk was used last (c21), then soup (c20), tea (c18), and jam (c16). Soup is still in the inventory. Salt
        // has no batch.
        let recent = AddAgain.recent(changes: inventoryLog, inventory: inventory)
        #expect(recent.map(\.product.id) == ["milk", "soup", "tea", "jam"])
        #expect(recent.map(\.at) == [21, 20, 18, 16])
        #expect(AddAgain.shown(recent, hidden: [:], limit: 2).map(\.id) == ["milk", "soup"])
        #expect(AddAgain.inStock(inventory: inventory, productId: "soup"))
        #expect(!AddAgain.inStock(inventory: inventory, productId: "milk"))
    }

    @Test func aRemovedFoodComesBackAfterTheNextAddUseOrThrowAway() {
        let recent = AddAgain.recent(changes: inventoryLog, inventory: inventory)
        // The person removed soup after its last use, and tea before its last use.
        let hidden = ["soup": 20, "tea": 17]
        #expect(AddAgain.shown(recent, hidden: hidden).map(\.id) == ["milk", "tea", "jam"])
    }

    @Test func anAddThatWasUndoneDoesNotCount() {
        let log = Self.log([
            Self.product("jam", "Jam", nil),
            Self.batch("j1", "jam", 500, "fridge", "2026-11-01"),
            .changeUndone(changeId: "c1"),
        ])
        #expect(AddAgain.recent(changes: log, inventory: Inventory.replay(log)) == [])
    }

    @Test func theFormOfAddAgainHasTheValuesAndAnEstimateFromToday() throws {
        let milk = try product("milk")
        let form = AddFoodForm.again(
            product: milk,
            values: AddAgain.values(inventory: inventory, productId: "milk"),
            startArea: "fridge",
            decimalSeparator: ","
        )
        #expect(form.name == "Milk")
        #expect(form.storageAreaId == "freezer")
        #expect(form.quantity == "1")
        #expect(form.expiry == .suggested)

        // The new batch goes to the same product. Its expiry date is the estimate for the freezer from today.
        let action = try #require(
            form.action(products: inventory.products, areas: inventory.storageAreas, foods: foods, today: today)
        )
        #expect(action.productId == "milk")
        #expect(action.quantity == 1_000)
        #expect(action.expiry == ExpiryDate(date: date("2027-02-10"), source: .estimated))

        // A product with no storage area and a fraction keeps the start storage area and the decimal sign.
        let jam = try product("jam")
        let jamForm = AddFoodForm.again(
            product: jam,
            values: AgainValues(storageAreaId: nil, quantity: 1_500),
            startArea: "fridge",
            decimalSeparator: ","
        )
        #expect(jamForm.storageAreaId == "fridge")
        #expect(jamForm.quantity == "1,5")
        // No food of the table: no estimate, so no expiry date. The form never takes an earlier date.
        let jamAction = jamForm.action(products: inventory.products, areas: inventory.storageAreas, foods: foods, today: today)
        #expect(jamAction != nil)
        #expect(jamAction?.expiry == nil)
    }

    @Test func aRecentFoodThatThePersonSelectsGetsItsValues() throws {
        let form = AddFoodForm(quantity: "3", storageAreaId: "fridge", expiry: .noExpiryDate)
            .withSuggestion(.ofProduct(try product("milk")), foods: foods, areas: inventory.storageAreas)
            .again(AddAgain.values(inventory: inventory, productId: "milk"), decimalSeparator: ".")
        #expect(form.name == "Milk")
        #expect(form.storageAreaId == "freezer")
        #expect(form.quantity == "1")
        #expect(form.expiry == .suggested)
    }
}
