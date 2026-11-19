import Foundation

// The text of a quantity field.
// The Android file `app/src/main/java/com/cvke/fridge/inventory/QuantityText.kt` in cvkefridge-android has the same
// behaviour, with two corrections for locales (see `QuantityText.parse`). `parse(_:locale:)` and `format(_:locale:)`
// also use the sign for thousands of the locale: on Android, "1.000" with a German locale is 1.

/// Why a text is not a quantity.
public enum QuantityProblem: String, CaseIterable, Sendable {
    case empty
    case notANumber
    case tooManyDecimals
    case notPositive
    case tooLarge
}

/// A quantity that the person typed.
public enum TypedQuantity: Hashable, Sendable {
    /// A quantity above 0, in thousandths.
    case value(Int)
    /// Why the text is not a quantity.
    case invalid(QuantityProblem)

    /// The quantity in thousandths, or nil when the text is not a quantity.
    public var thousandths: Int? {
        if case .value(let thousandths) = self {
            return thousandths
        }
        return nil
    }

    /// The problem of the text, or nil when the text is a quantity.
    public var problem: QuantityProblem? {
        if case .invalid(let problem) = self {
            return problem
        }
        return nil
    }
}

/// Reads and writes a quantity as the text of a number field. The core keeps a quantity as whole thousandths.
public enum QuantityText {
    /// The decimal signs that `parse` accepts: a point, a comma, and the Arabic decimal sign U+066B.
    public static let decimalSigns: Set<Character> = [".", ",", "\u{066B}"]

    /// The largest number of digits before the decimal sign. The largest quantity is 99999.999.
    private static let maxWholeDigits = 5

    /// The largest number of digits after the decimal sign.
    private static let maxDecimals = 3

