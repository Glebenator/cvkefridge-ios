import Testing
@testable import CVKEFridgeFeatures

/// Makes the identifiers `new-0`, `new-1`, and so on.
private final class Counter {
    private var count = 0

    func next() -> String {
        defer { count += 1 }
        return "new-\(count)"
    }
}

/// The changes of each action, and their result in the replay of the core. The same cases as the Android
/// InventoryActionsTest.
struct InventoryActionsTests {
    private let today = CalendarDate.parse("2026-11-12")!
    private let log: [Change]
    private let inventory: Inventory
    private let counter = Counter()

    private static func date(_ text: String) -> CalendarDate {
        CalendarDate.parse(text)!
    }

    private func date(_ text: String) -> CalendarDate {
        Self.date(text)
    }

    private static func batch(_ id: String, _ product: String, _ quantity: Int, _ area: String, _ expires: String?) -> ChangeBody {
        .batchAdded(
            batch: Batch(
                id: id,
                productId: product,
                quantity: quantity,
                storageAreaId: area,
                dateAdded: date("2026-11-01"),
                expiry: expires.map { ExpiryDate(date: date($0), source: .printed) }
            )
        )
    }

    private static func log(_ bodies: [ChangeBody], prefix: String = "c") -> [Change] {
        bodies.enumerated().map { index, body in Change(id: "\(prefix)\(index)", at: index, origin: "test", body: body) }
    }

    init() {
        log = Self.log([
            .storageAreaSaved(id: "pantry", name: "Pantry", kind: .pantry),
            .productSaved(product: Product(id: "milk", name: "Milk", category: .dairy, unit: .l, barcode: nil, foodId: nil)),
            .productSaved(product: Product(id: "rice", name: "Rice", category: .other, unit: .kg, barcode: nil, foodId: nil)),
            Self.batch("m-new", "milk", 2_000, "fridge", "2026-11-20"),
            Self.batch("m-old", "milk", 1_000, "fridge", "2026-11-13"),
            Self.batch("m-frozen", "milk", 1_000, "freezer", "2027-01-01"),
            Self.batch("r1", "rice", 1_000, "pantry", nil),
        ])
        inventory = Inventory.replay(log)
    }

    /// The barcodes in the tests are in the form of the lookup, so they stay as they are.
    private func plan(_ action: InventoryAction, _ inventory: Inventory) -> Planned {
        InventoryActions.plan(action, inventory: inventory, today: today, newId: counter.next, normalizeBarcode: { $0 })
    }

