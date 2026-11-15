import Foundation

// The reminder settings of the person, and the state of the schedule. The Android file
// `app/src/main/java/com/cvke/fridge/reminder/ReminderSettings.kt` in cvkefridge-android has the same values, the
// same defaults, the same checks, and the same JSON form.

/// The reminder settings of the person, and the state of the schedule. The app keeps them in one small JSON file
/// (see `decode(_:)` and `encode()`).
public struct ReminderSettings: Hashable, Sendable {
    /// 09:00, before the day of most people starts.
    public static let defaultMinuteOfDay = 9 * 60
    /// The minutes in one day.
    public static let minutesInDay = ReminderTime.minutesInDay

    /// True when the person turned reminders on.
    public var enabled: Bool
    /// The time of the reminder, in minutes after midnight on the clock of the device.
    public var minuteOfDay: Int
    /// The days before the expiry date from which a batch is in the reminder (see `ReminderRules`).
    public var leadDays: Int
    /// True when the person closed the offer of reminders on Home, or did not allow notifications from it. Home does
    /// not show the offer again. The settings screen always has the switch.
    public var offerDismissed: Bool
    /// True after the app asked the system for the notification permission one time.
    public var permissionAsked: Bool
    /// The date of the next reminder, in the form `YYYY-MM-DD`, or nil when reminders are off.
    public var nextDate: String?
    /// The date of the last reminder, in the form `YYYY-MM-DD`, or nil. The reminder of a date comes one time only.
    public var lastDate: String?

    public init(
        enabled: Bool = false,
        minuteOfDay: Int = defaultMinuteOfDay,
        leadDays: Int = ReminderRules.defaultLeadDays,
        offerDismissed: Bool = false,
        permissionAsked: Bool = false,
        nextDate: String? = nil,
        lastDate: String? = nil
    ) {
        self.enabled = enabled
        self.minuteOfDay = minuteOfDay
        self.leadDays = leadDays
        self.offerDismissed = offerDismissed
        self.permissionAsked = permissionAsked
        self.nextDate = nextDate
        self.lastDate = lastDate
    }

    /// The default settings: reminders off, at 09:00, with the lead time of the "expiring" rule.
    public static let defaults = ReminderSettings()

    /// The time of the reminder on the clock of the device. A minute out of range gives the default time.
    public var time: ReminderTime {
        ReminderTime(minuteOfDay: minuteOfDay) ?? ReminderTime(minuteOfDay: Self.defaultMinuteOfDay)!
    }

    /// The date of `nextDate`, or nil.
    public var next: CalendarDate? {
        nextDate.flatMap(CalendarDate.parse)
    }

    /// The date of `lastDate`, or nil.
    public var last: CalendarDate? {
        lastDate.flatMap(CalendarDate.parse)
    }

    /// The same settings with each value in its range. A value from an older or a damaged file can be out of range.
    public func normalized() -> ReminderSettings {
        var result = self
        if !(0..<Self.minutesInDay).contains(minuteOfDay) {
            result.minuteOfDay = Self.defaultMinuteOfDay
        }
        if !ReminderRules.leadDayChoices.contains(leadDays) {
            result.leadDays = ReminderRules.defaultLeadDays
        }
        if next == nil {
            result.nextDate = nil
        }
        if last == nil {
            result.lastDate = nil
        }
        return result
    }

    /// Why the file of the settings cannot be read.
    public struct DamagedFile: Error, Hashable, Sendable {
        public let reason: String
    }

    /// The settings of a JSON file, with each value in its range. An empty file, or a file with only white space,
    /// gives the default settings. A missing value gets its default, and an unknown key is ignored, so that a newer or
    /// an older version of the app can read the file.
    ///
    /// - Throws: `DamagedFile` when the text is not JSON or a value has the wrong type. The app then replaces the file
    ///   with the default settings.
    public static func decode(_ data: Data) throws(DamagedFile) -> ReminderSettings {
        let text = String(decoding: data, as: UTF8.self)
        if text.allSatisfy(\.isWhitespace) {
            return defaults
        }
        do {
            return try JSONDecoder().decode(ReminderSettingsFile.self, from: data).settings.normalized()
        } catch {
            throw DamagedFile(reason: "The reminder settings are not valid")
        }
    }

    /// The JSON text of the settings, with each key.
    public func encode() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // The encoder of a value with only text, numbers, and Boolean values does not fail.
        return (try? encoder.encode(ReminderSettingsFile(settings: self))) ?? Data("{}".utf8)
    }
}

/// The JSON shape of the settings. A key with `null` for a value that cannot be null is not valid, as on Android.
private struct ReminderSettingsFile: Codable {
    let settings: ReminderSettings

    init(settings: ReminderSettings) {
        self.settings = settings
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case minuteOfDay
        case leadDays
        case offerDismissed
        case permissionAsked
        case nextDate
        case lastDate
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            container.contains(key) ? try container.decode(T.self, forKey: key) : fallback
        }
        let defaults = ReminderSettings.defaults
        settings = ReminderSettings(
            enabled: try value(.enabled, defaults.enabled),
            minuteOfDay: try value(.minuteOfDay, defaults.minuteOfDay),
            leadDays: try value(.leadDays, defaults.leadDays),
            offerDismissed: try value(.offerDismissed, defaults.offerDismissed),
            permissionAsked: try value(.permissionAsked, defaults.permissionAsked),
            nextDate: try container.decodeIfPresent(String.self, forKey: .nextDate),
            lastDate: try container.decodeIfPresent(String.self, forKey: .lastDate)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(settings.enabled, forKey: .enabled)
        try container.encode(settings.minuteOfDay, forKey: .minuteOfDay)
        try container.encode(settings.leadDays, forKey: .leadDays)
        try container.encode(settings.offerDismissed, forKey: .offerDismissed)
        try container.encode(settings.permissionAsked, forKey: .permissionAsked)
        try container.encode(settings.nextDate, forKey: .nextDate)
        try container.encode(settings.lastDate, forKey: .lastDate)
    }
}
