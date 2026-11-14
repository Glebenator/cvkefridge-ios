import Foundation

// Reads and writes a change as JSON text. Rule 7 of `spec/rules.md`.
// The Android file `core/src/main/kotlin/com/cvke/fridge/core/ChangeCodec.kt` in cvkefridge-android reads and writes
// the same JSON shape.

/// Reads and writes a change in the JSON shape of the changes in `spec/vectors/change-log.json`:
/// `{"id", "at", "origin", "body": {"type", ...}}`.
///
/// Each key of the shape must be present, except `note` of a product: changes from before the note have no `note`
/// key, and a missing `note` is `null`. Only `unit`, `barcode`, `foodId`, `note`, `expiryDate`, and `expirySource` can
/// be `null`. `expiryDate` and `expirySource` are both `null` or both have a value. Other keys have no effect.
/// The codec does not check the form of identifiers.
public enum ChangeCodec: Sendable {
    /// The change in a JSON text. It throws when the text is not a change: for example an unknown type, a date that
    /// is not valid, an unknown enum text, only one of the two expiry values, a missing key, or a wrong JSON type.
    public static func decode(_ text: String) throws -> Change {
        try JSONDecoder().decode(ChangeWire.self, from: Data(text.utf8)).change
    }

    /// The JSON text of a change. `decode(encode(change))` is equal to `change`.
    public static func encode(_ change: Change) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            let data = try encoder.encode(ChangeWire(change))
            return String(decoding: data, as: UTF8.self)
        } catch {
            preconditionFailure("A change always has a JSON form: \(error)")
        }
    }
}

/// The error when a JSON text does not have the expected shape.
struct JSONFormatError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

/// The keys of all objects in the JSON shape of a change.
private enum ChangeKey: String, CodingKey {
    case id
    case at
    case origin
    case body
    case type
    case product
    case productId
    case area
    case storageAreaId
    case batch
    case batchId
    case quantity
    case dateAdded
    case expiryDate
    case expirySource
    case date
    case changeId
    case name
    case kind
    case category
    case unit
    case barcode
    case foodId
    case note
}

/// A change with its JSON form.
private struct ChangeWire: Codable {
    let change: Change

