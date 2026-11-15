import Foundation

// The actions of the person and their changes.
// The Android file `app/src/main/java/com/cvke/fridge/inventory/InventoryAction.kt` in cvkefridge-android has the same
// behaviour. `NoticeMessage` has no message for the test reminder of the Android debug build: the reminders of iOS
// are different, and the app adds its own message for them.

/// One thing that the person does to the inventory. `InventoryActions.plan` makes its changes.
public enum InventoryAction: Hashable, Sendable {
    /// Adds a batch. With no product identifier, it also adds the product.
    case addFood(AddFood)
    /// Replaces the values of a product.
    case saveProduct(SaveProduct)
    /// Replaces the values of a batch.
    case editBatch(EditBatch)
    /// Records a quantity of a product as used or as thrown away.
    case take(Take)
    /// Deletes batches that were a mistake. When the product has no other batch, active or ended, the product was
    /// the mistake, and the action deletes the product.
    case deleteBatches(productId: String, batchIds: [String])
    /// Deletes a product that was a mistake, with its batches and their history.
    case deleteProduct(productId: String)
    /// Adds a storage area, or replaces the name and the storage kind of a storage area.
    case saveStorageArea(SaveStorageArea)
    case deleteStorageArea(id: String)
    /// Gives a batch a later expiry date, because the food is still good. The date is a chosen date: not from the
    /// package and not an estimate. See `LaterExpiry`.
    case moveExpiry(batchId: String, date: CalendarDate)
    /// Undoes the changes of an earlier action.
    case undo(changeIds: [String])

    /// The values of `addFood`. `quantity` is in thousandths. `barcode` is the barcode of a scan, or nil: see
    /// `InventoryActions.plan` for the product that gets it. `storageText` is the storage text of a scan, or nil.
    public struct AddFood: Hashable, Sendable {
        public var productId: String?
        public var name: String
        public var category: CVKEFridgeCore.Category
        public var unit: MeasureUnit?
        public var foodId: String?
        public var quantity: Int
        public var storageAreaId: String
        public var expiry: ExpiryDate?
        public var barcode: String?
        public var note: String?
        public var storageText: String?

        public init(
            productId: String?,
            name: String,
            category: CVKEFridgeCore.Category,
            unit: MeasureUnit?,
            foodId: String?,
            quantity: Int,
            storageAreaId: String,
            expiry: ExpiryDate?,
            barcode: String? = nil,
            note: String? = nil,
            storageText: String? = nil
        ) {
            self.productId = productId
            self.name = name
            self.category = category
            self.unit = unit
            self.foodId = foodId
            self.quantity = quantity
            self.storageAreaId = storageAreaId
            self.expiry = expiry
            self.barcode = barcode
            self.note = note
            self.storageText = storageText
        }
    }

    /// The values of `saveProduct`.
    public struct SaveProduct: Hashable, Sendable {
        public var product: Product

        public init(product: Product) {
            self.product = product
        }
    }

    /// The values of `editBatch`. `quantity` is in thousandths.
    public struct EditBatch: Hashable, Sendable {
        public var batchId: String
        public var quantity: Int
        public var storageAreaId: String
        public var dateAdded: CalendarDate
        public var expiry: ExpiryDate?

        public init(batchId: String, quantity: Int, storageAreaId: String, dateAdded: CalendarDate, expiry: ExpiryDate?) {
            self.batchId = batchId
            self.quantity = quantity
            self.storageAreaId = storageAreaId
            self.dateAdded = dateAdded
            self.expiry = expiry
        }
    }

    /// The values of `take`. The quantity, in thousandths, comes from the batches with the `batchIds`, oldest batch
    /// first.
    public struct Take: Hashable, Sendable {
        public var productId: String
        public var batchIds: [String]
        public var quantity: Int
        public var outcome: Outcome

        public init(productId: String, batchIds: [String], quantity: Int, outcome: Outcome) {
            self.productId = productId
            self.batchIds = batchIds
            self.quantity = quantity
            self.outcome = outcome
        }
    }

    /// The values of `saveStorageArea`. `id` is the storage area to change, or nil for a new storage area.
    public struct SaveStorageArea: Hashable, Sendable {
        public var id: String?
        public var name: String
        public var kind: StorageKind

        public init(id: String?, name: String, kind: StorageKind) {
            self.id = id
            self.name = name
            self.kind = kind
        }
    }
}

