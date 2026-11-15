import CVKEFridgeFeatures
import Testing

/// The check digit and the one form of the app for each kind of barcode. The Android test `BarcodesTest` has the same
/// cases. The last tests are for the iOS barcode reader and for the correction of an EAN-8 with zeros at the start.
struct BarcodesTests {
    private func typed(_ text: String) -> String? {
        if case .valid(let barcode) = Barcodes.parseTyped(text) {
            return barcode
        }
        return nil
    }

    @Test func theCheckDigitIsTheGs1CheckDigit() {
        #expect(Barcodes.hasValidCheckDigit("3017620422003"))
        #expect(Barcodes.hasValidCheckDigit("96385074"))
        #expect(Barcodes.hasValidCheckDigit("036000291452"))
        #expect(!Barcodes.hasValidCheckDigit("3017620422004"))
        #expect(!Barcodes.hasValidCheckDigit("3"))
        #expect(!Barcodes.hasValidCheckDigit("30176204220a3"))
    }

    @Test func aTypedBarcodeGetsTheFormOfTheApp() {
        #expect(typed("3017620422003") == "3017620422003")
        // Packages print the digits in groups.
        #expect(typed(" 3 017620 422003 ") == "3017620422003")
        #expect(typed("5449000-000996") == "5449000000996")
        #expect(typed("96385074") == "96385074")
        // UPC-A is the EAN-13 with a 0 at the start.
        #expect(typed("036000291452") == "0036000291452")
        // A GTIN-14 with a 0 at the start is the EAN-13. Other GTIN-14 stay as they are.
        #expect(typed("00012345678905") == "0012345678905")
        #expect(typed("10012345678902") == "10012345678902")
    }

    @Test func eightDigitsAreAnEan8WhenTheyCanBeAndElseAUpcE() {
        // 01234565 is a valid EAN-8 and also a valid UPC-E. Typed, it is the EAN-8.
        #expect(typed("01234565") == "01234565")
        // 04252614 is not a valid EAN-8. Its UPC-A is 042100005264.
        #expect(typed("04252614") == "0042100005264")
    }

    @Test func aTextThatIsNotABarcodeSaysWhy() {
        #expect(Barcodes.parseTyped("3017620422004") == .invalid(.wrongCheckDigit))
        #expect(Barcodes.parseTyped("04252615") == .invalid(.wrongCheckDigit))
        #expect(Barcodes.parseTyped("3") == .invalid(.notABarcode))
        #expect(Barcodes.parseTyped("30176204220") == .invalid(.notABarcode))
        #expect(Barcodes.parseTyped("30176204220O3") == .invalid(.notABarcode))
        #expect(Barcodes.parseTyped("Nutella") == .invalid(.notABarcode))
        #expect(Barcodes.parseTyped("") == .invalid(.notABarcode))
        // Digits that are not ASCII are not digits of a barcode.
        #expect(Barcodes.parseTyped("٣٠١٧٦٢٠٤٢٢٠٠٣") == .invalid(.notABarcode))
    }

    @Test func theFormatOfTheCameraDecidesForEightDigits() {
        #expect(Barcodes.fromScan(format: .ean8, raw: "01234565") == "01234565")
        #expect(Barcodes.fromScan(format: .upcE, raw: "01234565") == "0012345000065")
        // A reader that gives only the 6 digits of a UPC-E.
        #expect(Barcodes.fromScan(format: .upcE, raw: "123456") == "0012345000065")
        #expect(Barcodes.fromScan(format: .upcA, raw: "036000291452") == "0036000291452")
        #expect(Barcodes.fromScan(format: .ean13, raw: "0036000291452") == "0036000291452")
    }

    @Test func aReadWithAWrongCheckDigitOrLengthIsNoBarcode() {
        #expect(Barcodes.fromScan(format: .ean13, raw: "3017620422004") == nil)
        #expect(Barcodes.fromScan(format: .ean8, raw: "3017620422003") == nil)
        #expect(Barcodes.fromScan(format: .upcE, raw: "21234565") == nil)
        #expect(Barcodes.fromScan(format: .upcE, raw: "01234566") == nil)
        #expect(Barcodes.fromScan(format: .ean13, raw: "") == nil)
    }

