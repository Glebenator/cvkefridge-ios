import Foundation

// The storage tips of a food: the storage text of its package, and the general advice of the table of foods. The
// shared specification has the two sources (rule 1 and rule 4 of `spec/rules.md`). It has no rules yet for what a
// screen shows from them. These are the smallest rules that work, and they must go into the specification, so that the
// two apps show the same (ADR 0012 in the cvkefridge repository).
// The Android file `app/src/main/java/com/cvke/fridge/inventory/StorageAdvice.kt` in cvkefridge-android has the same
// behaviour.

/// The storage text that the app saves with a product.
public enum StorageTexts {
    /// The largest number of characters of a saved storage text.
    public static let maxLength = 500

    /// The characters that separate the words: the ASCII white space of a Java regular expression `\s`, as on
    /// Android. A no-break space stays, so that "-18 °C" stays on one line.
    private static let separators: Set<Unicode.Scalar> = [" ", "\t", "\n", "\u{0B}", "\u{0C}", "\r"]

    /// The text with one space between words and no spaces at the ends, or nil for no text. A tab or a line break is
    /// a space. A longer text than `maxLength` is cut after the last whole word that fits.
    ///
    /// The length is in characters. The Android app counts UTF-16 units, so it can cut an emoji into two halves.
    public static func clean(_ text: String?) -> String? {
        var words: [String] = []
        var word = String.UnicodeScalarView()
        for scalar in (text ?? "").unicodeScalars {
            if separators.contains(scalar) {
                if !word.isEmpty {
                    words.append(String(word))
                    word = String.UnicodeScalarView()
                }
            } else {
                word.append(scalar)
            }
        }
        if !word.isEmpty {
            words.append(String(word))
        }
        let plain = words.joined(separator: " ")
        if plain.count <= maxLength {
            return plain.isEmpty ? nil : plain
        }
        let head = plain.prefix(maxLength + 1)
        if let space = head.lastIndex(of: " "), space > head.startIndex {
            return String(head[..<space])
        }
        return String(plain.prefix(maxLength))
    }
}

/// A time that a food keeps, in the largest unit that gives a whole number. The table of foods has days: a week is 7
/// days, a month is 30 days, and a year is 365 days (`spec/tools/build-foods.py`).
public struct KeepTime: Hashable, Sendable {
    /// The unit of a keep time.
    public enum Unit: String, CaseIterable, Sendable {
        case days
        case weeks
        case months
        case years
    }

    public let count: Int
    public let unit: Unit

    public init(count: Int, unit: Unit) {
        self.count = count
        self.unit = unit
    }

    /// The keep time of a number of days.
    public static func ofDays(_ days: Int) -> KeepTime {
        if days % 365 == 0 {
            return KeepTime(count: days / 365, unit: .years)
        }
        if days % 30 == 0 {
            return KeepTime(count: days / 30, unit: .months)
        }
        if days % 7 == 0 {
            return KeepTime(count: days / 7, unit: .weeks)
        }
        return KeepTime(count: days, unit: .days)
    }
}

/// What the table of foods says about a food in one storage kind. `time` is the time that the food keeps in the
/// storage kind, or nil. `tip` is the tip of the table for the storage kind, or nil.
public struct KindAdvice: Hashable, Sendable {
    public let kind: StorageKind
    public let time: KeepTime?
    public let tip: String?

    public init(kind: StorageKind, time: KeepTime?, tip: String?) {
        self.kind = kind
        self.time = time
        self.tip = tip
    }
}

/// The advice of the table of foods for a food. It is about the food in general, not about one product.
/// `foodName` is the name of the food of the table. `usualKind` is the usual storage kind of the food, or nil.
/// `kinds` has the storage kinds for which the food has a time or a tip, in the order pantry, fridge, freezer.
public struct GeneralAdvice: Hashable, Sendable {
    public let foodName: String
    public let usualKind: StorageKind?
    public let kinds: [KindAdvice]

    public init(foodName: String, usualKind: StorageKind?, kinds: [KindAdvice]) {
        self.foodName = foodName
        self.usualKind = usualKind
        self.kinds = kinds
    }
}

/// The storage tips that a screen shows. At least one of the two values is there. `packageText` is the storage text of
/// the product: the text on its package. The screen marks it as the text of this product. `general` is the advice of
/// the table of foods, or nil.
public struct StorageAdvice: Hashable, Sendable {
    public let packageText: String?
    public let general: GeneralAdvice?

    public init(packageText: String?, general: GeneralAdvice?) {
        self.packageText = packageText
        self.general = general
    }
}

/// Makes the storage tips of a product.
public enum StorageAdvices {
    /// The storage tips for a storage text and a food of the table of foods. The general advice is there when the
    /// food has a usual storage kind, a time, or a tip. With no storage text and no general advice, the result is
    /// nil.
    public static func of(storageText: String?, food: Food?) -> StorageAdvice? {
        var general: GeneralAdvice? = nil
        if let food {
            let kinds = StorageKind.allCases.compactMap { kind -> KindAdvice? in
                let days = food.days[kind]
                let tip = food.tips[kind]
                if days == nil && tip == nil {
                    return nil
                }
                return KindAdvice(kind: kind, time: days.map(KeepTime.ofDays), tip: tip)
            }
            if food.usualKind != nil || !kinds.isEmpty {
                general = GeneralAdvice(foodName: food.name, usualKind: food.usualKind, kinds: kinds)
            }
        }
        if storageText == nil && general == nil {
            return nil
        }
        return StorageAdvice(packageText: storageText, general: general)
    }
}
