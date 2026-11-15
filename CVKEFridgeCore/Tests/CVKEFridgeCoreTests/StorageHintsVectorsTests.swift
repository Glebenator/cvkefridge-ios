import Foundation
import Testing
@testable import CVKEFridgeCore

/// Runs each case of `spec/vectors/storage-hint.json` and `spec/vectors/storage-hints-table.json` (rule 8). The
/// Android test `StorageHintsVectorsTest` runs the same files.
struct StorageHintsVectorsTests {
    /// The storage hint of a case, in the JSON shape of its `expect` value.
    private func hint(_ hints: StorageHints, _ item: [String: Any]) throws -> [String: Any] {
        let storageText = try item.optionalString("storageText")
        let tags = try item.strings("tags")
        let found = hints.of(storageText: storageText, tags: tags)
        return [
            "kind": Vectors.orNull(found?.kind.rawValue),
            "source": Vectors.orNull(found?.source.rawValue),
        ]
    }

    @Test func theTemperaturesOfAText() throws {
        let file = try Vectors.load("storage-hint.json")
        for item in try Vectors.cases(file, "temperatures") {
            let name = try item.string("name")
            let text = try item.string("text")
            let actual: [String: Any] = ["celsius": StorageHints.temperatures(text.lowercased())]
            try Vectors.check(actual, item.object("expect"), "temperatures: \(name)")
        }
    }

    @Test func theStorageHintWithTheTableOfTheVectorFile() throws {
        let file = try Vectors.load("storage-hint.json")
        let hints = try StorageHints.decode(Vectors.canonical(file.object("hints")))
        for item in try Vectors.cases(file, "cases") {
            let name = try item.string("name")
            try Vectors.check(hint(hints, item), item.object("expect"), "cases: \(name)")
        }
    }

    @Test func theRealTableHasTheFactsOfTheVectorFile() throws {
        let hints = try StorageHints.decode(Vectors.text("storage-hints.json"))
        let file = try Vectors.load("storage-hints-table.json")
        var tags: [String: Any] = [:]
        for kind in StorageKind.allCases {
            tags[kind.rawValue] = hints.tags[kind]?.count ?? 0
        }
        let actual: [String: Any] = ["afterOpening": hints.afterOpening.count, "tags": tags]
        for item in try Vectors.cases(file, "facts") {
            let name = try item.string("name")
            try Vectors.check(actual, item.object("expect"), "facts: \(name)")
        }
    }

    @Test func theStorageHintsOfRealProductsWithTheRealTable() throws {
        let hints = try StorageHints.decode(Vectors.text("storage-hints.json"))
        let file = try Vectors.load("storage-hints-table.json")
        for item in try Vectors.cases(file, "cases") {
            let name = try item.string("name")
            try Vectors.check(hint(hints, item), item.object("expect"), "table: \(name)")
        }
    }

    @Test func aTagsKeyThatIsNotAStorageKindIsAnError() {
        let text = #"{"afterOpening":[],"tags":{"shelf":["en:breads"]}}"#
        #expect(throws: (any Error).self) { try StorageHints.decode(text) }
    }

    @Test func aStorageKindCanBeAbsentAndOtherKeysHaveNoEffect() throws {
        let text = #"{"note":"x","afterOpening":[],"tags":{"freezer":["en:ice-creams"]}}"#
        let hints = try StorageHints.decode(text)
        #expect(hints.of(storageText: nil, tags: ["en:ice-creams"]) == StorageHint(kind: .freezer, source: .tags))
        #expect(hints.of(storageText: nil, tags: ["en:yogurts"]) == nil)
    }
}
