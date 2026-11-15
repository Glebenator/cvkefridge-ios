import Foundation

// The dates and the times of the daily reminder. The Android file
// `app/src/main/java/com/cvke/fridge/reminder/ReminderSchedule.kt` in cvkefridge-android has the same behaviour.

/// A time on the clock of the device: an hour from 0 to 23 and a minute from 0 to 59.
public struct ReminderTime: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// The minutes in one day.
    public static let minutesInDay = 24 * 60

    /// The minutes after midnight, from 0 to 1439.
    public let minuteOfDay: Int

    /// The time with these values, or nil when they are out of range.
    public init?(hour: Int, minute: Int) {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else {
            return nil
        }
        minuteOfDay = hour * 60 + minute
    }

    /// The time of a minute after midnight, or nil when it is out of range.
    public init?(minuteOfDay: Int) {
        guard (0..<Self.minutesInDay).contains(minuteOfDay) else {
            return nil
        }
        self.minuteOfDay = minuteOfDay
    }

    public var hour: Int {
        minuteOfDay / 60
    }

    public var minute: Int {
        minuteOfDay % 60
    }

    /// The text form `HH:MM`.
    public var description: String {
        let hourText = hour < 10 ? "0\(hour)" : "\(hour)"
        let minuteText = minute < 10 ? "0\(minute)" : "\(minute)"
        return "\(hourText):\(minuteText)"
    }

    public static func < (lhs: ReminderTime, rhs: ReminderTime) -> Bool {
        lhs.minuteOfDay < rhs.minuteOfDay
    }
}

/// The dates and the times of the daily reminder. The app keeps the date of the next reminder, not an instant. The
/// instant comes from that date, the time of the settings, and the time zone of the device at the moment of the
/// calculation. A change of the time zone, of the clock, or of daylight saving time then moves the reminder to the
/// same time on the clock of the device.
///
/// Rules:
/// - There is not more than one reminder on one date of the device.
/// - When the person turns reminders on or changes the time, the first reminder is today if the time is still ahead
///   and today had no reminder. Otherwise it is tomorrow. A change never sends a reminder at once.
/// - After a reminder, the next one is on the next date.
/// - When the phone was off, or the clock or the time zone changed, at the time of a reminder, the reminder of today
///   comes when the app can run again, on the same date. The reminders of earlier dates do not come.
///
/// The calculations use the rules of the time zone that the caller gives, not the time zone of the process.
public enum ReminderSchedule {
    private static let epoch = CalendarDate(year: 1970, month: 1, day: 1)!
    private static let secondsInDay = 86_400

    /// The date of an instant in a time zone. An instant out of the years 1 to 9999 gives the nearest of these dates.
    public static func dateOf(_ instant: Date, timeZone: TimeZone) -> CalendarDate {
        let millis = epochMillis(instant)
        let offset = timeZone.secondsFromGMT(for: instant)
        if let date = CalendarDate.ofInstant(epochMillis: millis, utcOffsetSeconds: offset) {
            return date
        }
        return millis < 0 ? CalendarDate(year: 1, month: 1, day: 1)! : CalendarDate(year: 9999, month: 12, day: 31)!
    }

    /// The minute after midnight of an instant on the clock of a time zone, from 0 to 1439.
    public static func minuteOfDay(_ instant: Date, timeZone: TimeZone) -> Int {
        let local = Int((instant.timeIntervalSince1970).rounded(.down)) + timeZone.secondsFromGMT(for: instant)
        let secondOfDay = ((local % secondsInDay) + secondsInDay) % secondsInDay
        return secondOfDay / 60
    }

    /// The instant of the reminder of `date` at `time` in a time zone. A time that the clock skips (daylight saving
    /// time) moves forward by the gap. A time that the clock has two times is the first of the two.
    public static func triggerAt(_ date: CalendarDate, time: ReminderTime, timeZone: TimeZone) -> Date {
        let local = epoch.daysUntil(date) * secondsInDay + time.minuteOfDay * 60
        // The offsets that can apply near the local time. Two transitions are never less than one day apart.
        let offsets = Set([-secondsInDay, 0, secondsInDay].map { timeZone.secondsFromGMT(for: seconds(local + $0)) })
        let valid = offsets.map { local - $0 }.filter { timeZone.secondsFromGMT(for: seconds($0)) == local - $0 }
        if let first = valid.min() {
            return seconds(first)
        }
        // The time is in a gap. The offset before the gap moves it forward by the length of the gap.
        let before = timeZone.secondsFromGMT(for: seconds(local - secondsInDay))
        return seconds(local - before)
    }

    /// The date of the first reminder after the person turns reminders on or changes the time.
    public static func firstDate(now: Date, timeZone: TimeZone, time: ReminderTime, lastDate: CalendarDate?)
        -> CalendarDate
    {
        let today = dateOf(now, timeZone: timeZone)
        if lastDate != today && triggerAt(today, time: time, timeZone: timeZone) > now {
            return today
        }
        return nextDay(today)
    }

    /// The date of the last reminder, or nil when it is after today. A date after today comes from a clock that went
    /// back. It must not stop the reminder of that date when the date comes.
    public static func knownLastDate(_ lastDate: CalendarDate?, now: Date, timeZone: TimeZone) -> CalendarDate? {
        guard let lastDate, lastDate <= dateOf(now, timeZone: timeZone) else {
            return nil
        }
        return lastDate
    }

    /// The date of the next reminder after the reminder of `ranOn`, the date of the device when it ran.
    public static func dateAfterRun(_ ranOn: CalendarDate) -> CalendarDate {
        nextDay(ranOn)
    }

    /// The date of the next reminder after a restart of the phone, an update or a start of the app, or a change of
    /// the clock or the time zone. A `stored` date in the past becomes today, so that the reminder of today comes. Its
    /// instant can then be in the past, and the reminder comes at once. A stored date more than one day ahead (the
    /// clock went back) is calculated again.
    public static func restoredDate(
        stored: CalendarDate?,
        now: Date,
        timeZone: TimeZone,
        time: ReminderTime,
        lastDate: CalendarDate?
    ) -> CalendarDate {
        let today = dateOf(now, timeZone: timeZone)
        guard let stored, stored <= nextDay(today) else {
            return firstDate(now: now, timeZone: timeZone, time: time, lastDate: lastDate)
        }
        if lastDate == today {
            return nextDay(today)
        }
        return stored < today ? today : stored
    }

    /// The next date. The last date of the calendar stays.
    static func nextDay(_ date: CalendarDate) -> CalendarDate {
        date.plusDays(1) ?? date
    }

    private static func epochMillis(_ instant: Date) -> Int {
        Int((instant.timeIntervalSince1970 * 1000).rounded(.down))
    }

    private static func seconds(_ value: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(value))
    }
}
