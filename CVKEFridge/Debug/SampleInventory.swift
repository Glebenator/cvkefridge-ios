#if DEBUG
import CVKEFridgeFeatures
import Foundation

/// The sample of the debug build: a change log with food in each freshness, and a history of food that was used and
/// thrown away in the last five weeks, for work on the screens. It is not in the release build. Each date is a number
/// of days from today, so the days left and the days of the history come from the same calculation as for real food.
/// The changes have the origin `InventoryWork.sampleOrigin`, and the screens then show that the food is a sample.
///
/// The Android file `app/src/debug/java/com/cvke/fridge/SampleInventory.kt` has the same sample.
enum SampleInventory {
    private static let pantry = "sample-pantry"

    /// One batch of the sample. `quantity` is in thousandths. `added` is the date added, in days before today.
    /// `expires` is the expiry date in days from today, or nil for no expiry date.
    private struct Entry {
        let product: String
        let quantity: Int
        let area: String
        let added: Int
        let expires: Int?
        var source: ExpirySource = .printed
    }

    /// A use or a throw away of a batch of the sample. `quantity` is in thousandths, `daysAgo` in days before today.
    private struct Take {
        let outcome: Outcome
        let quantity: Int
        let daysAgo: Int
    }

    /// A batch of the sample that ended, or partly ended, before today, with its uses and throw aways.
    private struct Past {
        let entry: Entry
        let takes: [Take]
    }

    private static func product(
        _ id: String,
        _ name: String,
        _ category: CVKEFridgeCore.Category,
        _ unit: MeasureUnit?,
        foodId: String? = nil,
        note: String? = nil
    ) -> Product {
        Product(id: id, name: name, category: category, unit: unit, barcode: nil, foodId: foodId, note: note)
    }

    private static let products: [Product] = [
        product("sample-milk", "Whole milk", .dairy, .l, note: "Opened on Tuesday"),
        product("sample-chicken", "Chicken thighs", .meat, .g),
        product("sample-spinach", "Baby spinach", .produce, .g),
        product("sample-yoghurt", "Greek yoghurt", .dairy, .pcs),
        product("sample-lasagne", "Leftover lasagne with roasted vegetables and béchamel sauce", .leftovers, nil),
        product("sample-juice", "Orange juice", .beverage, .bottle),
        product("sample-cheddar", "Cheddar", .dairy, .g),
        product("sample-eggs", "Eggs", .other, .pcs),
        product("sample-bread", "Sourdough bread", .bakery, .slice),
        product("sample-peas", "Garden peas", .produce, .kg),
        product("sample-ketchup", "Tomato ketchup", .condiment, .bottle),
        product("sample-rice", "Basmati rice", .other, .pack),
        // Food that the person had before and has none of now. It is only in the history.
        product("sample-strawberries", "Strawberries", .produce, .g, foodId: "fk-481"),
        product("sample-bananas", "Bananas", .produce, .pcs, foodId: "fk-251"),
        product("sample-salmon", "Salmon fillet", .meat, .g),
        product("sample-curry", "Leftover curry", .leftovers, nil, note: "Made on Sunday. Spicy, so not for the children."),
        product("sample-croissants", "Croissants", .bakery, .pcs),
    ]

    private static let fridge = StorageArea.fridge.id
    private static let freezer = StorageArea.freezer.id

    private static let entries: [Entry] = [
        Entry(product: "sample-chicken", quantity: 600_000, area: fridge, added: 3, expires: -1, source: .estimated),
        Entry(product: "sample-spinach", quantity: 200_000, area: fridge, added: 4, expires: 0, source: .estimated),
        Entry(product: "sample-milk", quantity: 1_000, area: fridge, added: 6, expires: 1),
        Entry(product: "sample-milk", quantity: 2_000, area: fridge, added: 1, expires: 8),
        Entry(product: "sample-yoghurt", quantity: 4_000, area: fridge, added: 5, expires: 2),
        Entry(product: "sample-lasagne", quantity: 2_000, area: fridge, added: 1, expires: 3, source: .estimated),
        Entry(product: "sample-juice", quantity: 1_000, area: fridge, added: 2, expires: 5),
        Entry(product: "sample-eggs", quantity: 10_000, area: fridge, added: 7, expires: 14),
        Entry(product: "sample-cheddar", quantity: 350_000, area: fridge, added: 10, expires: 21),
        Entry(product: "sample-bread", quantity: 8_000, area: freezer, added: 20, expires: 70, source: .estimated),
        Entry(product: "sample-peas", quantity: 1_500, area: freezer, added: 40, expires: nil),
        Entry(product: "sample-ketchup", quantity: 1_000, area: pantry, added: 60, expires: 200),
        Entry(product: "sample-rice", quantity: 2_000, area: pantry, added: 30, expires: nil),
    ]

