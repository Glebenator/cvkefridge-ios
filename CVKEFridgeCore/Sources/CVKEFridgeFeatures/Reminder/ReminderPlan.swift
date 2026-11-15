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
/// 2. The dates are today and the days after it, `horizonDays` dates in all. A date with no food has no reminder.
/// 3. Today has a reminder only when its time has not passed, and today had no reminder (`ReminderSettings.last`).
///    The time has passed from the first second of its minute: at 09:00:00 and at 09:00:30, a reminder at 09:00 is
///    not planned for today. This is the rule of Android (`ReminderSchedule.firstDate`), where the instant of the
///    reminder must be after now.
/// 4. When the inventory changes, the plan is old. The app makes the plan again and replaces the planned
///    notifications.
public enum ReminderPlan {
    /// The number of dates of a plan at the start: two weeks. iOS keeps not more than 64 planned notifications of an
    /// app.
    public static let defaultHorizonDays = 14

    /// The reminders of the next `horizonDays` dates from `today`.
    ///
    /// - Parameters:
    ///   - today: The date of the device now.
    ///   - nowMinuteOfDay: The minute of now on the clock of the device, from 0 to 1439. The seconds have no effect.
    public static func reminders(
        inventory: Inventory,
        settings: ReminderSettings,
        today: CalendarDate,
        nowMinuteOfDay: Int,
        horizonDays: Int = defaultHorizonDays
    ) -> [PlannedReminder] {
        let time = settings.normalized().time
        return plan(
            inventory: inventory,
            settings: settings,
            today: today,
            todayTimeAhead: nowMinuteOfDay < time.minuteOfDay,
            horizonDays: horizonDays
        )
    }

    /// The reminders of the next `horizonDays` dates from the date of `now` in the time zone. Today's reminder is
    /// planned when its instant (`ReminderSchedule.triggerAt`) is after `now`. On a day when the clock skips the time
    /// of the reminder, the reminder is later by the gap, so it can still be ahead.
    public static func reminders(
        inventory: Inventory,
        settings: ReminderSettings,
        now: Date,
        timeZone: TimeZone,
        horizonDays: Int = defaultHorizonDays
    ) -> [PlannedReminder] {
        let today = ReminderSchedule.dateOf(now, timeZone: timeZone)
        let time = settings.normalized().time
        return plan(
            inventory: inventory,
            settings: settings,
            today: today,
            todayTimeAhead: ReminderSchedule.triggerAt(today, time: time, timeZone: timeZone) > now,
            horizonDays: horizonDays
        )
    }

    private static func plan(
        inventory: Inventory,
        settings: ReminderSettings,
        today: CalendarDate,
        todayTimeAhead: Bool,
        horizonDays: Int
    ) -> [PlannedReminder] {
        let settings = settings.normalized()
        guard settings.enabled, horizonDays > 0 else {
            return []
        }
        var reminders: [PlannedReminder] = []
        for offset in 0..<horizonDays {
            if offset == 0 && (!todayTimeAhead || settings.last == today) {
                continue
            }
            guard let date = today.plusDays(offset) else {
                break
            }
            let foods = ReminderRules.foods(inventory, today: date, leadDays: settings.leadDays)
            if !foods.isEmpty {
                reminders.append(PlannedReminder(date: date, time: settings.time, foods: foods))
            }
        }
        return reminders
    }
}
