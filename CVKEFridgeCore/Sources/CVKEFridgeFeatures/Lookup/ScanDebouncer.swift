import Foundation

// Decides which reads of the camera count. The Android file `app/src/main/java/com/cvke/fridge/scan/ScanDebouncer.kt`
// in cvkefridge-android has the same behaviour.

/// Decides which reads of the camera count. The camera reads a barcode in many pictures each second, and a bad
/// picture can give a wrong number with a correct check digit. A barcode counts when the camera reads the same number
/// `confirmations` times within `windowMillis`. A barcode that counted does not count again until `ignoreMillis`
/// after it counted, so one package gives one scan.
///
/// The instants are milliseconds of a monotonic clock, for example the uptime of the device. The values must not
/// come from the clock of the device, which can go back.
public struct ScanDebouncer: Sendable {
    private let confirmations: Int
    private let windowMillis: Int
    private let ignoreMillis: Int

    private var candidate: String?
    private var count = 0
    private var firstRead = 0
    private var ignored: String?
    private var ignoredUntil = Int.min

    public init(confirmations: Int = 2, windowMillis: Int = 1000, ignoreMillis: Int = 3000) {
        self.confirmations = confirmations
        self.windowMillis = windowMillis
        self.ignoreMillis = ignoreMillis
    }

    /// One read of the camera at the instant `now`, in milliseconds. The result is the barcode when it counts, else
    /// nil.
    public mutating func read(_ barcode: String, now: Int) -> String? {
        if barcode == ignored && now < ignoredUntil {
            return nil
        }
        if barcode != candidate || now - firstRead > windowMillis {
            candidate = barcode
            count = 0
            firstRead = now
        }
        count += 1
        if count < confirmations {
            return nil
        }
        candidate = nil
        count = 0
        ignore(barcode, now: now)
        return barcode
    }

    /// Ignores the `barcode` until `ignoreMillis` after `now`. The scanner calls it when it starts to read again after
    /// a scan, so that the package that is still in front of the camera does not give the same scan again.
    public mutating func ignore(_ barcode: String?, now: Int) {
        ignored = barcode
        ignoredUntil = now + ignoreMillis
    }
}
