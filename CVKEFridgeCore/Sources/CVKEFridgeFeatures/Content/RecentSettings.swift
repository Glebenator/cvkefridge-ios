import Foundation

// The products that the person removed from the recent foods of the add form.
// The Android file `app/src/main/java/com/cvke/fridge/settings/RecentSettings.kt` in cvkefridge-android has the same
// JSON shape. The Android file `settings/AppearanceSettings.kt` has only the setting for the wallpaper colours, which
// iOS does not have, so it has no Swift file.

/// The list of recent foods of the add form. The app keeps it in one small JSON file. It is not in the change log: it
/// does not change the inventory, and it stays on the phone.
///
/// The Android app keeps the instant when the person removed a food (`hidden`). A clock that moves makes that instant
/// wrong. This app keeps the identifier of the newest change of the food at the time of the removal
/// (`hiddenChanges`). A food comes back when it gets a newer change. The app still reads the instants of an older
/// file, and uses them for those foods until the person removes the food again.
public struct RecentSettings: Hashable, Sendable, Codable {
    /// The instant when the person removed each product from the list, in milliseconds from 1970-01-01T00:00:00Z, by
    /// the identifier of the product. A product comes back when it is added, used, or thrown away after that instant.
    /// Only an older file has these values. A new removal goes into `hiddenChanges`.
    public var hidden: [String: Int]

    /// The identifier of the newest change of each product when the person removed it from the list, by the
    /// identifier of the product. A product comes back when its newest change is a different change.
    public var hiddenChanges: [String: String]

    public init(hidden: [String: Int] = [:], hiddenChanges: [String: String] = [:]) {
        self.hidden = hidden
        self.hiddenChanges = hiddenChanges
    }

    /// The settings after the person removed the `food` from the list. The settings keep the identifier of the newest
    /// change of the food (`RecentFood.changeId`), so a change of the clock has no effect.
    ///
    /// A food with no identifier of its change gets the instant: `now`, but not before the instant of the food. A
    /// change can have an instant after the clock, when the clock of the phone went back (`NewChanges.stamp`).
    public func hiding(_ food: RecentFood, now: Int) -> RecentSettings {
        var next = self
        if let changeId = food.changeId {
            next.hiddenChanges[food.product.id] = changeId
            next.hidden[food.product.id] = nil
        } else {
            next.hidden[food.product.id] = max(now, food.at)
        }
        return next
    }

    /// True when the person removed the `food` from the list and it has no newer change.
    public func hides(_ food: RecentFood) -> Bool {
        if let changeId = hiddenChanges[food.product.id] {
            return food.changeId == changeId
        }
        if let instant = hidden[food.product.id] {
            return food.at <= instant
        }
        return false
    }

    /// The settings in a JSON file. An empty file, or a file with only white space, gives the default settings. A
    /// missing value gets its default, and an unknown key has no effect. It throws for a file that is not valid. The
    /// app then replaces the file with the default settings, as on Android.
    public static func decode(_ data: Data) throws -> RecentSettings {
        let text = String(decoding: data, as: UTF8.self)
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return RecentSettings()
        }
        return try JSONDecoder().decode(RecentSettings.self, from: data)
    }

    /// The JSON file of the settings, with the keys in a fixed order.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case hidden
        case hiddenChanges
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hidden = try container.decodeIfPresent([String: Int].self, forKey: .hidden) ?? [:]
        hiddenChanges = try container.decodeIfPresent([String: String].self, forKey: .hiddenChanges) ?? [:]
    }

    /// Writes `hidden` always, as Android does, and `hiddenChanges` only when it has a value.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hidden, forKey: .hidden)
        if !hiddenChanges.isEmpty {
            try container.encode(hiddenChanges, forKey: .hiddenChanges)
        }
    }
}