    init(_ change: Change) {
        self.change = change
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: ChangeKey.self)
        let id = try container.decode(String.self, forKey: .id)
        let at = try container.decode(Int.self, forKey: .at)
        let origin = try container.decode(String.self, forKey: .origin)
        let body = try container.nestedContainer(keyedBy: ChangeKey.self, forKey: .body)
        let typeName = try body.decode(String.self, forKey: .type)
        let value: ChangeBody
        switch typeName {
        case "productSaved":
            let item = try body.nestedContainer(keyedBy: ChangeKey.self, forKey: .product)
            let product = try decodeProduct(item)
            value = .productSaved(product: product)
        case "productDeleted":
            let productId = try body.decode(String.self, forKey: .productId)
            value = .productDeleted(productId: productId)
        case "storageAreaSaved":
            let item = try body.nestedContainer(keyedBy: ChangeKey.self, forKey: .area)
            let areaId = try item.decode(String.self, forKey: .id)
            let name = try item.decode(String.self, forKey: .name)
            let kind = try decodeEnum(StorageKind.self, item, .kind)
            value = .storageAreaSaved(id: areaId, name: name, kind: kind)
        case "storageAreaDeleted":
            let storageAreaId = try body.decode(String.self, forKey: .storageAreaId)
            value = .storageAreaDeleted(storageAreaId: storageAreaId)
        case "batchAdded":
            let item = try body.nestedContainer(keyedBy: ChangeKey.self, forKey: .batch)
            let batch = try decodeBatch(item)
            value = .batchAdded(batch: batch)
        case "batchEdited":
            let batchId = try body.decode(String.self, forKey: .batchId)
            let quantity = try body.decode(Int.self, forKey: .quantity)
            let storageAreaId = try body.decode(String.self, forKey: .storageAreaId)
            let dateAdded = try decodeDate(body, .dateAdded)
            let expiry = try decodeExpiry(body)
            value = .batchEdited(
                batchId: batchId,
                quantity: quantity,
                storageAreaId: storageAreaId,
                dateAdded: dateAdded,
                expiry: expiry
            )
        case "batchUsed":
            let batchId = try body.decode(String.self, forKey: .batchId)
            let quantity = try body.decode(Int.self, forKey: .quantity)
            let date = try decodeDate(body, .date)
            value = .batchUsed(batchId: batchId, quantity: quantity, date: date)
        case "batchThrownAway":
            let batchId = try body.decode(String.self, forKey: .batchId)
            let quantity = try body.decode(Int.self, forKey: .quantity)
            let date = try decodeDate(body, .date)
            value = .batchThrownAway(batchId: batchId, quantity: quantity, date: date)
        case "batchDeleted":
            let batchId = try body.decode(String.self, forKey: .batchId)
            value = .batchDeleted(batchId: batchId)
        case "changeUndone":
            let changeId = try body.decode(String.self, forKey: .changeId)
            value = .changeUndone(changeId: changeId)
        default:
            throw JSONFormatError("Unknown change type: \(typeName)")
        }
        change = Change(id: id, at: at, origin: origin, body: value)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: ChangeKey.self)
        try container.encode(change.id, forKey: .id)
        try container.encode(change.at, forKey: .at)
        try container.encode(change.origin, forKey: .origin)
        var body = container.nestedContainer(keyedBy: ChangeKey.self, forKey: .body)
        switch change.body {
        case .productSaved(let product):
            try body.encode("productSaved", forKey: .type)
            var item = body.nestedContainer(keyedBy: ChangeKey.self, forKey: .product)
            try item.encode(product.id, forKey: .id)
            try item.encode(product.name, forKey: .name)
            try item.encode(product.category.rawValue, forKey: .category)
            try encodeOrNull(&item, product.unit?.rawValue, .unit)
            try encodeOrNull(&item, product.barcode, .barcode)
            try encodeOrNull(&item, product.foodId, .foodId)
            try encodeOrNull(&item, product.note, .note)
        case .productDeleted(let productId):
            try body.encode("productDeleted", forKey: .type)
            try body.encode(productId, forKey: .productId)
        case .storageAreaSaved(let areaId, let name, let kind):
            try body.encode("storageAreaSaved", forKey: .type)
            var item = body.nestedContainer(keyedBy: ChangeKey.self, forKey: .area)
            try item.encode(areaId, forKey: .id)
            try item.encode(name, forKey: .name)
            try item.encode(kind.rawValue, forKey: .kind)
        case .storageAreaDeleted(let storageAreaId):
            try body.encode("storageAreaDeleted", forKey: .type)
            try body.encode(storageAreaId, forKey: .storageAreaId)
        case .batchAdded(let batch):
            try body.encode("batchAdded", forKey: .type)
            var item = body.nestedContainer(keyedBy: ChangeKey.self, forKey: .batch)
            try item.encode(batch.id, forKey: .id)
            try item.encode(batch.productId, forKey: .productId)
            try item.encode(batch.quantity, forKey: .quantity)
            try item.encode(batch.storageAreaId, forKey: .storageAreaId)
            try item.encode(batch.dateAdded.text, forKey: .dateAdded)
            try encodeExpiry(&item, batch.expiry)
        case .batchEdited(let batchId, let quantity, let storageAreaId, let dateAdded, let expiry):
            try body.encode("batchEdited", forKey: .type)
            try body.encode(batchId, forKey: .batchId)
            try body.encode(quantity, forKey: .quantity)
            try body.encode(storageAreaId, forKey: .storageAreaId)
            try body.encode(dateAdded.text, forKey: .dateAdded)
            try encodeExpiry(&body, expiry)
        case .batchUsed(let batchId, let quantity, let date):
            try body.encode("batchUsed", forKey: .type)
            try body.encode(batchId, forKey: .batchId)
            try body.encode(quantity, forKey: .quantity)
            try body.encode(date.text, forKey: .date)
        case .batchThrownAway(let batchId, let quantity, let date):
            try body.encode("batchThrownAway", forKey: .type)
            try body.encode(batchId, forKey: .batchId)
            try body.encode(quantity, forKey: .quantity)
            try body.encode(date.text, forKey: .date)
        case .batchDeleted(let batchId):
            try body.encode("batchDeleted", forKey: .type)
            try body.encode(batchId, forKey: .batchId)
        case .changeUndone(let changeId):
            try body.encode("changeUndone", forKey: .type)
            try body.encode(changeId, forKey: .changeId)
        }
    }
}