/// What the app tells the person after an action. The app makes the text.
public enum NoticeMessage: Hashable, Sendable {
    case added(name: String)
    /// `quantity` is the quantity that the batches gave, in thousandths.
    case taken(name: String, quantity: Int, unit: MeasureUnit?, outcome: Outcome)
    case foodDeleted(name: String)
    /// `count` is the number of batches.
    case batchDeleted(name: String, count: Int)
    /// A batch of the food got a new expiry date.
    case expiryMoved(name: String, date: CalendarDate)
    case storageAreaDeleted(name: String)
    /// The change log could not be written.
    case saveFailed
    /// The inventory changed, and the action is not possible now.
    case refused(RejectionReason)
    /// The person turned reminders on from the offer on Home.
    case remindersOn
    /// Home does not offer reminders again. The switch is in the settings.
    case remindersInSettings
    /// The reminder settings could not be written.
    case settingsNotSaved
    /// The person removed the photo of a product.
    case photoRemoved
    /// The picture that the person selected could not become a photo.
    case photoFailed
    /// The photo file could not be removed.
    case photoNotRemoved
}

/// The result of `InventoryActions.plan`.
public enum Planned: Hashable, Sendable {
    /// The changes of the action.
    case changes(Changes)
    /// The action has nothing to change.
    case refused(RejectionReason)

    /// The changes of the action, in their order. `message` is what to tell the person when the changes are in the
    /// log, or nil for nothing. `undoable` is true when the person can undo the action from the message.
    public struct Changes: Hashable, Sendable {
        public let bodies: [ChangeBody]
        public let message: NoticeMessage?
        public let undoable: Bool

        public init(bodies: [ChangeBody], message: NoticeMessage? = nil, undoable: Bool = false) {
            self.bodies = bodies
            self.message = message
            self.undoable = undoable
        }
    }

    /// The changes, or nil when the action is refused.
    public var plannedChanges: Changes? {
        if case .changes(let changes) = self {
            return changes
        }
        return nil
    }
}

/// Makes the changes of an action. The replay of the core decides if the changes can apply.
public enum InventoryActions {
    /// The changes for the `action` on the `inventory`.
    ///
    /// - Parameters:
    ///   - today: The date in the time zone of the device.
    ///   - newId: Makes a random identifier.
    ///   - normalizeBarcode: Gives a barcode in the form of the lookup, or nil when the text is not a barcode. The
    ///     default is the normalize function of the barcodes of the lookup (`Barcodes.normalize`).
    public static func plan(
        _ action: InventoryAction,
        inventory: Inventory,
        today: CalendarDate,
        newId: () -> String,
        normalizeBarcode: (String) -> String? = Barcodes.normalize
    ) -> Planned {
        switch action {
        case .addFood(let add):
            return addFood(add, inventory: inventory, today: today, newId: newId, normalizeBarcode: normalizeBarcode)
        case .saveProduct(let save):
            return .changes(Planned.Changes(bodies: [.productSaved(product: save.product)]))
        case .editBatch(let edit):
            return .changes(
                Planned.Changes(bodies: [
                    .batchEdited(
                        batchId: edit.batchId,
                        quantity: edit.quantity,
                        storageAreaId: edit.storageAreaId,
                        dateAdded: edit.dateAdded,
                        expiry: edit.expiry
                    ),
                ])
            )
        case .take(let take):
            return self.take(take, inventory: inventory, today: today)
        case .moveExpiry(let batchId, let date):
            return moveExpiry(batchId: batchId, date: date, inventory: inventory)
        case .deleteBatches(let productId, let batchIds):
            return deleteBatches(productId: productId, batchIds: batchIds, inventory: inventory)
        case .deleteProduct(let productId):
            let name = productName(productId, inventory)
            return .changes(
                Planned.Changes(
                    bodies: [.productDeleted(productId: productId)],
                    message: .foodDeleted(name: name),
                    undoable: true
                )
            )
        case .saveStorageArea(let save):
            return .changes(
                Planned.Changes(bodies: [.storageAreaSaved(id: save.id ?? newId(), name: save.name, kind: save.kind)])
            )
        case .deleteStorageArea(let id):
            let name = inventory.storageAreas.first(where: { $0.id == id })?.name ?? ""
            return .changes(
                Planned.Changes(
                    bodies: [.storageAreaDeleted(storageAreaId: id)],
                    message: .storageAreaDeleted(name: name),
                    undoable: true
                )
            )
        case .undo(let changeIds):
            if changeIds.isEmpty {
                return .refused(.unknownChange)
            }
            return .changes(Planned.Changes(bodies: changeIds.map { .changeUndone(changeId: $0) }))
        }
    }

