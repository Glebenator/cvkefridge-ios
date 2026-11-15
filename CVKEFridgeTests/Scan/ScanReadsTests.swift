import AVFoundation
import CVKEFridgeFeatures
import CoreGraphics
import Testing
@testable import CVKEFridge

/// Which reads of the camera become a scan, the zoom for a near barcode, and the place of the scan window.
struct ScanReadsTests {
    private static let nutella = RawRead(format: .ean13, text: "3017620422003")
    private static let cola = RawRead(format: .ean13, text: "5449000000996")

    private func reading(ignoring: String? = nil, now: Int = 0) -> ScanReads {
        var reads = ScanReads()
        reads.setReading(true, ignoring: ignoring, now: now)
        return reads
    }

    @Test func aBarcodeIsAScanAfterTwoReadsWithinOneSecond() {
        var reads = reading()
        #expect(reads.read([Self.nutella], now: 0) == nil)
        #expect(reads.read([Self.nutella], now: 100) == "3017620422003")
    }

    @Test func noReadCountsWhileTheScannerDoesNotRead() {
        var reads = ScanReads()
        #expect(reads.read([Self.nutella], now: 0) == nil)
        #expect(reads.read([Self.nutella], now: 100) == nil)
        // The reads before the start do not count for the first scan after it.
        reads.setReading(true, now: 200)
        #expect(reads.read([Self.nutella], now: 300) == nil)
        #expect(reads.read([Self.nutella], now: 400) == "3017620422003")
    }

    @Test func afterAScanTheScannerDoesNotReadUntilItStartsAgain() {
        var reads = reading()
        _ = reads.read([Self.nutella], now: 0)
        #expect(reads.read([Self.nutella], now: 100) != nil)
        #expect(!reads.isReading)
        // A second package in front of the camera does not start a second lookup.
        #expect(reads.read([Self.cola], now: 200) == nil)
        #expect(reads.read([Self.cola], now: 300) == nil)

        reads.setReading(true, ignoring: "3017620422003", now: 5000)
        #expect(reads.read([Self.cola], now: 5100) == nil)
        #expect(reads.read([Self.cola], now: 5200) == "5449000000996")
    }

    @Test func thePackageOfTheLastScanIsIgnoredForThreeSecondsAfterTheReadsStartAgain() {
        var reads = reading(ignoring: "3017620422003", now: 10_000)
        #expect(reads.read([Self.nutella], now: 10_100) == nil)
        #expect(reads.read([Self.nutella], now: 12_900) == nil)
        #expect(reads.read([Self.nutella], now: 13_000) == nil)
        #expect(reads.read([Self.nutella], now: 13_100) == "3017620422003")
    }

    @Test func aStartWhileTheScannerReadsDoesNotIgnoreABarcode() {
        var reads = reading()
        reads.setReading(true, ignoring: "3017620422003", now: 0)
        #expect(reads.read([Self.nutella], now: 0) == nil)
        #expect(reads.read([Self.nutella], now: 100) == "3017620422003")
    }

    @Test func aReadWithAWrongCheckDigitOrLettersDoesNotCount() {
        var reads = reading()
        for now in [0, 100, 200] {
            #expect(reads.read([RawRead(format: .ean13, text: "3017620422004")], now: now) == nil)
            #expect(reads.read([RawRead(format: .ean8, text: "ABCDEFGH")], now: now) == nil)
        }
        #expect(reads.isReading)
    }

    @Test func aUpcAThatTheCameraGivesAsAnEan13IsTheBarcodeOfTheTypedUpcA() {
        // AVFoundation gives the UPC-A 012345678905 as the EAN-13 0012345678905.
        var reads = reading()
        _ = reads.read([RawRead(format: .ean13, text: "0012345678905")], now: 0)
        let scan = reads.read([RawRead(format: .ean13, text: "0012345678905")], now: 100)
        #expect(scan == "0012345678905")
        #expect(Barcodes.parseTyped("012345678905") == .valid(barcode: "0012345678905"))
    }

    @Test func aUpcEBecomesItsUpcAAndAnEan8StaysAsItIs() {
        var reads = reading()
        _ = reads.read([RawRead(format: .upcE, text: "01234565")], now: 0)
        #expect(reads.read([RawRead(format: .upcE, text: "01234565")], now: 100) == "0012345000065")

        reads.setReading(true, now: 1000)
        _ = reads.read([RawRead(format: .ean8, text: "01234565")], now: 1100)
        #expect(reads.read([RawRead(format: .ean8, text: "01234565")], now: 1200) == "01234565")
    }