/// A product: `{"id", "name", "category", "unit", "barcode", "foodId", "note"}`. The key `note` can be missing.
private func decodeProduct(_ container: KeyedDecodingContainer<ChangeKey>) throws -> Product {
    let id = try container.decode(String.self, forKey: .id)
    let name = try container.decode(String.self, forKey: .name)
    let category = try decodeEnum(Category.self, container, .category)
    let unitText = try decodeNullableString(container, .unit)
    var unit: MeasureUnit? = nil
    if let unitText {
        guard let known = MeasureUnit(rawValue: unitText) else {
            throw JSONFormatError("unit has an unknown value: \(unitText)")
        }
        unit = known
    }
    let barcode = try decodeNullableString(container, .barcode)
    let foodId = try decodeNullableString(container, .foodId)
    let note = try container.contains(.note) ? decodeNullableString(container, .note) : nil
    return Product(id: id, name: name, category: category, unit: unit, barcode: barcode, foodId: foodId, note: note)
}

/// A batch: `{"id", "productId", "quantity", "storageAreaId", "dateAdded", "expiryDate", "expirySource"}`.
private func decodeBatch(_ container: KeyedDecodingContainer<ChangeKey>) throws -> Batch {
    let id = try container.decode(String.self, forKey: .id)
    let productId = try container.decode(String.self, forKey: .productId)
    let quantity = try container.decode(Int.self, forKey: .quantity)
    let storageAreaId = try container.decode(String.self, forKey: .storageAreaId)
    let dateAdded = try decodeDate(container, .dateAdded)
    let expiry = try decodeExpiry(container)
    return Batch(
        id: id,
        productId: productId,
        quantity: quantity,
        storageAreaId: storageAreaId,
        dateAdded: dateAdded,
        expiry: expiry
    )
}

/// The expiry date from the keys `expiryDate` and `expirySource`. Both are null, or both have a value.
private func decodeExpiry(_ container: KeyedDecodingContainer<ChangeKey>) throws -> ExpiryDate? {
    let dateText = try decodeNullableString(container, .expiryDate)
    let sourceText = try decodeNullableString(container, .expirySource)
    if dateText == nil && sourceText == nil {
        return nil
    }
    guard let dateText, let sourceText else {
        throw JSONFormatError("expiryDate and expirySource must both have a value, or both be null")
    }
    guard let date = CalendarDate.parse(dateText) else {
        throw JSONFormatError("expiryDate is not a date: \(dateText)")
    }
    guard let source = ExpirySource(rawValue: sourceText) else {
        throw JSONFormatError("expirySource has an unknown value: \(sourceText)")
    }
    return ExpiryDate(date: date, source: source)
}

/// A date in the form `YYYY-MM-DD`.
private func decodeDate(_ container: KeyedDecodingContainer<ChangeKey>, _ key: ChangeKey) throws -> CalendarDate {
    let text = try container.decode(String.self, forKey: key)
    guard let date = CalendarDate.parse(text) else {
        throw JSONFormatError("\(key.stringValue) is not a date: \(text)")
    }
    return date
}

/// An enum value from its key text, for example `fridge`.
private func decodeEnum<T: RawRepresentable>(
    _ type: T.Type,
    _ container: KeyedDecodingContainer<ChangeKey>,
    _ key: ChangeKey
) throws -> T where T.RawValue == String {
    let text = try container.decode(String.self, forKey: key)
    guard let value = T(rawValue: text) else {
        throw JSONFormatError("\(key.stringValue) has an unknown value: \(text)")
    }
    return value
}

/// A text or null. The key must be present.
private func decodeNullableString(_ container: KeyedDecodingContainer<ChangeKey>, _ key: ChangeKey) throws -> String? {
    guard container.contains(key) else {
        throw JSONFormatError("The key \(key.stringValue) is missing")
    }
    if try container.decodeNil(forKey: key) {
        return nil
    }
    return try container.decode(String.self, forKey: key)
}

/// Writes `expiryDate` and `expirySource`, both null when there is no expiry date.
private func encodeExpiry(_ container: inout KeyedEncodingContainer<ChangeKey>, _ expiry: ExpiryDate?) throws {
    try encodeOrNull(&container, expiry?.date.text, .expiryDate)
    try encodeOrNull(&container, expiry?.source.rawValue, .expirySource)
}

/// Writes a text, or null for nil.
private func encodeOrNull(
    _ container: inout KeyedEncodingContainer<ChangeKey>,
    _ value: String?,
    _ key: ChangeKey
) throws {
    if let value {
        try container.encode(value, forKey: key)
    } else {
        try container.encodeNil(forKey: key)
    }
}