    /// A barcode belongs to one product. A new product gets the barcode of the action. A product in the inventory
    /// with no barcode gets it also, so that the next scan finds it. The barcode is not saved when another product has
    /// it: the scan of that barcode then finds the other product, as before.
    private static func addFood(
        _ action: InventoryAction.AddFood,
        inventory: Inventory,
        today: CalendarDate,
        newId: () -> String,
        normalizeBarcode: (String) -> String?
    ) -> Planned {
        let productId = action.productId ?? newId()
        let barcode = action.barcode.flatMap { code in
            inventory.products.contains(where: { other in
                other.id != productId && other.barcode.flatMap(normalizeBarcode) == code
            }) ? nil : code
        }
        let existing = action.productId.flatMap { id in inventory.products.first(where: { $0.id == id }) }
        // A product in the inventory gets the barcode when it has none, and the note and the storage text when the
        // action has them.
        let changed = existing.map { product in
            Product(
                id: product.id,
                name: product.name,
                category: product.category,
                unit: product.unit,
                barcode: product.barcode ?? barcode,
                foodId: product.foodId,
                note: action.note ?? product.note,
                storageText: action.storageText ?? product.storageText
            )
        }
        let saved: Product?
        if action.productId == nil {
            saved = Product(
                id: productId,
                name: action.name,
                category: action.category,
                unit: action.unit,
                barcode: barcode,
                foodId: action.foodId,
                note: action.note,
                storageText: action.storageText
            )
        } else if changed != existing {
            saved = changed
        } else {
            saved = nil
        }
        let batch = Batch(
            id: newId(),
            productId: productId,
            quantity: action.quantity,
            storageAreaId: action.storageAreaId,
            dateAdded: today,
            expiry: action.expiry
        )
        var bodies: [ChangeBody] = []
        if let saved {
            bodies.append(.productSaved(product: saved))
        }
        bodies.append(.batchAdded(batch: batch))
        return .changes(Planned.Changes(bodies: bodies, message: .added(name: action.name), undoable: true))
    }

    private static func take(_ action: InventoryAction.Take, inventory: Inventory, today: CalendarDate) -> Planned {
        guard let product = inventory.products.first(where: { $0.id == action.productId }) else {
            return .refused(.unknownProduct)
        }
        guard let first = action.batchIds.first else {
            return .refused(.unknownBatch)
        }
        let wanted = Set(action.batchIds)
        let plan = UseFirst.plan(
            inventory.batches.filter { wanted.contains($0.id) },
            productId: action.productId,
            quantity: action.quantity
        )
        // With an empty plan, the replay gives the reason: the batch is not there, it has ended, or the quantity is 0.
        var takes = plan.takes.map { ($0.batchId, $0.quantity) }
        if takes.isEmpty {
            takes = [(first, action.quantity)]
        }
        let bodies: [ChangeBody] = takes.map { batchId, quantity in
            switch action.outcome {
            case .used:
                return .batchUsed(batchId: batchId, quantity: quantity, date: today)
            case .thrownAway:
                return .batchThrownAway(batchId: batchId, quantity: quantity, date: today)
            }
        }
        let taken = plan.takes.reduce(0) { $0 + $1.quantity }
        return .changes(
            Planned.Changes(
                bodies: bodies,
                message: .taken(name: product.name, quantity: taken, unit: product.unit, outcome: action.outcome),
                undoable: true
            )
        )
    }

    private static func moveExpiry(batchId: String, date: CalendarDate, inventory: Inventory) -> Planned {
        guard let batch = inventory.batches.first(where: { $0.id == batchId }) else {
            return .refused(.unknownBatch)
        }
        let name = productName(batch.productId, inventory)
        // The date is not from the package and not from the table of foods (rule 5 of the shared specification).
        let expiry = ExpiryDate(date: date, source: .chosen)
        return .changes(
            Planned.Changes(
                bodies: [
                    .batchEdited(
                        batchId: batch.id,
                        quantity: batch.quantity,
                        storageAreaId: batch.storageAreaId,
                        dateAdded: batch.dateAdded,
                        expiry: expiry
                    ),
                ],
                message: .expiryMoved(name: name, date: date),
                undoable: true
            )
        )
    }

    private static func deleteBatches(productId: String, batchIds: [String], inventory: Inventory) -> Planned {
        if batchIds.isEmpty {
            return .refused(.unknownBatch)
        }
        let name = productName(productId, inventory)
        let wanted = Set(batchIds)
        let others = inventory.batches.contains(where: { $0.productId == productId && !wanted.contains($0.id) })
        if others {
            return .changes(
                Planned.Changes(
                    bodies: batchIds.map { .batchDeleted(batchId: $0) },
                    message: .batchDeleted(name: name, count: batchIds.count),
                    undoable: true
                )
            )
        }
        return .changes(
            Planned.Changes(
                bodies: [.productDeleted(productId: productId)],
                message: .foodDeleted(name: name),
                undoable: true
            )
        )
    }

    /// The name of the product, or an empty text when the product is not there.
    private static func productName(_ productId: String, _ inventory: Inventory) -> String {
        inventory.products.first(where: { $0.id == productId })?.name ?? ""
    }
}
