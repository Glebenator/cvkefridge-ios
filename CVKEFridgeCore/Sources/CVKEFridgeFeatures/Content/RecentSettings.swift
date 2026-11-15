import Foundation

// The products that the person removed from the recent foods of the add form.
// The Android file `app/src/main/java/com/cvke/fridge/settings/RecentSettings.kt` in cvkefridge-android has the same
// JSON shape. The Android file `settings/AppearanceSettings.kt` has only the setting for the wallpaper colours, which
// iOS does not have, so it has no Swift file.

/// The list of recent foods of the add form. The app keeps it in one small JSON file. It is not in the change log: it
/// does not change the inventory, and it stays on the phone.
public struct RecentSettings: Hashable, Sendable, Codable {
    /// The instant when the person removed each product from the list, in milliseconds from 1970-01-01T00:00:00Z, by
    /// the identifier of the product. A product comes back when it is added, used, or thrown away after that instant.
    public var hidden: [String: Int]

    public init(hidden: [String: Int] = [:]) {
        self.hidden = hidden
    }

    /// The settings after the person removed the `food` from the list at the instant `now`.
    ///
    /// The instant is not before the instant of the food. A change can have an instant after the clock, when the
    /// clock of the phone went back (`NewChanges.stamp`). The Android app keeps the instant of the clock, so the food
    /// then stays in the list.
    public func hiding(_ food: RecentFood, now: Int) -> RecentSettings {
        var next = self
        next.hidden[food.product.id] = max(now, food.at)
        return next
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
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hidden = try container.decodeIfPresent([String: Int].self, forKey: .hidden) ?? [:]
    }
}
