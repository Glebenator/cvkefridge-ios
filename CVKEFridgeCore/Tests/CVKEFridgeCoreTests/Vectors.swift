import Foundation
import Testing
@testable import CVKEFridgeCore

/// Finds the copy of the shared specification in `spec/` and reads its files. The tests read the files by path, so
/// the package has no resources. The Android tests have a helper with the same function.
enum Vectors {
    /// The `spec/` folder. The root of the repository is four levels above this file:
    /// `CVKEFridgeCore/Tests/CVKEFridgeCoreTests/Vectors.swift`.
    static var specFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("spec")
    }

    /// The text of a file in `spec/`, for example `foods.json`.
    static func text(_ path: String) throws -> String {
        try String(contentsOf: specFolder.appendingPathComponent(path), encoding: .utf8)
    }

    /// The JSON object in a vector file, for example `calendar-date.json`. It throws when the file is missing.
    static func load(_ name: String) throws -> [String: Any] {
        let url = specFolder.appendingPathComponent("vectors").appendingPathComponent(name)
        let data = try Data(contentsOf: url)
        guard let found = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw VectorError("\(name) is not a JSON object")
        }
        return found
    }

    /// The cases of a section. It throws when the section is missing or has no cases, so that a renamed file or
    /// section cannot pass.
    static func cases(_ file: [String: Any], _ section: String) throws -> [[String: Any]] {
        let found = try file.objects(section)
        if found.isEmpty {
            throw VectorError("The section \(section) has no cases")
        }
        return found
    }

    /// The JSON text of an object or a list, with sorted keys. Two JSON values are equal when their texts are equal.
    static func canonical(_ value: Any) throws -> String {
        guard JSONSerialization.isValidJSONObject(value) else {
            throw VectorError("This is not a JSON object or list: \(value)")
        }
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    /// Records an issue when the calculated result is not equal to the complete `expect` value of a case.
    static func check(_ actual: [String: Any], _ expected: [String: Any], _ name: String) throws {
        let actualText = try canonical(actual)
        let expectedText = try canonical(expected)
        #expect(actualText == expectedText, "\(name)")
    }

    /// The value, or a JSON null for nil.
    static func orNull(_ value: Any?) -> Any {
        if let value {
            return value
        }
        return NSNull()
    }

    /// The date of a text in a vector file.
    static func date(_ text: String) throws -> CalendarDate {
        guard let found = CalendarDate.parse(text) else {
            throw VectorError("\(text) is not a date")
        }
        return found
    }

    /// A batch in the JSON shape of the vector files.
    static func batch(_ item: [String: Any]) throws -> Batch {
        let id = try item.string("id")
        let productId = try item.string("productId")
        let quantity = try item.int("quantity")
        let storageAreaId = try item.string("storageAreaId")
        let dateAdded = try date(item.string("dateAdded"))
        let expiryDate = try item.optionalString("expiryDate")
        let expirySource = try item.optionalString("expirySource")
        var expiry: ExpiryDate? = nil
        if let expiryDate, let expirySource {
            let expiryDay = try date(expiryDate)
            guard let source = ExpirySource(rawValue: expirySource) else {
                throw VectorError("\(expirySource) is not an expiry source")
            }
            expiry = ExpiryDate(date: expiryDay, source: source)
        } else if expiryDate != nil || expirySource != nil {
            throw VectorError("The batch \(id) has only one of expiryDate and expirySource")
        }
        return Batch(
            id: id,
            productId: productId,
            quantity: quantity,
            storageAreaId: storageAreaId,
            dateAdded: dateAdded,
            expiry: expiry
        )
    }
}

/// The error when a vector file does not have the expected shape.
struct VectorError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

/// Typed access to a JSON object from `JSONSerialization`. Each function throws when the key is missing or has a
/// different type.
extension Dictionary where Key == String, Value == Any {
    func field(_ key: String) throws -> Any {
        guard let found = self[key] else {
            throw VectorError("The key \(key) is missing")
        }
        return found
    }

    func string(_ key: String) throws -> String {
        guard let found = try field(key) as? String else {
            throw VectorError("\(key) is not text")
        }
        return found
    }

    /// A text, or nil for a JSON null. The key must be present.
    func optionalString(_ key: String) throws -> String? {
        let found = try field(key)
        if found is NSNull {
            return nil
        }
        guard let text = found as? String else {
            throw VectorError("\(key) is not text or null")
        }
        return text
    }

    func int(_ key: String) throws -> Int {
        guard let found = try field(key) as? Int else {
            throw VectorError("\(key) is not a whole number")
        }
        return found
    }

    func object(_ key: String) throws -> [String: Any] {
        guard let found = try field(key) as? [String: Any] else {
            throw VectorError("\(key) is not an object")
        }
        return found
    }

    /// A list of objects. The list can be empty.
    func objects(_ key: String) throws -> [[String: Any]] {
        guard let found = try field(key) as? [[String: Any]] else {
            throw VectorError("\(key) is not a list of objects")
        }
        return found
    }

    func strings(_ key: String) throws -> [String] {
        guard let found = try field(key) as? [String] else {
            throw VectorError("\(key) is not a list of texts")
        }
        return found
    }
}