    /// The changes of the action, and the change log after them. A change that the core rejects fails the test.
    private func apply(
        _ action: InventoryAction,
        from: [Change]? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> (planned: Planned.Changes, changes: [Change]) {
        let start = from ?? log
        let before = Inventory.replay(start)
        let planned = try #require(plan(action, before).plannedChanges, sourceLocation: sourceLocation)
        let changes = start + NewChanges.stamp(planned.bodies, log: start, now: 1_000, origin: "phone", newId: counter.next)
        #expect(NewChanges.rejection(previous: before, next: Inventory.replay(changes)) == nil, sourceLocation: sourceLocation)
        return (planned, changes)
    }

    private func quantities(_ changes: [Change]) -> [String: Int] {
        var found: [String: Int] = [:]
        for batch in Inventory.replay(changes).batches {
            found[batch.id] = batch.quantity
        }
        return found
    }

    private func product(_ changes: [Change], where wanted: (Product) -> Bool) throws -> Product {
        let found = Inventory.replay(changes).products.filter(wanted)
        try #require(found.count == 1)
        return found[0]
    }

    private func addFood(
        _ productId: String?,
        _ name: String,
        _ category: CVKEFridgeCore.Category,
        _ unit: MeasureUnit?,
        _ foodId: String?,
        _ quantity: Int,
        _ area: String,
        barcode: String? = nil,
        note: String? = nil,
        storageText: String? = nil
    ) -> InventoryAction.AddFood {
        InventoryAction.AddFood(
            productId: productId,
            name: name,
            category: category,
            unit: unit,
            foodId: foodId,
            quantity: quantity,
            storageAreaId: area,
            expiry: nil,
            barcode: barcode,
            note: note,
            storageText: storageText
        )
    }

    private func changed<T>(_ value: T, _ change: (inout T) -> Void) -> T {
        var copy = value
        change(&copy)
        return copy
    }

    @Test func aLaterExpiryDateChangesOnlyTheExpiryDateAndCanBeUndone() throws {
        let (planned, changes) = try apply(.moveExpiry(batchId: "m-old", date: date("2026-11-20")))
        #expect(planned.message == .expiryMoved(name: "Milk", date: date("2026-11-20")))
        #expect(planned.undoable)
        let moved = try #require(Inventory.replay(changes).batches.first(where: { $0.id == "m-old" }))
        #expect(moved.expiry == ExpiryDate(date: date("2026-11-20"), source: .chosen))
        #expect(moved.quantity == 1_000)
        #expect(moved.storageAreaId == "fridge")
        #expect(moved.dateAdded == date("2026-11-01"))

        let ids = changes.suffix(planned.bodies.count).map(\.id)
        let (_, undone) = try apply(.undo(changeIds: ids), from: changes)
        #expect(Inventory.replay(undone).batches.first(where: { $0.id == "m-old" })?.expiry?.date == date("2026-11-13"))
    }

    @Test func aLaterExpiryDateOfABatchThatIsNotThereIsRefused() {
        #expect(plan(.moveExpiry(batchId: "none", date: today), inventory) == .refused(.unknownBatch))
    }

    @Test func aNewFoodIsAProductAndABatchThatIsAddedToday() throws {
        let action = addFood(nil, "Butter", .dairy, .g, "fk-1", 250_000, "fridge")
        let (planned, changes) = try apply(.addFood(action))
        #expect(planned.bodies.count == 2)
        #expect(planned.message == .added(name: "Butter"))
        let after = Inventory.replay(changes)
        let butter = try product(changes) { $0.name == "Butter" }
        #expect(
            after.batches.filter { $0.productId == butter.id } == [
                Batch(id: "new-1", productId: butter.id, quantity: 250_000, storageAreaId: "fridge", dateAdded: today, expiry: nil),
            ]
        )

        // A batch for a product in the inventory does not save the product again.
        let (again, _) = try apply(.addFood(changed(action) {
            $0.productId = "milk"
            $0.name = "Milk"
        }))
        #expect(again.bodies.count == 1)
    }

    @Test func aNoteOfTheAddFormGoesOnTheProductAndAnEmptyNoteKeepsTheNote() throws {
        let action = addFood(nil, "Jam", .condiment, nil, nil, 1_000, "fridge", note: "For the cake")
        let (_, changes) = try apply(.addFood(action))
        let jam = try product(changes) { $0.name == "Jam" }
        #expect(jam.note == "For the cake")

        // A batch with no note keeps the note of the product, and saves the product not again.
        let (same, _) = try apply(.addFood(changed(action) {
            $0.productId = jam.id
            $0.note = nil
        }), from: changes)
        #expect(same.bodies.count == 1)
        // A batch with the same note also does not save the product again.
        let (unchanged, _) = try apply(.addFood(changed(action) { $0.productId = jam.id }), from: changes)
        #expect(unchanged.bodies.count == 1)

        // A batch with another note replaces the note, and the undo of the add brings the first note back.
        let (other, replaced) = try apply(.addFood(changed(action) {
            $0.productId = jam.id
            $0.note = "Opened"
        }), from: changes)
        #expect(other.bodies.count == 2)
        #expect(try product(replaced) { $0.id == jam.id }.note == "Opened")
        let (_, undone) = try apply(.undo(changeIds: replaced.dropFirst(changes.count).map(\.id)), from: replaced)
        #expect(try product(undone) { $0.id == jam.id }.note == "For the cake")
    }

