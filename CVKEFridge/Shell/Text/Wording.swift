import CVKEFridgeFeatures
import Foundation

// The words of the app. The rules of `CVKEFridgeFeatures` give values, and this folder makes the words that the
// person reads. Each screen uses these functions, so that one value has the same words on each screen.
//
// The English words are the words of `res/values/strings.xml` and `ui/DisplayFormat.kt` of the Android app. A text
// that names Android names iOS here.
//
// Each text is a key of the string catalog (`String(localized:)`). A text with a count has two keys, one for the count
// 1 and one for each other count, as the `plurals` of Android. The key for the other counts has the count as a
// number, so that the string catalog can give it the plural forms of a language that has more than two.
//
// | File | Words |
// | --- | --- |
// | `Wording.swift` | Numbers, quantities, dates, the days left, and the greeting |
// | `Wording+Labels.swift` | Categories, units, storage kinds, storage areas, sort orders, the history filters |
// | `Wording+Messages.swift` | Messages, the problems of a field, and the reasons of the core |
// | `Wording+Reminders.swift` | The text of a reminder notification, and the reminder settings |

/// The words for numbers, quantities, dates, and the days left.
enum Wording {
    /// The sign between two short values on one line: "2 l • Expires in 3d".
    static let separator = "•"

    /// The sign in the place of a number that is not loaded.
    static let noValue = "—"

    // MARK: Numbers and quantities

    /// A whole number in the format of the locale: "1,250".
    static func number(_ value: Int, locale: Locale = .current) -> String {
        value.formatted(.number.locale(locale))
    }

    /// A quantity in thousandths with its unit, for the locale of the device: "1.5 l", "2 packs", "3".
    static func quantity(_ thousandths: Int, unit: MeasureUnit?, locale: Locale = .current) -> String {
        let display = QuantityDisplay(thousandths: thousandths, unit: unit)
        let number = display.number(locale: locale)
        guard let unit else {
            return number
        }
        // The key with a number is for a whole quantity. A quantity with a fraction uses the plural form "other".
        let count = display.pluralCount
        switch unit {
        case .pcs:
            return String(localized: "\(number) pcs", comment: "A quantity with its unit. The value is a number.")
        case .g:
            return String(localized: "\(number) g", comment: "A quantity with its unit. The value is a number.")
        case .kg:
            return String(localized: "\(number) kg", comment: "A quantity with its unit. The value is a number.")
        case .ml:
            return String(localized: "\(number) ml", comment: "A quantity with its unit. The value is a number.")
        case .l:
            return String(localized: "\(number) l", comment: "A quantity with its unit. The value is a number.")
        case .pack:
            return count == 1 ? String(localized: "\(number) pack") : String(localized: "\(number) packs")
        case .bottle:
            return count == 1 ? String(localized: "\(number) bottle") : String(localized: "\(number) bottles")
        case .slice:
            return count == 1 ? String(localized: "\(number) slice") : String(localized: "\(number) slices")
        case .cup:
            return count == 1 ? String(localized: "\(number) cup") : String(localized: "\(number) cups")
        }
    }

    /// A number of foods: "1 item", "12 items".
    static func itemCount(_ count: Int) -> String {
        count == 1 ? String(localized: "\(count) item") : String(localized: "\(count) items")
    }

    /// A number of batches: "1 batch", "2 batches".
    static func batchCount(_ count: Int) -> String {
        count == 1 ? String(localized: "\(count) batch") : String(localized: "\(count) batches")
    }

    /// The number of different expiry dates of the batches of a food: "2 expiry dates".
    static func expiryDateCount(_ count: Int) -> String {
        count == 1 ? String(localized: "\(count) expiry date") : String(localized: "\(count) expiry dates")
    }

    // MARK: The days left

    /// The days left, with the same words on each screen: "Expired 3d ago", "Expired yesterday", "Expires today",
    /// "Expires tomorrow", "Expires in 5d", or "No expiry". A date that the app estimated ends with ", estimated".
    static func expiry(daysLeft: Int?, expiry: ExpiryDate?) -> String {
        text(ExpiryText.of(daysLeft: daysLeft, expiry: expiry))
    }

    /// The words of an expiry text.
    static func text(_ expiry: ExpiryText) -> String {
        let phrase = text(expiry.phrase)
        return expiry.estimated ? estimated(phrase) : phrase
    }

    /// The words of an expiry phrase, with no ", estimated".
    static func text(_ phrase: ExpiryPhrase) -> String {
        switch phrase {
        case .noExpiry:
            return String(localized: "No expiry")
        case .expiredDaysAgo(let days):
            return String(localized: "Expired \(days)d ago", comment: "\"d\" is the short form of \"days\".")
        case .expiredYesterday:
            return String(localized: "Expired yesterday")
        case .expiresToday:
            return String(localized: "Expires today")
        case .expiresTomorrow:
            return String(localized: "Expires tomorrow")
        case .expiresInDays(let days):
            return String(localized: "Expires in \(days)d", comment: "\"d\" is the short form of \"days\".")
        }
    }

