import Foundation

// The text of a quantity field.
// The Android file `app/src/main/java/com/cvke/fridge/inventory/QuantityText.kt` in cvkefridge-android has the same
// behaviour, with two corrections for locales (see `QuantityText.parse`).

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
