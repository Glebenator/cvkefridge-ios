import CVKEFridgeFeatures
import Foundation

// The words of a reminder notification and of the reminder settings.

extension Wording {
    /// The title of a reminder: "1 item needs attention", "3 items need attention".
    static func reminderTitle(_ message: ReminderMessage) -> String {
        String(
            localized: "\(message.count) items need attention",
            comment: "The title of a reminder notification. The catalog has the plural forms."
        )
    }

    /// The short text of a reminder: "Chicken thighs, Baby spinach and 2 more".
    static func reminderNames(_ message: ReminderMessage) -> String {
        let separator = String(localized: ", ", comment: "Between two names of food in a reminder.")
        let names = message.names.joined(separator: separator)
        if message.moreNames > 0 {
            return String(localized: "\(names) and \(message.moreNames) more", comment: "A list of names of food, and the number of foods that are not in the list.")
        }
        return names
    }

    /// The lines of a reminder, one for each food: "Expires today, estimated: Baby spinach". The last line can be
    /// "And 3 more".
    static func reminderLines(_ message: ReminderMessage) -> [String] {
        var lines = message.lines.map { line in
            let days = reminderDaysLeft(line.daysLeft)
            let shown = line.estimated ? estimated(days) : days
            return String(localized: "\(shown): \(line.name)", comment: "The days left of a food, and its name.")
        }
        if message.moreLines > 0 {
            lines.append(String(localized: "And \(message.moreLines) more", comment: "The number of foods that have no line in a reminder."))
        }
        return lines
    }

    /// The days left in a line of a reminder, in words: "Expires in 2 days".
    static func reminderDaysLeft(_ daysLeft: ReminderDaysLeft) -> String {
        switch daysLeft {
        case .expiredYesterday:
            String(localized: "Expired yesterday")
        case .expiresToday:
            String(localized: "Expires today")
        case .expiresTomorrow:
            String(localized: "Expires tomorrow")
        case .expiresInDays(let days):
            String(localized: "Expires in \(days) days", comment: "A line of a reminder notification. The catalog has the plural forms.")
        }
    }

    /// A lead time of the reminder settings: "On the expiry date", "2 days before the expiry date".
    static func reminderLead(days: Int) -> String {
        switch days {
        case ...0:
            String(localized: "On the expiry date")
        default:
            String(
                localized: "\(days) days before the expiry date",
                comment: "A lead time of the reminders. The catalog has the plural forms."
            )
        }
    }

    /// A time of the clock in the format of the locale: "9:00 AM".
    static func time(_ time: ReminderTime, locale: Locale = .current) -> String {
        var components = DateComponents()
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = time.hour
        components.minute = time.minute
        let instant = utcCalendar.date(from: components) ?? .distantPast
        var format = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale)
        format.timeZone = .gmt
        return instant.formatted(format)
    }
}
