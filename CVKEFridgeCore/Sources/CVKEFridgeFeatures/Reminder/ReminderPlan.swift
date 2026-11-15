import Foundation

// The reminders that the iOS app plans ahead. Android has no such file: there, an alarm starts code at the time of the
// reminder, and that code reads the inventory (`Reminders.run`). iOS does not start the code of the app at a time. So
// the app plans the local notifications of the next days, and plans them again after each change of the inventory or
// of the settings, at each start, and after each change of the clock or of the time zone.

/// One reminder that the app plans: its date, its time on the clock of the device, and its foods.
public struct PlannedReminder: Hashable, Sendable {
    public let date: CalendarDate
    public let time: ReminderTime
    /// The foods of the reminder, in the order of `ReminderRules.foods`. The list is never empty.
    public let foods: [ReminderFood]

    public init(date: CalendarDate, time: ReminderTime, foods: [ReminderFood]) {
        self.date = date
        self.time = time
        self.foods = foods
    }

    /// The content of the notification.
    public var message: ReminderMessage {
        guard let message = ReminderText.message(foods) else {
            preconditionFailure("A planned reminder has foods")
        }
        return message
    }

    /// The instant of the reminder in a time zone (see `ReminderSchedule.triggerAt`).
    public func triggerAt(timeZone: TimeZone) -> Date {
        ReminderSchedule.triggerAt(date, time: time, timeZone: timeZone)
    }
}

/// The reminders of the coming days, for an inventory that does not change. For each date, the content is the content
/// that Android computes when its alarm goes off on that date: `ReminderRules.foods` with that date as "today". So an
/// expired batch is only in the reminder of the first day after its expiry date.
///
/// Rules:
/// 1. With reminders off, there is no reminder.
/// 2. The dates are today and the days after it, to the day after the latest expiry date: each date that has
///    something to say. A date with no food has no reminder. The plan has not more than `maxReminders` reminders, the
///    earliest first. iOS keeps not more than 64 planned notifications of an app, and the app can need some for other
///    things. When the app does not open for a long time, the reminders of the planned dates still come.
/// 3. Today has a reminder only when the instant of its time (`ReminderSchedule.triggerAt`) is after now, and today
///    had no reminder (`ReminderSettings.last`). The time has passed from the first second of its minute: at 09:00:00
///    and at 09:00:30, a reminder at 09:00 is not planned for today. This is the rule of Android
///    (`ReminderSchedule.firstDate`), where the instant of the reminder must be after now. The compare uses instants,
///    so a change of the clock for daylight saving time has the correct result.
/// 4. When the inventory changes, the plan is old. The app makes the plan again and replaces the planned
///    notifications.
public enum ReminderPlan {
    /// The largest number of reminders in a plan at the start. iOS keeps not more than 64 planned notifications of
    /// an app.
    public static let defaultMaxReminders = 30

    /// The number of dates of the old fixed plan: two weeks. A plan now has no fixed number of dates (rule 2). Give
    /// it as `horizonDays` only to stop the plan earlier.
    public static let defaultHorizonDays = 14

    /// The reminders from `today`, when the minute of now is known but not the instant.
    ///
    /// This function cannot be correct on a day with a change of the clock for daylight saving time: at 03:10 on a
    /// day when the clock skips from 02:00 to 03:00, a reminder at 02:30 comes at 03:30 and is still ahead, and in the
    /// hour that the clock repeats, the minute does not tell which of the two hours it is.
    ///
    /// - Parameters:
    ///   - today: The date of the device now.
    ///   - nowMinuteOfDay: The minute of now on the clock of the device, from 0 to 1439. The seconds have no effect.
    ///   - horizonDays: The largest number of dates, from today, or nil for no limit (rule 2).
    ///   - maxReminders: The largest number of reminders.
    @available(*, deprecated, message: "Use reminders(inventory:settings:now:timeZone:): only an instant is correct when the clock changes")
    public static func reminders(
        inventory: Inventory,
        settings: ReminderSettings,
        today: CalendarDate,
        nowMinuteOfDay: Int,
        horizonDays: Int? = nil,
        maxReminders: Int = defaultMaxReminders
    ) -> [PlannedReminder] {
        let time = settings.normalized().time
        return plan(
            inventory: inventory,
            settings: settings,
            today: today,
            todayTimeAhead: nowMinuteOfDay < time.minuteOfDay,
            horizonDays: horizonDays,
            maxReminders: maxReminders
        )
    }

