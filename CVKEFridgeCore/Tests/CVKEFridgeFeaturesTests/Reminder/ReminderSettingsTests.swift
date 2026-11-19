import CVKEFridgeFeatures
import Foundation
import Testing

/// The default reminder settings, and the file that keeps them. The Android test `ReminderSettingsTest` has the same
/// cases.
struct ReminderSettingsTests {
    private func read(_ text: String) throws -> ReminderSettings {
        try ReminderSettings.decode(Data(text.utf8))
    }

    @Test func theDefaultsAreOffAt0900WithTheExpiringRule() throws {
        let settings = ReminderSettings.defaults
        #expect(!settings.enabled)
        #expect(settings.time == ReminderTime(hour: 9, minute: 0))
        #expect(settings.leadDays == Freshness.expiringWithinDays)
        #expect(!settings.offerDismissed)
        #expect(!settings.permissionAsked)
        #expect(settings.next == nil)
        #expect(settings.last == nil)
        #expect(try read("") == settings)
    }

    @Test func theSettingsGoThroughTheFile() throws {
        let settings = ReminderSettings(
            enabled: true,
            minuteOfDay: 7 * 60 + 30,
            leadDays: 0,
            offerDismissed: true,
            permissionAsked: true,
            nextDate: "2026-11-13",
            lastDate: "2026-11-12"
        )
        #expect(try ReminderSettings.decode(settings.encode()) == settings)
        #expect(settings.time == ReminderTime(hour: 7, minute: 30))
        #expect(settings.next == CalendarDate(year: 2026, month: 11, day: 13))
        #expect(settings.last == CalendarDate(year: 2026, month: 11, day: 12))
        // The file has each key, also a date that is null.
        let keys = try JSONSerialization.jsonObject(with: ReminderSettings.defaults.encode()) as? [String: Any]
        #expect(Set(keys?.keys ?? [:].keys) == ["enabled", "minuteOfDay", "leadDays", "offerDismissed", "permissionAsked", "nextDate", "lastDate"])
    }

    @Test func aMissingValueGetsItsDefaultAndAnUnknownKeyIsIgnored() throws {
        #expect(try read(#"{"enabled":true,"newerSetting":3}"#) == ReminderSettings(enabled: true))
    }

    @Test func aValueOutOfRangeGetsItsDefault() throws {
        let settings = try read(#"{"enabled":true,"minuteOfDay":1440,"leadDays":9,"nextDate":"2026-13-01","lastDate":"yesterday"}"#)
        #expect(settings == ReminderSettings(enabled: true))
    }

    @Test func aFileThatIsNotJsonIsDamaged() {
        #expect(throws: ReminderSettings.DamagedFile.self) { try read("not json") }
        #expect(throws: ReminderSettings.DamagedFile.self) { try read(#"{"enabled":"maybe"}"#) }
        // iOS: also a null for a value that cannot be null, as kotlinx-serialization does on Android.
        #expect(throws: ReminderSettings.DamagedFile.self) { try read(#"{"enabled":null}"#) }
    }
}
