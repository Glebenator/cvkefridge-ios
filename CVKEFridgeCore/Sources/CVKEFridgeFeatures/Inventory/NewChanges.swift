import Foundation

// The changes that the phone adds to the change log.
// The Android file `app/src/main/java/com/cvke/fridge/inventory/NewChanges.kt` in cvkefridge-android has the same
// behaviour.

/// Makes the changes that the phone adds to the change log, and checks them before the write.
public enum NewChanges {
    /// The changes for the `bodies`, in their order. The replay sorts by the instant, so each change gets an instant
    /// that is after all changes in the `log` and after the change before it. The instant is `now`, or later when the
    /// clock of the phone went back.
    ///
    /// - Parameters:
    ///   - now: The instant of the clock, in milliseconds from 1970-01-01T00:00:00Z.
    ///   - origin: The identifier of the phone.
    ///   - newId: Makes a random identifier for each change.
    public static func stamp(
        _ bodies: [ChangeBody],
        log: [Change],
        now: Int,
        origin: String,
        newId: () -> String
    ) -> [Change] {
        let first: Int
        if let last = log.map(\.at).max(), last >= now {
            first = last + 1
        } else {
            first = now
        }
        return bodies.enumerated().map { index, body in
            Change(id: newId(), at: first + index, origin: origin, body: body)
        }
    }

    /// Why the new changes cannot apply: the reason of the first change that the replay rejects in `next` and did not
    /// reject in `previous`. It is nil when the replay rejects no more changes than before.
    public static func rejection(previous: Inventory, next: Inventory) -> RejectionReason? {
        let before = Set(previous.rejected.map(\.changeId))
        return next.rejected.first(where: { !before.contains($0.changeId) })?.reason
    }
}