    private static func used(_ quantity: Int, _ daysAgo: Int) -> Take {
        Take(outcome: .used, quantity: quantity, daysAgo: daysAgo)
    }

    private static func thrownAway(_ quantity: Int, _ daysAgo: Int) -> Take {
        Take(outcome: .thrownAway, quantity: quantity, daysAgo: daysAgo)
    }

    private static let past: [Past] = [
        Past(
            entry: Entry(product: "sample-croissants", quantity: 4_000, area: fridge, added: 35, expires: -32),
            takes: [used(2_000, 34), thrownAway(2_000, 31)]
        ),
        Past(entry: Entry(product: "sample-milk", quantity: 1_000, area: fridge, added: 27, expires: -20), takes: [used(1_000, 22)]),
        Past(
            entry: Entry(product: "sample-strawberries", quantity: 400_000, area: fridge, added: 30, expires: -28, source: .estimated),
            takes: [thrownAway(400_000, 25)]
        ),
        Past(
            entry: Entry(product: "sample-curry", quantity: 1_000, area: fridge, added: 20, expires: -16, source: .estimated),
            takes: [thrownAway(1_000, 15)]
        ),
        Past(entry: Entry(product: "sample-salmon", quantity: 300_000, area: fridge, added: 16, expires: -14), takes: [used(300_000, 14)]),
        Past(
            entry: Entry(product: "sample-spinach", quantity: 200_000, area: fridge, added: 18, expires: -12),
            takes: [used(50_000, 14), thrownAway(150_000, 12)]
        ),
        Past(entry: Entry(product: "sample-milk", quantity: 1_000, area: fridge, added: 13, expires: -6), takes: [used(1_000, 8)]),
        Past(entry: Entry(product: "sample-bananas", quantity: 6_000, area: fridge, added: 9, expires: nil), takes: [used(3_000, 7), used(3_000, 4)]),
        Past(
            entry: Entry(product: "sample-strawberries", quantity: 400_000, area: fridge, added: 12, expires: -10, source: .estimated),
            takes: [thrownAway(400_000, 6)]
        ),
        Past(entry: Entry(product: "sample-yoghurt", quantity: 2_000, area: fridge, added: 8, expires: -1), takes: [thrownAway(2_000, 1)]),
        Past(entry: Entry(product: "sample-juice", quantity: 1_000, area: fridge, added: 9, expires: 3), takes: [used(1_000, 0)]),
    ]

    /// The change log of the sample for the date `today`.
    static func changes(today: CalendarDate) -> [Change] {
        func date(_ days: Int) -> CalendarDate {
            today.plusDays(days) ?? today
        }
        func batch(_ id: String, _ entry: Entry) -> ChangeBody {
            let expiry = entry.expires.map { ExpiryDate(date: date($0), source: entry.source) }
            return .batchAdded(
                batch: Batch(
                    id: id,
                    productId: entry.product,
                    quantity: entry.quantity,
                    storageAreaId: entry.area,
                    dateAdded: date(-entry.added),
                    expiry: expiry
                )
            )
        }
        var bodies: [ChangeBody] = [.storageAreaSaved(id: pantry, name: "Pantry", kind: .pantry)]
        bodies += products.map { .productSaved(product: $0) }
        bodies += entries.enumerated().map { batch("sample-batch-\($0.offset + 1)", $0.element) }
        bodies += past.enumerated().map { batch("sample-past-\($0.offset + 1)", $0.element.entry) }
        // The uses and throw aways in the order of their dates, as a person makes them. Takes of the same day keep
        // their order.
        let takes = past.enumerated()
            .flatMap { index, batch in batch.takes.map { (batchId: "sample-past-\(index + 1)", take: $0) } }
            .enumerated()
            .sorted { first, second in
                first.element.take.daysAgo != second.element.take.daysAgo
                    ? first.element.take.daysAgo > second.element.take.daysAgo
                    : first.offset < second.offset
            }
            .map(\.element)
        for item in takes {
            switch item.take.outcome {
            case .used:
                bodies.append(.batchUsed(batchId: item.batchId, quantity: item.take.quantity, date: date(-item.take.daysAgo)))
            case .thrownAway:
                bodies.append(.batchThrownAway(batchId: item.batchId, quantity: item.take.quantity, date: date(-item.take.daysAgo)))
            }
        }
        return bodies.enumerated().map { index, body in
            Change(id: "sample-change-\(index + 1)", at: index, origin: InventoryWork.sampleOrigin, body: body)
        }
    }
}
#endif
