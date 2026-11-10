import Foundation

/// How fresh a batch is, from its days left. Rule 3 of `spec/rules.md`.
/// The Android file `core/src/main/kotlin/com/cvke/fridge/core/Freshness.kt` in cvkefridge-android has the same
/// behaviour.
public enum Freshness: String, CaseIterable, Sendable {
    case fresh
    case expiring
    case expired
    case noExpiryDate

    /// A batch with this number of days left or fewer, and not below 0, is expiring.
    public static let expiringWithinDays = 2

    /// The days from today to the expiry date, or nil if there is no expiry date.
    public static func daysLeft(today: CalendarDate, expiryDate: CalendarDate?) -> Int? {
        guard let expiryDate else {
            return nil
        }
        return today.daysUntil(expiryDate)
    }

    /// The freshness for a number of days left. Nil days left is a batch with no expiry date.
    public static func of(daysLeft: Int?) -> Freshness {
        guard let daysLeft else {
            return .noExpiryDate
        }
        if daysLeft < 0 {
            return .expired
        }
        if daysLeft <= expiringWithinDays {
            return .expiring
        }
        return .fresh
    }
}