    /// The quantity in the `text`. The decimal sign is a point or a comma, because the decimal keyboard of some
    /// phones has only one of the two. The text has no sign for thousands. The largest quantity is 99999.999.
    ///
    /// Two corrections of the Android app: the Arabic decimal sign U+066B is also a decimal sign, because `format`
    /// writes it for an Arabic locale. And a decimal digit of another script, for example "١", is the same as its
    /// ASCII digit, because the decimal keyboard of iOS can type it.
    public static func parse(_ text: String) -> TypedQuantity {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .invalid(.empty)
        }
        var whole = ""
        var decimals = ""
        var hasSign = false
        for character in trimmed {
            if decimalSigns.contains(character) {
                if hasSign {
                    return .invalid(.notANumber)
                }
                hasSign = true
            } else if let digit = digit(character) {
                if hasSign {
                    decimals.append(digit)
                } else {
                    whole.append(digit)
                }
            } else {
                return .invalid(.notANumber)
            }
        }
        return quantity(whole: whole, decimals: decimals)
    }

    /// The quantity in the `text`, read with the number format of the `locale`: its decimal sign, its sign for
    /// thousands, and the digits of each script. German "1.000" is 1000 and "1.000,5" is 1000.5. The limits are the
    /// limits of `parse(_:)`: not more than 3 decimals, and not more than 99999.999. `format(_:locale:)` writes a text
    /// that this function reads again as the same thousandths.
    ///
    /// The rules:
    /// 1. The decimal sign of the locale can be in the text one time. The decimals after it have no other sign.
    /// 2. The sign for thousands of the locale can be in the whole number, between groups of digits. The first group
    ///    has 1 to 3 digits, the last group has 3 digits, and a group between them has 2 or 3 digits (the groups of
    ///    India). When the sign for thousands is a space, each space is a sign for thousands.
    /// 3. A text with no decimal sign of the locale can have one point, comma, or Arabic decimal sign that is not in
    ///    groups of rule 2. That sign is then the decimal sign, because the decimal keyboard of some phones has only
    ///    one of the two. "1,5" in English is 1.5, but "1,500" is 1500.
    public static func parse(_ text: String, locale: Locale) -> TypedQuantity {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .invalid(.empty)
        }
        let separators = Separators(locale)
        // Each character is a digit, a sign, or not a part of a number.
        var parts: [Character] = []
        for character in trimmed {
            if let digit = digit(character) {
                parts.append(digit)
            } else if separators.isGroup(character) || separators.isDecimal(character)
                || decimalSigns.contains(character) {
                parts.append(character)
            } else {
                return .invalid(.notANumber)
            }
        }
        let signs = parts.indices.filter { !parts[$0].isASCIIDigit }
        let decimalPlaces = signs.filter { separators.isDecimal(parts[$0]) }
        let whole: [Character]
        let decimals: [Character]
        if decimalPlaces.count > 1 {
            return .invalid(.notANumber)
        } else if let place = decimalPlaces.first {
            whole = Array(parts[..<place])
            decimals = Array(parts[(place + 1)...])
        } else if signs.isEmpty || separators.areGroups(parts) {
            whole = parts
            decimals = []
        } else if signs.count == 1, let place = signs.first, decimalSigns.contains(parts[place]) {
            whole = Array(parts[..<place])
            decimals = Array(parts[(place + 1)...])
        } else {
            return .invalid(.notANumber)
        }
        if !decimals.allSatisfy(\.isASCIIDigit) {
            return .invalid(.notANumber)
        }
        if !whole.allSatisfy(\.isASCIIDigit) && !separators.areGroups(whole) {
            return .invalid(.notANumber)
        }
        return quantity(whole: String(whole.filter(\.isASCIIDigit)), decimals: String(decimals))
    }

    /// `parse(_:locale:)` for a locale, and `parse(_:)` for nil.
    static func parse(_ text: String, optionalLocale locale: Locale?) -> TypedQuantity {
        locale.map { parse(text, locale: $0) } ?? parse(text)
    }

    /// The quantity of a whole number and its decimals, as ASCII digits, with the limits of the Android app.
    private static func quantity(whole: String, decimals: String) -> TypedQuantity {
        if whole.isEmpty && decimals.isEmpty {
            return .invalid(.notANumber)
        }
        if decimals.count > maxDecimals {
            return .invalid(.tooManyDecimals)
        }
        let significant = whole.drop(while: { $0 == "0" })
        if significant.count > maxWholeDigits {
            return .invalid(.tooLarge)
        }
        let paddedDecimals = decimals + String(repeating: "0", count: maxDecimals - decimals.count)
        let value = (Int(significant) ?? 0) * 1000 + (Int(paddedDecimals) ?? 0)
        if value <= 0 {
            return .invalid(.notPositive)
        }
        return .value(value)
    }

    /// The text of a quantity for a number field: no zeros at the end, and the decimal sign of the locale.
    ///
    /// - Parameter decimalSeparator: The decimal sign of the locale, for example `Locale.current.decimalSeparator`.
    public static func format(_ thousandths: Int, decimalSeparator: String = ".") -> String {
        let sign = thousandths < 0 ? "-" : ""
        let magnitude = thousandths.magnitude
        let whole = magnitude / 1000
        var decimals = String(magnitude % 1000)
        decimals = String(repeating: "0", count: maxDecimals - decimals.count) + decimals
        while decimals.hasSuffix("0") {
            decimals.removeLast()
        }
        if decimals.isEmpty {
            return "\(sign)\(whole)"
        }
        return "\(sign)\(whole)\(decimalSeparator)\(decimals)"
    }

    /// The text of a quantity for a number field, in the number format of the `locale`: its decimal sign and its
    /// digits, with no sign for thousands and no zeros at the end. `parse(_:locale:)` reads it again as the same
    /// thousandths.
    public static func format(_ thousandths: Int, locale: Locale) -> String {
        let value = Decimal(sign: thousandths < 0 ? .minus : .plus, exponent: -maxDecimals, significand: Decimal(thousandths.magnitude))
        return value.formatted(
            Decimal.FormatStyle(locale: locale)
                .grouping(.never)
                .precision(.fractionLength(0...maxDecimals))
        )
    }

    /// The decimal sign and the sign for thousands of a locale.
    private struct Separators {
        let decimal: String
        let group: String
        let groupIsSpace: Bool

        init(_ locale: Locale) {
            decimal = locale.decimalSeparator ?? "."
            let group = locale.groupingSeparator ?? ""
            // A locale must not have one sign for the two.
            self.group = group == decimal ? "" : group
            groupIsSpace = !self.group.isEmpty && self.group.allSatisfy(\.isWhitespace)
        }

        func isDecimal(_ character: Character) -> Bool {
            String(character) == decimal
        }

        func isGroup(_ character: Character) -> Bool {
            if group.isEmpty || isDecimal(character) {
                return false
            }
            if groupIsSpace {
                return character.isWhitespace
            }
            // Switzerland has an apostrophe: U+2019 or the ASCII apostrophe. The two are the same sign.
            let apostrophes: Set<String> = ["'", "\u{2019}"]
            return String(character) == group || (apostrophes.contains(group) && apostrophes.contains(String(character)))
        }

        /// True when the characters are digits in groups with the sign for thousands between them (rule 2 of
        /// `parse(_:locale:)`).
        func areGroups(_ characters: [Character]) -> Bool {
            var groups: [Int] = [0]
            for character in characters {
                if character.isASCIIDigit {
                    groups[groups.count - 1] += 1
                } else if isGroup(character) {
                    groups.append(0)
                } else {
                    return false
                }
            }
            guard groups.count >= 2, let first = groups.first, let last = groups.last else {
                return false
            }
            return (1...3).contains(first) && last == 3 && groups.dropFirst().dropLast().allSatisfy { (2...3).contains($0) }
        }
    }

    /// The ASCII digit of a decimal digit of any script, or nil for a different character.
    private static func digit(_ character: Character) -> Character? {
        let scalars = character.unicodeScalars
        guard scalars.count == 1, let scalar = scalars.first, scalar.properties.numericType == .decimal,
              let value = scalar.properties.numericValue, value >= 0, value <= 9
        else {
            return nil
        }
        return Character(String(Int(value)))
    }
}

private extension Character {
    var isASCIIDigit: Bool {
        asciiValue.map { $0 >= 0x30 && $0 <= 0x39 } ?? false
    }
}