    @Test func theStorageTextOfAScanGoesOnTheProductAndABatchWithNoStorageTextKeepsIt() throws {
        let action = addFood(nil, "Pizza", .other, nil, nil, 1_000, "freezer", storageText: "Store at -18°C.")
        let (_, changes) = try apply(.addFood(action))
        let pizza = try product(changes) { $0.name == "Pizza" }
        #expect(pizza.storageText == "Store at -18°C.")

        // A batch that the person adds by hand has no storage text. The product keeps its text, and is not saved again.
        let (same, _) = try apply(.addFood(changed(action) {
            $0.productId = pizza.id
            $0.storageText = nil
        }), from: changes)
        #expect(same.bodies.count == 1)

        // A later scan with another text replaces the text. A product with no text gets the text of a scan.
        let (_, replaced) = try apply(.addFood(changed(action) {
            $0.productId = pizza.id
            $0.storageText = "Bei -18 °C lagern."
        }), from: changes)
        #expect(try product(replaced) { $0.id == pizza.id }.storageText == "Bei -18 °C lagern.")
        let (_, milk) = try apply(
            .addFood(addFood("milk", "Milk", .dairy, .l, nil, 1_000, "fridge", storageText: "Keep at max. 7°C."))
        )
        #expect(try product(milk) { $0.id == "milk" }.storageText == "Keep at max. 7°C.")

        // An edit of the product keeps the storage text.
        let form = changed(ProductForm.of(pizza)) { $0.name = "Frozen pizza" }
        let edited = form.action(product: pizza, products: Inventory.replay(changes).products, foods: FoodTable(foods: []))
        #expect(edited?.product.storageText == "Store at -18°C.")
    }

    @Test func aScannedBarcodeGoesOnTheProductWhenNoOtherProductHasIt() throws {
        let scanned = addFood(nil, "Nutella", .condiment, .g, nil, 400_000, "pantry", barcode: "3017620422003")
        let (_, changes) = try apply(.addFood(scanned))
        #expect(try product(changes) { $0.name == "Nutella" }.barcode == "3017620422003")

        // Another product has the barcode. The new product does not get it, so a scan still finds the first product.
        let (_, twice) = try apply(.addFood(changed(scanned) { $0.name = "Hazelnut spread" }), from: changes)
        #expect(try product(twice) { $0.name == "Hazelnut spread" }.barcode == nil)
    }

    @Test func aSavedBarcodeIsComparedInTheFormOfTheLookup() throws {
        // A product has an older barcode with a space. The lookup gives the form without the space.
        let older = Self.log(
            [.productSaved(product: Product(id: "n", name: "Nutella", category: .condiment, unit: .g, barcode: " 3017620422003", foodId: nil))],
            prefix: "o"
        )
        let before = Inventory.replay(log + older)
        let action = InventoryAction.addFood(addFood(nil, "Spread", .condiment, .g, nil, 400_000, "pantry", barcode: "3017620422003"))
        let normalized = InventoryActions.plan(
            action,
            inventory: before,
            today: today,
            newId: counter.next,
            normalizeBarcode: { $0.filter(\.isNumber) }
        )
        let saved = try #require(normalized.plannedChanges?.bodies.first)
        guard case .productSaved(let spread) = saved else {
            Issue.record("The first change does not save the product")
            return
        }
        #expect(spread.barcode == nil)
    }

    @Test func aProductInTheInventoryWithNoBarcodeGetsTheScannedBarcode() throws {
        let batch = addFood("milk", "Milk", .dairy, .l, nil, 1_000, "fridge", barcode: "5449000000996")
        let (planned, changes) = try apply(.addFood(batch))
        #expect(planned.bodies.count == 2)
        #expect(try product(changes) { $0.id == "milk" }.barcode == "5449000000996")

        // A product keeps the barcode that it has.
        let (other, _) = try apply(.addFood(changed(batch) { $0.barcode = "3017620422003" }), from: changes)
        #expect(other.bodies.count == 1)

        // The undo of the add also removes the barcode.
        let (_, undone) = try apply(.undo(changeIds: changes.dropFirst(log.count).map(\.id)), from: changes)
        #expect(try product(undone) { $0.id == "milk" }.barcode == nil)
    }

