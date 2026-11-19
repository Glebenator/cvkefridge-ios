import CVKEFridgeFeatures
import Foundation
import UIKit

/// The clock of the app: the instant of now, the time zone, and the date of today.
///
/// `today` is an observable value. It changes when the day changes while the app is open: at midnight, after a change
/// of the clock, and after a change of the time zone. The Android app reads the date only when its screen comes back,
/// so the days left there can be old after midnight.
///
/// The clock listens for the day change (`NSCalendarDayChanged`), the time zone change, and the significant time
/// change of the system. The app also calls `refresh()` each time its scene becomes active.
///
/// A test gives a fixed date. The clock then stays at 12:00 of that date.
@Observable
@MainActor
final class DayClock {
    /// The date of today in the time zone of the device.
    private(set) var today: CalendarDate

    /// Runs after each change of `today`, and after each change of the clock or the time zone with the same date. The
    /// model sets it, to calculate the days left and to plan the reminders again.
    @ObservationIgnored var onChange: (@MainActor () -> Void)?

    @ObservationIgnored private let instant: @Sendable () -> Date
    @ObservationIgnored private let zone: @Sendable () -> TimeZone
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    /// The clock of the device.
    convenience init() {
        self.init(now: { Date() }, timeZone: { TimeZone.current })
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            .NSCalendarDayChanged,
            .NSSystemTimeZoneDidChange,
            .NSSystemClockDidChange,
            UIApplication.significantTimeChangeNotification,
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.systemTimeChanged()
                }
            }
        }
    }

    /// A clock that stays at 12:00 of the `date`, for the tests and the screenshots.
    convenience init(fixed date: CalendarDate, timeZone: TimeZone = .current) {
        let noon = ReminderSchedule.triggerAt(date, time: ReminderTime(minuteOfDay: 12 * 60)!, timeZone: timeZone)
        self.init(now: { noon }, timeZone: { timeZone })
    }

    /// A clock with these sources.
    init(now: @escaping @Sendable () -> Date, timeZone: @escaping @Sendable () -> TimeZone) {
        instant = now
        zone = timeZone
        today = ReminderSchedule.dateOf(now(), timeZone: timeZone())
    }

    /// The instant of now.
    nonisolated func now() -> Date {
        instant()
    }

    /// The instant of now in milliseconds from 1970-01-01T00:00:00Z, for a new change.
    nonisolated func nowMillis() -> Int {
        Int((instant().timeIntervalSince1970 * 1000).rounded(.down))
    }

    /// The time zone of the device now.
    nonisolated func timeZone() -> TimeZone {
        zone()
    }

    /// Reads the date again. The app calls it when its scene becomes active.
    func refresh() {
        let date = ReminderSchedule.dateOf(instant(), timeZone: zone())
        if date != today {
            today = date
            onChange?()
        }
    }

    private func systemTimeChanged() {
        // The system keeps the time zone that the process read first. This call makes it read the zone again.
        NSTimeZone.resetSystemTimeZone()
        let date = ReminderSchedule.dateOf(instant(), timeZone: zone())
        if date != today {
            today = date
        }
        // The reminders are planned for instants. A change of the clock or the zone moves them, also on the same date.
        onChange?()
    }
}