    /// A text with ", estimated" after it: "Expires in 3d, estimated", "May 11, 2027, estimated".
    static func estimated(_ text: String) -> String {
        String(localized: "\(text), estimated", comment: "The value is the days left or a date that the app estimated.")
    }

    // MARK: Dates

    /// A date in the medium format of the locale: "Nov 18, 2026".
    static func date(_ date: CalendarDate, locale: Locale = .current) -> String {
        instant(of: date).formatted(dateStyle(.abbreviated, locale: locale))
    }

    /// A date in the full format of the locale, with the day of the week: "Thursday, November 12, 2026".
    static func longDate(_ date: CalendarDate, locale: Locale = .current) -> String {
        instant(of: date).formatted(dateStyle(.complete, locale: locale))
    }

    /// The expiry date of a batch with its source: "Printed date: Nov 20, 2026", "Estimated date: …", or
    /// "Your date: …" for a date that the person chose because the food was still good.
    static func dateWithSource(_ expiry: ExpiryDate) -> String {
        let text = date(expiry.date)
        switch expiry.source {
        case .printed:
            return String(localized: "Printed date: \(text)")
        case .estimated:
            return String(localized: "Estimated date: \(text)")
        case .chosen:
            return String(localized: "Your date: \(text)")
        }
    }

    /// The date added of a batch: "Added Nov 10, 2026".
    static func dateAdded(_ date: CalendarDate) -> String {
        String(localized: "Added \(Wording.date(date))")
    }

    /// The instant of 12:00 of a calendar date in UTC. The date formats use UTC, so the text has the same date in
    /// each time zone.
    static func instant(of date: CalendarDate) -> Date {
        var components = DateComponents()
        components.year = date.year
        components.month = date.month
        components.day = date.day
        components.hour = 12
        return utcCalendar.date(from: components) ?? .distantPast
    }

    /// The calendar date of an instant of a date picker. The pickers of the app use `Wording.utcCalendar`.
    static func calendarDate(of instant: Date) -> CalendarDate? {
        let components = utcCalendar.dateComponents([.year, .month, .day], from: instant)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }
        return CalendarDate(year: year, month: month, day: day)
    }

    /// The Gregorian calendar in UTC. A calendar date of the core is a Gregorian date with no time zone.
    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private static func dateStyle(_ style: Date.FormatStyle.DateStyle, locale: Locale) -> Date.FormatStyle {
        var format = Date.FormatStyle(date: style, time: .omitted, locale: locale)
        format.timeZone = .gmt
        return format
    }

    // MARK: Home

    /// "Good morning" before 12:00, "Good afternoon" before 17:00, and then "Good evening", for the clock of the
    /// device.
    static func greeting(at instant: Date = Date(), timeZone: TimeZone = .current) -> String {
        switch ReminderSchedule.minuteOfDay(instant, timeZone: timeZone) / 60 {
        case ..<12:
            return String(localized: "Good morning")
        case ..<17:
            return String(localized: "Good afternoon")
        default:
            return String(localized: "Good evening")
        }
    }

    // MARK: Storage tips

    /// The time that a food keeps in a storage kind: "About 3 days.", "About 1 week."
    static func text(_ time: KeepTime) -> String {
        let count = time.count
        switch time.unit {
        case .days:
            return count == 1 ? String(localized: "About \(count) day.") : String(localized: "About \(count) days.")
        case .weeks:
            return count == 1 ? String(localized: "About \(count) week.") : String(localized: "About \(count) weeks.")
        case .months:
            return count == 1 ? String(localized: "About \(count) month.") : String(localized: "About \(count) months.")
        case .years:
            return count == 1 ? String(localized: "About \(count) year.") : String(localized: "About \(count) years.")
        }
    }

    /// Where an estimate comes from: "Estimate for Butter (Fridge): 30 days." It is nil when the food has no days for
    /// the storage kind.
    static func estimateHint(food: Food?, kind: StorageKind?) -> String? {
        guard let food, let kind, let days = food.days[kind] else {
            return nil
        }
        let name = foodName(food)
        return days == 1
            ? String(localized: "Estimate for \(name) (\(kind.label)): \(days) day.")
            : String(localized: "Estimate for \(name) (\(kind.label)): \(days) days.")
    }

    /// A food of the table of foods with the text that tells it from other foods: "Cheese, processed slices".
    static func foodName(_ food: Food) -> String {
        guard let subtitle = food.subtitle else {
            return food.name
        }
        return String(localized: "\(food.name), \(subtitle)", comment: "A food and the text that tells it from other foods.")
    }
}

extension QuantityDisplay {
    /// The quantity with its unit, for the locale of the device: "1.5 l", "2 packs", "3".
    var text: String {
        Wording.quantity(thousandths, unit: unit)
    }
}

extension ExpiryText {
    /// The words of the expiry text: "Expires in 3d, estimated".
    var text: String {
        Wording.text(self)
    }
}
