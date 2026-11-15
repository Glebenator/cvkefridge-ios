import Foundation

// The values that the screens turn into words.
// The Android file `app/src/main/java/com/cvke/fridge/ui/DisplayFormat.kt` in cvkefridge-android makes the words with
// Android resources. This file has only the parts that do not need words: the number of a quantity, the plural count
// of its unit, and the kind of expiry text. The app makes the words from its string catalog. Colours, icons, and the
// names of categories, units, sort orders, and problems are in the app.

/// A quantity with its unit, as a screen shows it: "1.5 l", "2 packs", "3". The app puts the `number` into the text
/// of the unit, with the plural form for `pluralCount`.
public struct QuantityDisplay: Hashable, Sendable {
    /// The quantity in thousandths.
    public let thousandths: Int
    public let unit: MeasureUnit?

    public init(thousandths: Int, unit: MeasureUnit?) {
        self.thousandths = thousandths
        self.unit = unit
    }

    /// The quantity as a decimal number: 1500 thousandths is 1.5. The value is exact.
    public var value: Decimal {
        Decimal(sign: thousandths < 0 ? .minus : .plus, exponent: -3, significand: Decimal(thousandths.magnitude))
    }

    /// The whole number that selects the plural form of the unit, or nil when the quantity has a fraction. For a
    /// fraction, use the plural form "other" of the language.
    ///
    /// The Android app uses the form for 1 for exactly 1, and the form for 2 for all other quantities. That is not
    /// correct in a language with more plural forms, for example "few" and "many" in Polish or Russian.
    public var pluralCount: Int? {
        thousandths % 1000 == 0 ? thousandths / 1000 : nil
    }

    /// The number in the format of the `locale`, with not more than 3 decimals and with the sign for thousands:
    /// "1,250.5" in English (United States), "1.250,5" in German (Germany).
    public func number(locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? QuantityText.format(thousandths)
    }
}

/// When a batch expires, in the words of the two screens: "Expired 3d ago", "Expired yesterday", "Expires today",
/// "Expires tomorrow", "Expires in 5d", or "No expiry".
public enum ExpiryPhrase: Hashable, Sendable {
    case noExpiry
    /// The batch expired 2 or more days ago. The value is the number of days, above 1.
    case expiredDaysAgo(Int)
    case expiredYesterday
    case expiresToday
    case expiresTomorrow
    /// The batch expires in 2 or more days. The value is the number of days, above 1.
    case expiresInDays(Int)
}

/// The expiry text of a batch: the phrase, and if the app estimated the date. The app adds ", estimated" to the
/// phrase when `estimated` is true.
public struct ExpiryText: Hashable, Sendable {
    public let phrase: ExpiryPhrase
    public let estimated: Bool

    public init(phrase: ExpiryPhrase, estimated: Bool) {
        self.phrase = phrase
        self.estimated = estimated
    }

    /// The expiry text for the days left and the expiry date. With no days left or no expiry date, it is "No expiry",
    /// and it is not estimated.
    public static func of(daysLeft: Int?, expiry: ExpiryDate?) -> ExpiryText {
        guard let daysLeft, let expiry else {
            return ExpiryText(phrase: .noExpiry, estimated: false)
        }
        let phrase: ExpiryPhrase
        switch daysLeft {
        case ..<(-1):
            phrase = .expiredDaysAgo(-daysLeft)
        case -1:
            phrase = .expiredYesterday
        case 0:
            phrase = .expiresToday
        case 1:
            phrase = .expiresTomorrow
        default:
            phrase = .expiresInDays(daysLeft)
        }
        return ExpiryText(phrase: phrase, estimated: expiry.source == .estimated)
    }
}
