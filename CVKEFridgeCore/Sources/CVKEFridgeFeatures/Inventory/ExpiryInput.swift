import Foundation

// The expiry date that the person selected in a form.
// The Android file `app/src/main/java/com/cvke/fridge/inventory/ExpiryInput.kt` in cvkefridge-android has the same
// behaviour.

/// What the person selected for the expiry date in a form.
public enum ExpiryInput: Hashable, Sendable {
    /// The estimated date of the app. It follows the food, the storage area, and the date added.
    case suggested
    /// The printed date that the person entered. The app does not change it.
    case printed(CalendarDate)
    /// The date that the person chose because the food was still good (see `LaterExpiry`). It stays a chosen date
    /// while the person does not select another date in the form.
    case chosen(CalendarDate)
    /// No expiry date.
    case noExpiryDate

    /// The selection that shows the expiry date of a batch as it is.
    public static func of(_ expiry: ExpiryDate?) -> ExpiryInput {
        guard let expiry else {
            return .noExpiryDate
        }
        switch expiry.source {
        case .printed:
            return .printed(expiry.date)
        case .estimated:
            return .suggested
        case .chosen:
            return .chosen(expiry.date)
        }
    }
}

/// The expiry date that a form saves.
public enum ExpiryChoice {
    /// The expiry date for the selection. `suggested` is the estimated date, or nil when there is no estimate.
    public static func expiry(_ input: ExpiryInput, suggested: ExpiryDate?) -> ExpiryDate? {
        switch input {
        case .suggested:
            return suggested
        case .printed(let date):
            return ExpiryDate(date: date, source: .printed)
        case .chosen(let date):
            return ExpiryDate(date: date, source: .chosen)
        case .noExpiryDate:
            return nil
        }
    }

    /// The estimated date for a batch that the person edits. While the storage area and the date added are those of
    /// the `original` batch, it is the estimated date that the batch has. After a change of one of them, it is the
    /// new `estimate`. When there is no new estimate, the estimated date of the batch stays.
    public static func suggestionForEdit(
        original: Batch,
        storageAreaId: String,
        dateAdded: CalendarDate,
        estimate: ExpiryDate?
    ) -> ExpiryDate? {
        let kept = original.expiry?.source == .estimated ? original.expiry : nil
        let unchanged = storageAreaId == original.storageAreaId && dateAdded == original.dateAdded
        return unchanged ? (kept ?? estimate) : (estimate ?? kept)
    }
}
