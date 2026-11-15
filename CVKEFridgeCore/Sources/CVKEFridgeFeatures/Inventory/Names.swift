import Foundation

// The rules for the names that the person types.
// The Android file `app/src/main/java/com/cvke/fridge/inventory/Names.kt` in cvkefridge-android has the same behaviour.

/// The rules for the names that the person types. The core does not check names (ADR 0005 in the cvkefridge
/// repository), so the forms do.
public enum Names {
    /// The largest number of characters in the name of a food.
    public static let maxFoodLength = 80

    /// The largest number of characters in the name of a storage area. The name must fit on a tab.
    public static let maxAreaLength = 30

    /// The name as the app keeps it: no space at the start or the end, and one space between words.
    ///
    /// All Unicode white space is a space, also a no-break space. The Android app makes only the ASCII white space
    /// between words into one space, so "Whole milk" with a no-break space was a different name.
    public static func clean(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// True when the two texts are the same name. Case and extra spaces have no effect.
    ///
    /// The case rule is the rule of Kotlin `equals(ignoreCase = true)` on Android: each character is changed to upper
    /// case and then to lower case before the compare (`key`). So the Greek "σ" and the final "ς" are the same, and
    /// "İ" is the same as "i". Accents have an effect: "Eclair" is not "Éclair".
    public static func same(_ first: String, _ second: String) -> Bool {
        key(first) == key(second)
    }

    /// The identity of a name: the cleaned name, with each character changed to upper case and then to lower case.
    /// Two names are the same (`same`) when they have the same key. Use it, for example, as the key of a dictionary.
    ///
    /// The change of each character uses only its mapping to one character, as Kotlin does with `Char.uppercaseChar`.
    /// A character that becomes more than one character in upper case, for example "ß", stays as it is.
    public static func key(_ name: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in clean(name).unicodeScalars {
            let upper = single(scalar.properties.uppercaseMapping) ?? scalar
            scalars.append(lowercase(upper))
        }
        return String(scalars)
    }

    /// The lower case of one character, as `Char.lowercaseChar` of Kotlin. Swift gives the full mapping. It is the
    /// mapping to one character for all characters but "İ" (U+0130), which has the full mapping "i" and a dot above.
    private static func lowercase(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        if scalar == "\u{0130}" {
            return "i"
        }
        return single(scalar.properties.lowercaseMapping) ?? scalar
    }

    /// The scalar of a text that has exactly one scalar, or nil.
    private static func single(_ text: String) -> Unicode.Scalar? {
        let scalars = text.unicodeScalars
        guard let first = scalars.first, scalars.index(after: scalars.startIndex) == scalars.endIndex else {
            return nil
        }
        return first
    }

    /// The order of two names in a list: case and accents have no effect, so "Éclair" comes before "Zucchini".
    /// The result is `.orderedSame` for two names that are equal in this order. The caller then uses another value.
    ///
    /// The Android app uses `String.CASE_INSENSITIVE_ORDER`, which puts a name that starts with an accented letter
    /// after "Z". This order does not use the locale, so that it is the same on each phone.
    public static func order(_ first: String, _ second: String) -> ComparisonResult {
        let firstKey = sortKey(first)
        let secondKey = sortKey(second)
        if firstKey == secondKey {
            return .orderedSame
        }
        return firstKey < secondKey ? .orderedAscending : .orderedDescending
    }

    /// The name with no case and no accents, for `order`.
    private static func sortKey(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
