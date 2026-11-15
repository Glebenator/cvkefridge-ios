import CVKEFridgeFeatures
import Foundation

// The words of the scanner that have a value in them. They are the words of `res/values/strings.xml` of the Android
// app. A text that names Android names iOS here.

extension Wording {
    /// "Looking up barcode 3017620422003…"
    static func lookingUp(barcode: String) -> String {
        String(localized: "Looking up barcode \(barcode)…", comment: "The value is a barcode.")
    }

    /// What VoiceOver says for "Looking up barcode …": the same words, with the digits of the barcode one by one.
    static func spokenLookingUp(barcode: String) -> AttributedString {
        var text = AttributedString(lookingUp(barcode: barcode))
        if let digits = text.range(of: barcode) {
            text[digits].accessibilitySpeechSpellsOutCharacters = true
        }
        return text
    }

    /// The hint for a barcode that the camera does not read. It names the light only when the camera has one.
    static func slowScanHint(hasLight: Bool) -> String {
        hasLight
            ? String(localized: "Can't read the barcode? Hold it flat and still, 10 to 20 cm from the camera. Turn on the light, or type the barcode.")
            : String(localized: "Can't read the barcode? Hold it flat and still, 10 to 20 cm from the camera. You can also type the barcode.")
    }

    /// Why a typed text is not a barcode.
    static func text(_ problem: Barcodes.Problem) -> String {
        switch problem {
        case .notABarcode:
            String(localized: "Enter the 8, 12, 13, or 14 digits below the lines of the barcode.")
        case .wrongCheckDigit:
            String(localized: "A digit is not correct. Check the digits.")
        }
    }
}

extension LookupFailure {
    /// The icon of a failed lookup.
    var icon: AppIcon {
        switch self {
        case .noConnection: .offline
        case .timeout, .busy, .server: .serviceUnavailable
        }
    }

    /// What failed, in a few words.
    var title: String {
        switch self {
        case .noConnection: String(localized: "No connection")
        case .timeout: String(localized: "Open Food Facts did not answer")
        case .busy: String(localized: "Too many lookups")
        case .server: String(localized: "Open Food Facts has a problem")
        }
    }

    /// What the person can do. The text says that the barcode stays for "Enter by hand".
    func message(barcode: String) -> String {
        switch self {
        case .noConnection:
            String(
                localized: "The product lookup needs the internet. Try again, or enter the food by hand. The app keeps barcode \(barcode) with the food.",
                comment: "The value is a barcode."
            )
        case .timeout:
            String(
                localized: "The answer took too long. Try again, or enter the food by hand. The app keeps barcode \(barcode) with the food.",
                comment: "The value is a barcode."
            )
        case .busy:
            String(
                localized: "Wait one minute and try again, or enter the food by hand. The app keeps barcode \(barcode) with the food.",
                comment: "The value is a barcode."
            )
        case .server:
            String(
                localized: "Try again later, or enter the food by hand. The app keeps barcode \(barcode) with the food.",
                comment: "The value is a barcode."
            )
        }
    }
}
