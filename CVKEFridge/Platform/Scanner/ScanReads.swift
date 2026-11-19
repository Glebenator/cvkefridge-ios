import CVKEFridgeFeatures
import Foundation

// The parts of the scanner that are calculations: which reads of the camera become a scan, the clock for them, and
// the zoom for a barcode that is near the camera. They use Foundation only, so a unit test can run them with no
// camera.

/// One barcode that the camera read in one picture, before the rules of `Barcodes`.
struct RawRead: Hashable, Sendable {
    /// The format that the camera gave.
    let format: Barcodes.Format
    /// The digits that the camera gave.
    let text: String
    /// How far the barcode is from the centre of the scan window. Only the order of two values is important.
    let offCentre: Double

    init(format: Barcodes.Format, text: String, offCentre: Double = 0) {
        self.format = format
        self.text = text
        self.offCentre = offCentre
    }
}

/// Decides which reads of the camera become a scan. The camera reads a barcode in many pictures each second.
///
/// - A read counts only while the scanner reads: not during a lookup, and not while a form is above the scanner.
/// - Each read goes through `Barcodes.fromScan`, so a read with a wrong check digit does not count.
/// - `ScanDebouncer` then decides: the same number two times in one second, and one package gives one scan.
/// - After a scan, the scanner does not read until `setReading(true, …)` starts it again. So two packages in front of
///   the camera cannot start two lookups.
///
/// One picture can show more than one barcode. Then only the barcode that is nearest to the centre of the scan
/// window counts. The Android app gives each barcode of the picture to its debouncer. Two barcodes then take the
/// place of each other in each picture, and no barcode counts.
struct ScanReads: Sendable {
    private var debouncer: ScanDebouncer
    private(set) var isReading = false

    init(debouncer: ScanDebouncer = ScanDebouncer()) {
        self.debouncer = debouncer
    }

    /// Starts or stops the reads.
    ///
    /// - Parameters:
    ///   - ignoring: When the reads start: the barcode of the last scan. The package can still be in front of the
    ///     camera, so the scanner ignores this barcode for a short time.
    ///   - now: The instant of now, in milliseconds of a monotonic clock.
    mutating func setReading(_ reading: Bool, ignoring: String? = nil, now: Int) {
        if reading && !isReading {
            debouncer.ignore(ignoring, now: now)
        }
        isReading = reading
    }

    /// The barcodes of one picture of the camera, at the instant `now` in milliseconds of a monotonic clock. The
    /// result is the barcode of a scan, in the form of `Barcodes`, or nil.
    mutating func read(_ reads: [RawRead], now: Int) -> String? {
        guard isReading else {
            return nil
        }
        let valid = reads.compactMap { read in
            Barcodes.fromScan(format: read.format, raw: read.text).map { (barcode: $0, offCentre: read.offCentre) }
        }
        guard let nearest = valid.min(by: { $0.offCentre < $1.offCentre }) else {
            return nil
        }
        guard let scan = debouncer.read(nearest.barcode, now: now) else {
            return nil
        }
        isReading = false
        return scan
    }
}

/// A clock for the reads of the camera: the milliseconds from the instant when it was made. It is monotonic, so a
/// change of the clock of the device has no effect on it.
struct MonotonicMillis: Sendable {
    private let start = ContinuousClock.now

    func now() -> Int {
        let elapsed = start.duration(to: ContinuousClock.now).components
        return Int(elapsed.seconds) * 1000 + Int(elapsed.attoseconds / 1_000_000_000_000_000)
    }
}

/// The zoom for a barcode that is near the camera.
///
/// The camera of some iPhone models cannot focus nearer than about 20 cm. At that distance a barcode is small in the
/// picture, so a person moves the package nearer, and the picture is then not sharp. With a zoom, the barcode fills
/// the scan window at a distance where the camera can focus. The calculation is the one that Apple gives for
/// barcodes (`AVCaptureDevice.minimumFocusDistance`).
enum CloseFocus {
    /// The width of the barcode of a retail package, in millimetres: an EAN-13 at its usual size, with the quiet
    /// zones.
    static let barcodeWidth = 37.0

    /// The part of the width of the picture that the scan window has.
    static let windowFill = 0.8

    /// More zoom makes the picture less sharp, and a small movement of the hand then moves the barcode out of the
    /// scan window.
    static let maxZoom = 2.0

    /// The zoom factor for the camera, from 1 to `maxZoom` and not more than the camera permits.
    ///
    /// - Parameters:
    ///   - minimumFocusDistance: The nearest distance at which the camera can focus, in millimetres. A value of 0 or
    ///     less means that the camera does not tell the distance.
    ///   - fieldOfView: The horizontal field of view of the camera, in degrees.
    ///   - deviceMaxZoom: The largest zoom factor of the camera.
    static func zoomFactor(minimumFocusDistance: Int, fieldOfView: Double, deviceMaxZoom: Double) -> Double {
        guard minimumFocusDistance > 0, fieldOfView > 0, fieldOfView < 180 else {
            return 1
        }
        let halfAngle = fieldOfView / 2 * .pi / 180
        // The distance at which the barcode fills the scan window with no zoom.
        let fillDistance = barcodeWidth / windowFill / tan(halfAngle)
        let zoom = Double(minimumFocusDistance) / fillDistance
        return min(max(zoom, 1), maxZoom, max(deviceMaxZoom, 1))
    }
}
