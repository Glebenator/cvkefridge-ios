import Foundation

// The storage hint of a looked-up product. Rule 8 of `spec/rules.md`.
// The Android file `core/src/main/kotlin/com/cvke/fridge/core/StorageHints.kt` in cvkefridge-android has the same
// behaviour.

/// Where a storage hint comes from: the text on the package about how to keep the product, or the category tags of
/// Open Food Facts.
public enum StorageHintSource: String, CaseIterable, Sendable {
    case storageText
    case tags
}

/// The storage kind that a product lookup gives for a product, and its source.
public struct StorageHint: Hashable, Sendable {
    public let kind: StorageKind
    public let source: StorageHintSource

    public init(kind: StorageKind, source: StorageHintSource) {
        self.kind = kind
        self.source = source
    }
}

/// The table for the storage hint of a looked-up product, in the format of `spec/storage-hints.json`, and the rule
/// that uses it. `afterOpening` has the phrases, in lowercase, that start the instructions for an opened package.
/// `tags` has the category tags of Open Food Facts for each storage kind.
public struct StorageHints: Equatable, Sendable {
    public let afterOpening: [String]
    public let tags: [StorageKind: Set<String>]

    /// A temperature is frozen when it is this value or lower.
    public static let frozenMax = -6

    /// The highest temperature of a fridge.
    public static let fridgeMax = 10

    public init(afterOpening: [String], tags: [StorageKind: Set<String>]) {
        self.afterOpening = afterOpening
        self.tags = tags
    }

    /// The storage hint of a product: the storage kind of its storage text, and then the storage kind of its
    /// category tags. Nil when the two give no storage kind.
    public func of(storageText: String?, tags: [String]) -> StorageHint? {
        if let storageText, let kind = kindOfStorageText(storageText) {
            return StorageHint(kind: kind, source: .storageText)
        }
        if let kind = kindOfTags(tags) {
            return StorageHint(kind: kind, source: .tags)
        }
        return nil
    }

    /// The storage kind of a storage text, from the temperatures before the first phrase for an opened package. All
    /// temperatures frozen: the freezer. None frozen: the fridge when the highest is `fridgeMax` or lower, and the
    /// pantry above that. No temperature, or only some frozen: nil.
    public func kindOfStorageText(_ text: String) -> StorageKind? {
        let lower = Array(text.lowercased().unicodeScalars)
        var cut = lower.count
        for phrase in afterOpening {
            if let position = Self.firstIndex(of: Array(phrase.unicodeScalars), in: lower), position < cut {
                cut = position
            }
        }
        let found = Self.temperatures(Array(lower[0..<cut]))
        let frozen = found.filter { $0 <= Self.frozenMax }.count
        guard let highest = found.max(), frozen == 0 || frozen == found.count else {
            return nil
        }
        if frozen > 0 {
            return .freezer
        }
        return highest <= Self.fridgeMax ? .fridge : .pantry
    }

    /// The first storage kind of freezer, fridge, and pantry that has one of the tags, or nil.
    public func kindOfTags(_ tags: [String]) -> StorageKind? {
        for kind in Self.tagOrder {
            if let ofKind = self.tags[kind], tags.contains(where: { ofKind.contains($0) }) {
                return kind
            }
        }
        return nil
    }

    /// The Celsius temperatures of a text in lowercase, in the order of their degree signs (rule 8.1).
    public static func temperatures(_ text: String) -> [Int] {
        temperatures(Array(text.unicodeScalars))
    }

    /// The table in a JSON text in the format of `spec/storage-hints.json`: an object with an `afterOpening` list of
    /// texts and a `tags` object, which has a list of texts for each storage kind. A storage kind can be absent.
    /// Other keys of the object have no effect. It throws when the text has a different format, or a key of `tags`
    /// is not a storage kind.
    public static func decode(_ text: String) throws -> StorageHints {
        let file = try JSONDecoder().decode(HintsFile.self, from: Data(text.utf8))
        var tags: [StorageKind: Set<String>] = [:]
        for (key, list) in file.tags {
            guard let kind = StorageKind(rawValue: key) else {
                throw JSONFormatError("The table of storage hints has an unknown storage kind: \(key)")
            }
            tags[kind] = Set(list)
        }
        return StorageHints(afterOpening: file.afterOpening, tags: tags)
    }