    @Test func aUseTakesFromTheOldestBatchFirst() throws {
        let fridge = ["m-new", "m-old"]
        let (planned, changes) = try apply(
            .take(InventoryAction.Take(productId: "milk", batchIds: fridge, quantity: 1_500, outcome: .used))
        )
        #expect(quantities(changes) == ["m-old": 0, "m-new": 1_500, "m-frozen": 1_000, "r1": 1_000])
        #expect(planned.message == .taken(name: "Milk", quantity: 1_500, unit: .l, outcome: .used))
        #expect(Inventory.replay(changes).history.map(\.outcome) == [.used, .used])

        // The undo of the action undoes each of its changes.
        let added = changes.dropFirst(log.count).map(\.id)
        let (_, undone) = try apply(.undo(changeIds: added), from: changes)
        #expect(quantities(undone) == quantities(log))
        #expect(Inventory.replay(undone).history.isEmpty)
    }

    @Test func aThrowAwayOfOneBatchDoesNotTakeFromTheOthers() throws {
        let (planned, changes) = try apply(
            .take(InventoryAction.Take(productId: "milk", batchIds: ["m-new"], quantity: 2_000, outcome: .thrownAway))
        )
        #expect(quantities(changes)["m-new"] == 0)
        #expect(quantities(changes)["m-old"] == 1_000)
        #expect(Inventory.replay(changes).history.map(\.outcome) == [.thrownAway])
        #expect(planned.undoable)
    }

