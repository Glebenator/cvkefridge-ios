import Foundation

// The later expiry date of a batch that is still good.
// The Android file `app/src/main/java/com/cvke/fridge/inventory/LaterExpiry.kt` in cvkefridge-android has the same
// behaviour.

/// The later expiry date of a batch that is expiring or expired, when the person says that the food is still good.
///
/// The quick choices add days to the expiry date. An expired batch starts from today, not from its expiry date: one
/// more day for food that expired three days ago means good until tomorrow, not still expired.
public enum LaterExpiry {
    /// The quick choices, in days: one day and one week.
    public static let quickDays = [1, 7]

    /// The expiry date `days` after the expiry date, or after `today` when the expiry date is before today.
    ///
    /// The result is nil when `days` is 0 or less, or when the date is after 9999-12-31. The Android app stops with
    /// an error in these two cases.
    public static func date(expiry: CalendarDate, today: CalendarDate, days: Int) -> CalendarDate? {
        guard days > 0 else {
            return nil
        }
        return max(expiry, today).plusDays(days)
    }

    /// True when `date` is a later expiry date for a batch: after its expiry date and after today. A batch with no
    /// expiry date needs a date after today.
    ///
    /// The app calls it when the action runs, with the date of today at that time. So a date that the person selected
    /// before midnight is not accepted after midnight when it is today then. The Android app accepts each date
    /// (defect 6 of `docs/android-parity-plan.md`). The Android app has no such function.
    public static func isLater(_ date: CalendarDate, expiry: CalendarDate?, today: CalendarDate) -> Bool {
        date > max(expiry ?? today, today)
    }
}