    private static let tagOrder: [StorageKind] = [.freezer, .fridge, .pantry]
    private static let spaces: Set<Unicode.Scalar> = [" ", "\u{00A0}", "\u{202F}"]
    private static let minusSigns: Set<Unicode.Scalar> = ["-", "\u{2212}", "\u{2013}"]
    private static let degree: Unicode.Scalar = "\u{00B0}"
    private static let digits: ClosedRange<Unicode.Scalar> = "0"..."9"
    private static let letters: ClosedRange<Unicode.Scalar> = "a"..."z"

    /// The position after the last character before `end` that is not a space.
    private static func skipSpacesBack(_ text: [Unicode.Scalar], _ end: Int) -> Int {
        var position = end
        while position > 0 && spaces.contains(text[position - 1]) {
            position -= 1
        }
        return position
    }

    /// The start of the digits that end at `end`.
    private static func digitsBack(_ text: [Unicode.Scalar], _ end: Int) -> Int {
        var start = end
        while start > 0 && digits.contains(text[start - 1]) {
            start -= 1
        }
        return start
    }

    /// True when the character before `end`, with the spaces skipped, is a degree sign.
    private static func degreeBefore(_ text: [Unicode.Scalar], _ end: Int) -> Bool {
        let position = skipSpacesBack(text, end)
        return position > 0 && text[position - 1] == degree
    }

    /// The first position at which the phrase starts in the text, or nil.
    private static func firstIndex(of phrase: [Unicode.Scalar], in text: [Unicode.Scalar]) -> Int? {
        if phrase.isEmpty {
            return 0
        }
        if phrase.count > text.count {
            return nil
        }
        for start in 0...(text.count - phrase.count) {
            if text[start..<(start + phrase.count)].elementsEqual(phrase) {
                return start
            }
        }
        return nil
    }

    /// The digits before a degree sign are the value. A decimal part has no effect. A minus sign before the digits
    /// makes the value negative, unless it is the line between the two ends of a range. A temperature in Fahrenheit
    /// is not used.
    private static func temperatures(_ text: [Unicode.Scalar]) -> [Int] {
        var found: [Int] = []
        for at in text.indices {
            if text[at] != degree {
                continue
            }
            var after = at + 1
            while after < text.count && spaces.contains(text[after]) {
                after += 1
            }
            if after < text.count && text[after] == "f" && !(after + 1 < text.count && letters.contains(text[after + 1])) {
                continue
            }
            var end = skipSpacesBack(text, at)
            var start = digitsBack(text, end)
            if start == end {
                continue
            }
            if start >= 2 && (text[start - 1] == "." || text[start - 1] == ",") && digits.contains(text[start - 2]) {
                end = start - 1
                start = digitsBack(text, end)
            }
            if end - start > 3 {
                continue
            }
            var value = 0
            for digit in text[start..<end] {
                value = value * 10 + Int(digit.value) - 48
            }
            let sign = skipSpacesBack(text, start)
            if sign > 0 && minusSigns.contains(text[sign - 1]) {
                let before = skipSpacesBack(text, sign - 1)
                var ofRange = false
                if before > 0 {
                    let previous = text[before - 1]
                    ofRange = digits.contains(previous) || previous == degree
                        || (previous == "c" && degreeBefore(text, before - 1))
                }
                if !ofRange {
                    value = -value
                }
            }
            found.append(value)
        }
        return found
    }
}

/// The JSON shape of `spec/storage-hints.json`.
private struct HintsFile: Decodable {
    let afterOpening: [String]
    let tags: [String: [String]]
}