    /// The reminders from the date of `now` in the time zone. Today's reminder is planned when its instant
    /// (`ReminderSchedule.triggerAt`) is after `now`. On a day when the clock skips the time of the reminder, the
    /// reminder is later by the gap, so it can still be ahead. When the clock repeats an hour, the reminder is at the
    /// first of the two times.
    ///
    /// - Parameters:
    ///   - horizonDays: The largest number of dates, from today, or nil for no limit (rule 2).
    ///   - maxReminders: The largest number of reminders.
    public static func reminders(
        inventory: Inventory,
        settings: ReminderSettings,
        now: Date,
        timeZone: TimeZone,
        horizonDays: Int? = nil,
        maxReminders: Int = defaultMaxReminders
    ) -> [PlannedReminder] {
        let today = ReminderSchedule.dateOf(now, timeZone: timeZone)
        let time = settings.normalized().time
        return plan(
            inventory: inventory,
            settings: settings,
            today: today,
            todayTimeAhead: ReminderSchedule.triggerAt(today, time: time, timeZone: timeZone) > now,
            horizonDays: horizonDays,
            maxReminders: maxReminders
        )
    }

    private static func plan(
        inventory: Inventory,
        settings: ReminderSettings,
        today: CalendarDate,
        todayTimeAhead: Bool,
        horizonDays: Int?,
        maxReminders: Int
    ) -> [PlannedReminder] {
        let settings = settings.normalized()
        guard settings.enabled, horizonDays.map({ $0 > 0 }) ?? true, maxReminders > 0 else {
            return []
        }
        let lastDate = horizonDays.flatMap { today.plusDays($0 - 1) }
        var reminders: [PlannedReminder] = []
        for date in candidateDates(inventory, leadDays: settings.leadDays) {
            if date < today || (lastDate.map { date > $0 } ?? false) {
                continue
            }
            if date == today && (!todayTimeAhead || settings.last == today) {
                continue
            }
            let foods = ReminderRules.foods(inventory, today: date, leadDays: settings.leadDays)
            if !foods.isEmpty {
                reminders.append(PlannedReminder(date: date, time: settings.time, foods: foods))
                if reminders.count == maxReminders {
                    break
                }
            }
        }
        return reminders
    }

    /// The dates on which a batch can be in a reminder, in order: for each expiry date, the dates from the lead time
    /// before it to the day after it (rule 1 of `ReminderRules`). Each date with a reminder is in the list, so the plan
    /// does not look at each day up to a far expiry date.
    private static func candidateDates(_ inventory: Inventory, leadDays: Int) -> [CalendarDate] {
        let lead = min(max(leadDays, ReminderRules.leadDayChoices.lowerBound), ReminderRules.leadDayChoices.upperBound)
        var dates = Set<CalendarDate>()
        for batch in inventory.activeBatches {
            guard let expiry = batch.expiry?.date else {
                continue
            }
            for offset in -lead...ReminderRules.expiredDays {
                if let date = expiry.plusDays(offset) {
                    dates.insert(date)
                }
            }
        }
        return dates.sorted()
    }
}

// MARK: - The notification of a planned reminder

/// The identifier and the trigger of the local notification of a planned reminder.
///
/// Rules:
/// 1. Each date has one identifier: `reminder-2026-11-14`. A new plan replaces the notification of the same date, and
///    the app can find the date of a notification that iOS shows.
/// 2. The trigger is the instant of `triggerAt(timeZone:)`, as a full date and time in the time zone of the device.
///    On a day when the clock skips the time of the reminder, the trigger is later by the gap. The date components
///    then always name a time that exists on the clock.
extension PlannedReminder {
    /// The start of the identifier of each planned reminder. The rest is the date.
    public static let identifierPrefix = "reminder-"

    /// The identifier of the notification of this reminder (rule 1).
    public var identifier: String {
        Self.identifierPrefix + date.text
    }

    /// The date of a notification identifier of a planned reminder, or nil for each other identifier.
    public static func date(ofIdentifier identifier: String) -> CalendarDate? {
        guard identifier.hasPrefix(identifierPrefix) else {
            return nil
        }
        return CalendarDate.parse(String(identifier.dropFirst(identifierPrefix.count)))
    }

    /// The date and the time of the trigger of the notification (rule 2): the Gregorian year, month, day, hour,
    /// minute, and second of the instant in the time zone, with the calendar and the time zone. The components give
    /// the same instant on each device, also when the person uses a calendar that is not Gregorian.
    public func triggerComponents(timeZone: TimeZone) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: triggerAt(timeZone: timeZone)
        )
        components.calendar = calendar
        components.timeZone = timeZone
        return components
    }
}