    @Test func theCoreGivesTheReasonWhenABatchHasNothingToTake() throws {
        let useRice = InventoryAction.take(
            InventoryAction.Take(productId: "rice", batchIds: ["r1"], quantity: 1_000, outcome: .used)
        )
        let (_, ended) = try apply(useRice)
        let before = Inventory.replay(ended)
        let planned = try #require(plan(useRice, before).plannedChanges)
        let after = Inventory.replay(
            ended + NewChanges.stamp(planned.bodies, log: ended, now: 2_000, origin: "phone", newId: counter.next)
        )
        #expect(NewChanges.rejection(previous: before, next: after) == .batchEnded)
        #expect(
            plan(.take(InventoryAction.Take(productId: "rice", batchIds: [], quantity: 1_000, outcome: .used)), inventory)
                == .refused(.unknownBatch)
        )
        #expect(
            plan(.take(InventoryAction.Take(productId: "none", batchIds: ["r1"], quantity: 1_000, outcome: .used)), inventory)
                == .refused(.unknownProduct)
        )
    }

    @Test func aDeleteOfSomeBatchesKeepsTheProductAndADeleteOfAllBatchesDeletesIt() throws {
        let (some, afterSome) = try apply(.deleteBatches(productId: "milk", batchIds: ["m-new", "m-old"]))
        #expect(some.message == .batchDeleted(name: "Milk", count: 2))
        #expect(Set(quantities(afterSome).keys) == ["m-frozen", "r1"])
        #expect(Inventory.replay(afterSome).products.contains(where: { $0.id == "milk" }))

        let (all, afterAll) = try apply(.deleteBatches(productId: "rice", batchIds: ["r1"]))
        #expect(all.bodies == [.productDeleted(productId: "rice")])
        #expect(all.message == .foodDeleted(name: "Rice"))
        #expect(Inventory.replay(afterAll).products.map(\.id) == ["milk"])
        #expect(plan(.deleteBatches(productId: "rice", batchIds: []), inventory) == .refused(.unknownBatch))
    }

    @Test func aDeleteOfAProductHasItsName() throws {
        let (deleted, changes) = try apply(.deleteProduct(productId: "rice"))
        #expect(deleted.message == .foodDeleted(name: "Rice"))
        #expect(deleted.undoable)
        #expect(Inventory.replay(changes).products.map(\.id) == ["milk"])
    }

    @Test func aStorageAreaWithFoodCannotBeDeleted() throws {
        let planned = try #require(plan(.deleteStorageArea(id: "pantry"), inventory).plannedChanges)
        let after = Inventory.replay(
            log + NewChanges.stamp(planned.bodies, log: log, now: 1_000, origin: "phone", newId: counter.next)
        )
        #expect(NewChanges.rejection(previous: inventory, next: after) == .storageAreaInUse)

        // After the food is used, the delete applies, and the person can undo it.
        let (_, used) = try apply(
            .take(InventoryAction.Take(productId: "rice", batchIds: ["r1"], quantity: 1_000, outcome: .used))
        )
        let (deleted, changes) = try apply(.deleteStorageArea(id: "pantry"), from: used)
        #expect(deleted.message == .storageAreaDeleted(name: "Pantry"))
        #expect(Inventory.replay(changes).storageAreas.map(\.id) == ["freezer", "fridge"])
    }

    @Test func aNewStorageAreaGetsARandomIdentifierAndAnEditKeepsIt() throws {
        let (_, added) = try apply(.saveStorageArea(InventoryAction.SaveStorageArea(id: nil, name: "Cellar", kind: .pantry)))
        #expect(Inventory.replay(added).storageAreas.first(where: { $0.id == "new-0" })?.name == "Cellar")
        let (_, renamed) = try apply(
            .saveStorageArea(InventoryAction.SaveStorageArea(id: "pantry", name: "Larder", kind: .fridge)),
            from: added
        )
        let pantry = try #require(Inventory.replay(renamed).storageAreas.first(where: { $0.id == "pantry" }))
        #expect(pantry.name == "Larder")
        #expect(pantry.kind == .fridge)
    }

    @Test func anEmptyUndoIsRefused() {
        #expect(plan(.undo(changeIds: []), inventory) == .refused(.unknownChange))
    }

    @Test func theSourceOfATakeStartsWithTheOldestBatch() throws {
        let source = try #require(
            TakeSource.of(inventory: inventory, request: TakeRequest(productId: "milk", batchIds: ["m-new", "m-old"], outcome: .used))
        )
        #expect(source == TakeSource(name: "Milk", unit: .l, firstQuantity: 1_000, available: 3_000))
        #expect(source.check("3") == .quantity(3_000))
        #expect(source.check("3.001") == .tooMuch)
        #expect(source.check("0") == .problem(.notPositive))
        #expect(TakeSource.of(inventory: inventory, request: TakeRequest(productId: "milk", batchIds: ["gone"], outcome: .used)) == nil)
    }

    @Test func oneItemLeftNeedsNoDialogForAQuantity() {
        func source(_ unit: MeasureUnit?, _ available: Int) -> TakeSource {
            TakeSource(name: "Egg", unit: unit, firstQuantity: available, available: available)
        }
        #expect(source(nil, 1_000).oneLeft)
        #expect(source(.pcs, 1_000).oneLeft)
        #expect(source(.bottle, 1_000).oneLeft)
        #expect(!source(.pcs, 2_000).oneLeft)
        #expect(!source(.pcs, 500).oneLeft)
        #expect(!source(.kg, 1_000).oneLeft)
        #expect(!source(.l, 1_000).oneLeft)

        let eggs = Inventory.replay(
            Self.log(
                [
                    .productSaved(product: Product(id: "egg", name: "Egg", category: .other, unit: .pcs, barcode: nil, foodId: nil)),
                    Self.batch("e1", "egg", 1_000, "fridge", nil),
                ],
                prefix: "e"
            )
        )
        #expect(
            TakeRequest(productId: "egg", batchIds: ["e1"], outcome: .thrownAway).withoutDialog(eggs)
                == InventoryAction.Take(productId: "egg", batchIds: ["e1"], quantity: 1_000, outcome: .thrownAway)
        )
        // One litre of milk can be divided, and three litres are more than one item.
        #expect(TakeRequest(productId: "milk", batchIds: ["m-old"], outcome: .used).withoutDialog(inventory) == nil)
        #expect(TakeRequest(productId: "milk", batchIds: ["m-new", "m-old"], outcome: .used).withoutDialog(inventory) == nil)
    }
}