    @Test func ofTwoBarcodesInOnePictureTheOneNearestToTheCentreCounts() {
        // The Android app gives the two barcodes to its debouncer in turn, and then no barcode counts.
        var reads = reading()
        let near = RawRead(format: .ean13, text: "5449000000996", offCentre: 0.01)
        let far = RawRead(format: .ean13, text: "3017620422003", offCentre: 0.2)
        #expect(reads.read([far, near], now: 0) == nil)
        #expect(reads.read([near, far], now: 100) == "5449000000996")
    }

    @Test func aBarcodeThatIsNotValidDoesNotHideAValidBarcodeOfThePicture() {
        var reads = reading()
        let wrong = RawRead(format: .ean13, text: "3017620422004", offCentre: 0)
        let valid = RawRead(format: .ean13, text: "5449000000996", offCentre: 0.3)
        _ = reads.read([wrong, valid], now: 0)
        #expect(reads.read([wrong, valid], now: 100) == "5449000000996")
    }

    @Test func theFormatsOfAVFoundationAreTheFormatsOfRetailPackages() {
        #expect(Barcodes.Format(AVMetadataObject.ObjectType.ean13) == .ean13)
        #expect(Barcodes.Format(AVMetadataObject.ObjectType.ean8) == .ean8)
        #expect(Barcodes.Format(AVMetadataObject.ObjectType.upce) == .upcE)
        #expect(Barcodes.Format(AVMetadataObject.ObjectType.qr) == nil)
        #expect(Barcodes.Format(AVMetadataObject.ObjectType.code128) == nil)
    }

    @Test func theClockOfTheReadsDoesNotGoBack() {
        let clock = MonotonicMillis()
        let first = clock.now()
        let second = clock.now()
        #expect(first >= 0)
        #expect(second >= first)
    }

    // MARK: - The zoom for a near barcode

    @Test func aCameraThatFocusesNearNeedsNoZoom() {
        // At 5 cm, the barcode already fills more than the scan window.
        #expect(CloseFocus.zoomFactor(minimumFocusDistance: 50, fieldOfView: 69, deviceMaxZoom: 10) == 1)
    }

    @Test func aCameraThatFocusesOnlyFromFarGetsAZoomWithALimit() {
        let near = CloseFocus.zoomFactor(minimumFocusDistance: 100, fieldOfView: 69, deviceMaxZoom: 10)
        #expect(near > 1.4 && near < 1.6)
        // 20 cm needs a zoom of about 3. The limit is `CloseFocus.maxZoom`.
        #expect(CloseFocus.zoomFactor(minimumFocusDistance: 200, fieldOfView: 69, deviceMaxZoom: 10) == CloseFocus.maxZoom)
        // The camera permits less.
        #expect(CloseFocus.zoomFactor(minimumFocusDistance: 200, fieldOfView: 69, deviceMaxZoom: 1.5) == 1.5)
    }

    @Test func aCameraThatDoesNotTellItsValuesGetsNoZoom() {
        #expect(CloseFocus.zoomFactor(minimumFocusDistance: -1, fieldOfView: 69, deviceMaxZoom: 10) == 1)
        #expect(CloseFocus.zoomFactor(minimumFocusDistance: 0, fieldOfView: 69, deviceMaxZoom: 10) == 1)
        #expect(CloseFocus.zoomFactor(minimumFocusDistance: 200, fieldOfView: 0, deviceMaxZoom: 10) == 1)
        #expect(CloseFocus.zoomFactor(minimumFocusDistance: 200, fieldOfView: 69, deviceMaxZoom: 0) == 1)
    }

    // MARK: - The scan window

    @Test func theScanWindowIsInTheMiddleWithTheShapeOfABarcode() {
        let window = ScanWindow.rect(in: CGRect(x: 0, y: 100, width: 400, height: 500))
        #expect(window.width == 320)
        #expect(abs(window.height - 176) < 0.001)
        #expect(window.midX == 200)
        #expect(window.midY == 350)
    }

    @Test func theScanWindowHasALargestWidthAndStaysInALowArea() {
        let wide = ScanWindow.rect(in: CGRect(x: 0, y: 0, width: 1000, height: 800))
        #expect(wide.width == ScanWindow.maxWidth)
        let low = ScanWindow.rect(in: CGRect(x: 0, y: 0, width: 500, height: 200))
        #expect(low.height == 100)
        #expect(low.minY == 50)
        #expect(ScanWindow.rect(in: .zero).isEmpty)
    }
}