    @Test func aUpcEExpandsToItsUpcA() {
        #expect(Barcodes.expandUpcE("01234565") == "012345000065")
        #expect(Barcodes.expandUpcE("04252614") == "042100005264")
        #expect(Barcodes.expandUpcE("01234505") == "012000003455")
        #expect(Barcodes.expandUpcE("01234531") == "012300000451")
        #expect(Barcodes.expandUpcE("01234543") == "012340000053")
        // The number system is 0 or 1.
        #expect(Barcodes.expandUpcE("21234565") == nil)
    }

    @Test func aStoredBarcodeIsComparedInTheFormOfTheApp() {
        #expect(Barcodes.normalize("036000291452") == "0036000291452")
        #expect(Barcodes.normalize("5449000000996") == "5449000000996")
        #expect(Barcodes.normalize("12") == nil)
    }

    // iOS: AVFoundation gives a UPC-A as an EAN-13 with a 0 at the start. The read, the UPC-A, the typed digits, and
    // the stored UPC-A are the same barcode.
    @Test func aUpcAThatTheIosReaderGivesAsAnEan13IsTheSameBarcode() {
        let fromReader = Barcodes.fromScan(format: .ean13, raw: "0036000291452")
        #expect(fromReader == Barcodes.fromScan(format: .upcA, raw: "036000291452"))
        #expect(fromReader == typed("0 36000 29145 2"))
        #expect(fromReader == Barcodes.normalize("036000291452"))
        // A UPC-E package and its UPC-A in the EAN-13 form of the reader are also the same.
        #expect(Barcodes.fromScan(format: .upcE, raw: "01234565") == Barcodes.fromScan(format: .ean13, raw: "0012345000065"))
    }

    // Correction of Barcodes.kt:110-117: an EAN-8 in a 12, 13, or 14-digit field (zeros at the start) is the EAN-8.
    @Test func anEan8WithZerosAtTheStartIsTheEan8() {
        #expect(typed("00000096385074") == "96385074")
        #expect(typed("0000096385074") == "96385074")
        #expect(typed("000096385074") == "96385074")
        #expect(Barcodes.fromScan(format: .ean13, raw: "0000096385074") == "96385074")
        #expect(Barcodes.fromScan(format: .ean8, raw: "96385074") == "96385074")
        // A wrong check digit stays wrong.
        #expect(Barcodes.parseTyped("0000096385075") == .invalid(.wrongCheckDigit))
        // Four zeros at the start are a UPC-A of a company, not an EAN-8.
        #expect(typed("0000123456784") == "0000123456784")
    }

    // Correction of Barcodes.kt:45: eight typed digits that are a valid EAN-8 and a valid UPC-E gave only the EAN-8.
    @Test func eightDigitsCanBeAnEan8AndAUpcE() {
        // "01234565" is a valid EAN-8, and as a UPC-E it is the UPC-A 012345000065.
        #expect(Barcodes.typedCandidates("0123 4565") == ["01234565", "0012345000065"])
        #expect(Barcodes.typedCandidates("01234602") == ["01234602", "0012000003462"])
        // The barcode of `parseTyped` stays the first.
        #expect(Barcodes.parseTyped("01234565") == .valid(barcode: "01234565"))
        // Only a UPC-E, only an EAN-8, and the two forms that give the same barcode.
        #expect(Barcodes.typedCandidates("04252614") == ["0042100005264"])
        #expect(Barcodes.typedCandidates("96385074") == ["96385074"])
        #expect(Barcodes.typedCandidates("00000055") == ["00000055"])
        // The other lengths have one barcode, and a text that is not a barcode has none.
        #expect(Barcodes.typedCandidates("3017620422003") == ["3017620422003"])
        #expect(Barcodes.typedCandidates("3017620422004").isEmpty)
        #expect(Barcodes.typedCandidates("milk").isEmpty)
    }
}
