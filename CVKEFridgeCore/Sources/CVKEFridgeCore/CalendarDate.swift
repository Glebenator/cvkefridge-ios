import Foundation

/// A date in the Gregorian calendar, from 0001-01-01 to 9999-12-31. Rule 2 of `spec/rules.md`.
/// The Android file `core/src/main/kotlin/com/cvke/fridge/core/CalendarDate.kt` in cvkefridge-android has the same
/// behaviour.
///
/// Only a valid date can exist. The calculations use day numbers from 1970-01-01. They do not use the system calendar
/// or a time zone.
public struct CalendarDate: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// The day number of 0001-01-01.
    private static let firstDayNumber = -719_162
    /// The day number of 9999-12-31.
    private static let lastDayNumber = 2_932_896
    /// The milliseconds in one day.
    private static let millisPerDay = 86_400_000

    /// The date with these values, or nil if the values do not make a valid date.
    public init?(year: Int, month: Int, day: Int) {
        guard year >= 1, year <= 9999, month >= 1, month <= 12, day >= 1,
              day <= CalendarDate.daysInMonth(year: year, month: month)
        else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    /// The date of a text in the form `YYYY-MM-DD`, or nil. The text must have exactly 10 characters: 4 digits, `-`,
    /// 2 digits, `-`, and 2 digits. Only the ASCII digits 0 to 9 are digits. Spaces are not removed.
    public static func parse(_ text: String) -> CalendarDate? {
        let bytes = Array(text.utf8)
        guard bytes.count == 10, bytes[4] == 0x2D, bytes[7] == 0x2D,
              let year = number(bytes, from: 0, to: 4),
              let month = number(bytes, from: 5, to: 7),
              let day = number(bytes, from: 8, to: 10)
        else {
            return nil
        }
        return CalendarDate(year: year, month: month, day: day)
    }

    /// The date of an instant at a UTC offset in seconds, or nil if that date is not in the years 1 to 9999.
    /// The day number is `floor((epochMillis + utcOffsetSeconds * 1000) / 86400000)` from 1970-01-01.
    public static func ofInstant(epochMillis: Int, utcOffsetSeconds: Int) -> CalendarDate? {
        let (offsetMillis, offsetOverflow) = utcOffsetSeconds.multipliedReportingOverflow(by: 1000)
        if offsetOverflow {
            return nil
        }
        let (localMillis, sumOverflow) = epochMillis.addingReportingOverflow(offsetMillis)
        if sumOverflow {
            return nil
        }
        return ofDayNumber(floorDiv(localMillis, millisPerDay))
    }

    /// The text form `YYYY-MM-DD`.
    public var text: String {
        let yearText = CalendarDate.padded(year, width: 4)
        let monthText = CalendarDate.padded(month, width: 2)
        let dayText = CalendarDate.padded(day, width: 2)
        return "\(yearText)-\(monthText)-\(dayText)"
    }

    /// The text form `YYYY-MM-DD`.
    public var description: String {
        text
    }

    /// The date that is `days` days later, or earlier for a negative number. Nil if the result is before year 1 or
    /// after year 9999.
    public func plusDays(_ days: Int) -> CalendarDate? {
        let (sum, overflow) = dayNumber.addingReportingOverflow(days)
        if overflow {
            return nil
        }
        return CalendarDate.ofDayNumber(sum)
    }

    /// The days from this date to `other`. The number is positive when `other` is later.
    public func daysUntil(_ other: CalendarDate) -> Int {
        other.dayNumber - dayNumber
    }

    /// An earlier date is less than a later date.
    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }
        if lhs.month != rhs.month {
            return lhs.month < rhs.month
        }
        return lhs.day < rhs.day
    }

    /// The quotient rounded down, also for negative numbers. The operator `/` rounds toward zero.
    static func floorDiv(_ dividend: Int, _ divisor: Int) -> Int {
        let quotient = dividend / divisor
        if dividend % divisor != 0 && (dividend < 0) != (divisor < 0) {
            return quotient - 1
        }
        return quotient
    }

    /// The days from 1970-01-01 to this date. The algorithm is "days from civil" by Howard Hinnant. A year starts on
    /// 1 March, so that the leap day is the last day of the year.
    var dayNumber: Int {
        let shiftedYear = month <= 2 ? year - 1 : year
        let era = CalendarDate.floorDiv(shiftedYear, 400)
        let yearOfEra = shiftedYear - era * 400
        let shiftedMonth = month > 2 ? month - 3 : month + 9
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    /// The date of a day number from 1970-01-01, or nil if it is not in the years 1 to 9999. The algorithm is
    /// "civil from days" by Howard Hinnant.
    private static func ofDayNumber(_ dayNumber: Int) -> CalendarDate? {
        guard dayNumber >= firstDayNumber, dayNumber <= lastDayNumber else {
            return nil
        }
        let shifted = dayNumber + 719_468
        let era = floorDiv(shifted, 146_097)
        let dayOfEra = shifted - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shiftedMonth = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
        let month = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9
        let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
        return CalendarDate(year: year, month: month, day: day)
    }

    private static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2:
            return isLeapYear(year) ? 29 : 28
        case 4, 6, 9, 11:
            return 30
        default:
            return 31
        }
    }

    /// A year that divides by 4 is a leap year, but not a year that divides by 100, unless it divides by 400.
    private static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    /// The number of the ASCII digits from `start` up to `end`, or nil if a byte is not a digit 0 to 9.
    private static func number(_ bytes: [UInt8], from start: Int, to end: Int) -> Int? {
        var value = 0
        for index in start..<end {
            let byte = bytes[index]
            guard byte >= 0x30, byte <= 0x39 else {
                return nil
            }
            value = value * 10 + Int(byte - 0x30)
        }
        return value
    }

    /// The digits of a value that is not negative, with zeros at the start to make `width` digits.
    private static func padded(_ value: Int, width: Int) -> String {
        let digits = String(value)
        if digits.count >= width {
            return digits
        }
        return String(repeating: "0", count: width - digits.count) + digits
    }
}
