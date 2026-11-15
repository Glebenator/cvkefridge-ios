import Foundation

// The barcodes of retail packages. The Android file `app/src/main/java/com/cvke/fridge/lookup/Barcodes.kt` in
// cvkefridge-android has the same behaviour, with one correction (an EAN-8 with zeros at the start).

/// The barcodes of retail packages: EAN-13, EAN-8, UPC-A, UPC-E, and GTIN-14. The app keeps a barcode in one form, so
/// that one package always gives the same text, typed or scanned:
///
/// - EAN-13 and EAN-8 stay as they are.
/// - UPC-A (12 digits) gets a 0 at the start. It is then the EAN-13 of the same package. Open Food Facts uses this
///   form. The barcode reader of AVFoundation gives a UPC-A as this EAN-13, so the two reads give the same text.
/// - UPC-E (8 digits) becomes its UPC-A, and then gets a 0 at the start.
/// - GTIN-14 loses a 0 at the start. A GTIN-14 that does not start with 0 stays as it is.
/// - A 13-digit form that starts with five zeros is an EAN-8 with zeros at the start (GS1 keeps the prefix `00000`
///   for GTIN-8). It becomes the EAN-8, which is the text of a scan of the same package.
///
/// Each barcode has a check digit at the end. A text with a wrong check digit is not a barcode. Only the ASCII digits
/// 0 to 9 are digits.
public enum Barcodes {
    /// The format that the camera read. The format tells EAN-8 from UPC-E, which both have 8 digits.
    public enum Format: Hashable, Sendable, CaseIterable {
        case ean13
        case ean8
        case upcA
        case upcE
    }

    /// Why a typed text is not a barcode.
    public enum Problem: Hashable, Sendable {
        /// The text has a character that is not a digit, a space, or a hyphen, or it has a wrong number of digits.
        case notABarcode
        /// The number of digits is correct, but the last digit is not the check digit.
        case wrongCheckDigit
    }

    /// The result of `parseTyped`.
    public enum Typed: Hashable, Sendable {
        case valid(barcode: String)
        case invalid(Problem)
    }

    /// The numbers of digits of a barcode (glossary: "Barcode").
    private static let lengths: Set<Int> = [8, 12, 13, 14]

    /// The barcode in a text that the person typed. Spaces and hyphens have no effect, because packages print the
    /// digits in groups. A text of 8 digits is an EAN-8 when its check digit is correct for EAN-8, and else a UPC-E.
    public static func parseTyped(_ text: String) -> Typed {
        if text.unicodeScalars.contains(where: { !isDigit($0) && $0 != " " && $0 != "-" }) {
            return .invalid(.notABarcode)
        }
        let digits = String(String.UnicodeScalarView(text.unicodeScalars.filter(isDigit)))
        guard lengths.contains(digits.count) else {
            return .invalid(.notABarcode)
        }
        let barcode = digits.count == 8 ? (canonical(digits) ?? upcE(digits)) : canonical(digits)
        guard let barcode else {
            return .invalid(.wrongCheckDigit)
        }
        return .valid(barcode: barcode)
    }

    /// The barcode that the camera read, in the form of the app, or nil when its digits are not a valid barcode.
    public static func fromScan(format: Format, raw: String) -> String? {
        guard !raw.isEmpty, raw.unicodeScalars.allSatisfy(isDigit) else {
            return nil
        }
        switch format {
        case .upcE:
            switch raw.count {
            case 8:
                return upcE(raw)
            case 6:
                // Some readers give only the 6 digits of the code. The number system is then 0.
                return upcE("0" + raw + String(checkDigit(upcABody("0" + raw))))
            default:
                return nil
            }
        case .ean8:
            return raw.count == 8 ? canonical(raw) : nil
        case .ean13, .upcA:
            return raw.count == 12 || raw.count == 13 ? canonical(raw) : nil
        }
    }

    /// The barcode in the form of the app, or nil when `text` is not a valid barcode. A text from storage that is not
    /// in this form, for example a UPC-A, gets the same result as the scan of the same package.
    public static func normalize(_ text: String) -> String? {
        if case .valid(let barcode) = parseTyped(text) {
            return barcode
        }
        return nil
    }

    /// True when the last digit is the GS1 check digit of the other digits.
    public static func hasValidCheckDigit(_ digits: String) -> Bool {
        let values = digitValues(digits)
        guard let values, values.count >= 2 else {
            return false
        }
        return checkDigit(values.dropLast()) == values[values.count - 1]
    }

    /// The UPC-A of a UPC-E: 8 digits with the number system (0 or 1) first and the check digit last. The result is
    /// nil when the text is not a UPC-E or its check digit is wrong.
    public static func expandUpcE(_ digits: String) -> String? {
        guard let values = digitValues(digits), values.count == 8, values[0] <= 1 else {
            return nil
        }
        let upcA = upcABody(digits) + String(values[7])
        return hasValidCheckDigit(upcA) ? upcA : nil
    }

    /// The GS1 check digit for the digits: weights 3 and 1 from the right, and then the step to the next 10.
    private static func checkDigit<C: BidirectionalCollection>(_ body: C) -> Int where C.Element == Int {
        var sum = 0
        for (index, value) in body.reversed().enumerated() {
            sum += value * (index % 2 == 0 ? 3 : 1)
        }
        return (10 - sum % 10) % 10
    }

    private static func checkDigit(_ body: String) -> Int {
        checkDigit(digitValues(body) ?? [])
    }

    /// The 11 digits of the UPC-A of a UPC-E, with no check digit. `digits` has the number system first, and at least
    /// 7 ASCII digits.
    private static func upcABody(_ digits: String) -> String {
        let d = Array(digits)
        let tail: [Character]
        switch d[6] {
        case "0", "1", "2":
            tail = [d[1], d[2], d[6], "0", "0", "0", "0", d[3], d[4], d[5]]
        case "3":
            tail = [d[1], d[2], d[3], "0", "0", "0", "0", "0", d[4], d[5]]
        case "4":
            tail = [d[1], d[2], d[3], d[4], "0", "0", "0", "0", "0", d[5]]
        default:
            tail = [d[1], d[2], d[3], d[4], d[5], "0", "0", "0", "0", d[6]]
        }
        return String(d[0]) + String(tail)
    }

    /// The form of the app for a UPC-E, or nil.
    private static func upcE(_ digits: String) -> String? {
        expandUpcE(digits).flatMap(canonical)
    }

    /// The form of the app for an EAN-8, a UPC-A, an EAN-13, or a GTIN-14, or nil when the check digit is wrong.
    private static func canonical(_ digits: String) -> String? {
        guard hasValidCheckDigit(digits) else {
            return nil
        }
        let form: String
        switch digits.count {
        case 12:
            form = "0" + digits
        case 14:
            form = digits.hasPrefix("0") ? String(digits.dropFirst()) : digits
        default:
            form = digits
        }
        // A GTIN-8 in a 13-digit field has five zeros at the start. Zeros at the start do not change the check
        // digit, so the last 8 digits are a valid EAN-8.
        if form.count == 13 && form.hasPrefix("00000") {
            return String(form.dropFirst(5))
        }
        return form
    }

    /// The values of the digits, or nil when a character is not an ASCII digit.
    private static func digitValues(_ text: String) -> [Int]? {
        var values: [Int] = []
        for scalar in text.unicodeScalars {
            guard isDigit(scalar) else {
                return nil
            }
            values.append(Int(scalar.value) - 0x30)
        }
        return values
    }

    private static func isDigit(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 0x30 && scalar.value <= 0x39
    }
}
