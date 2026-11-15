import Foundation

// The content of a reminder notification. The Android file `app/src/main/java/com/cvke/fridge/reminder/ReminderText.kt`
// in cvkefridge-android makes the same content, with the words of its string resources. Here the content is values:
// the app makes the words from its string catalog.

/// The days left of a food in a line of the reminder. The words are the words of the screens.
public enum ReminderDaysLeft: Hashable, Sendable {
    /// "Expired yesterday". A batch is in a reminder only one day after its expiry date.
    case expiredYesterday
    /// "Expires today".
    case expiresToday
    /// "Expires tomorrow".
    case expiresTomorrow
    /// "Expires in N days", with N 2 or more.
    case expiresInDays(Int)

    /// The value for a number of days left. A negative number is "expired yesterday".
    public init(daysLeft: Int) {
        switch daysLeft {
        case ..<0:
            self = .expiredYesterday
        case 0:
            self = .expiresToday
        case 1:
            self = .expiresTomorrow
        default:
            self = .expiresInDays(daysLeft)
        }
    }
}

/// One line of the expanded notification: "Expires today, estimated: Baby spinach". The days left come first,
/// because the system can cut a long line at its end.
public struct ReminderLine: Hashable, Sendable {
    public let productId: String
    /// The full name of the food.
    public let name: String
    public let daysLeft: ReminderDaysLeft
    /// True when the app adds "estimated" after the days left.
    public let estimated: Bool

    public init(productId: String, name: String, daysLeft: ReminderDaysLeft, estimated: Bool) {
        self.productId = productId
        self.name = name
        self.daysLeft = daysLeft
        self.estimated = estimated
    }
}

/// The content of a reminder notification.
public struct ReminderMessage: Hashable, Sendable {
    /// The number of foods, for the title: "3 items need attention".
    public let count: Int
    /// The first names, cut to `ReminderText.maxName` characters, for the short text: "Chicken thighs, Baby spinach".
    public let names: [String]
    /// The number of foods that are not in `names`, for the short text: "… and 2 more". 0 when all names are there.
    public let moreNames: Int
    /// One line for each food when the notification is expanded, up to `ReminderText.maxLines` lines with the last
    /// line.
    public let lines: [ReminderLine]
    /// The number of foods that have no line, for a last line: "And 3 more". 0 when each food has a line.
    public let moreLines: Int

    public init(count: Int, names: [String], moreNames: Int, lines: [ReminderLine], moreLines: Int) {
        self.count = count
        self.names = names
        self.moreNames = moreNames
        self.lines = lines
        self.moreLines = moreLines
    }
}

/// Makes the content of a reminder from its foods, in the order of `ReminderRules.foods`.
public enum ReminderText {
    /// The number of names in the short text. With more, the count of the others does not fit in one line.
    public static let namesInText = 2

    /// The largest number of lines in the expanded notification, with the line for the foods that do not fit.
    public static let maxLines = 5

    /// The longest name in the short text, in characters. A longer name is cut, so that the number of the other foods
    /// stays visible.
    public static let maxName = 28

    /// The content for the `foods`, or nil when there are no foods. A reminder with no foods is not shown.
    public static func message(_ foods: [ReminderFood]) -> ReminderMessage? {
        if foods.isEmpty {
            return nil
        }
        // All foods have a line when they fit. Otherwise the last line says how many foods do not have a line.
        let shown = foods.count <= maxLines ? foods : Array(foods.prefix(maxLines - 1))
        return ReminderMessage(
            count: foods.count,
            names: foods.prefix(namesInText).map { short($0.name) },
            moreNames: max(foods.count - namesInText, 0),
            lines: shown.map {
                ReminderLine(
                    productId: $0.productId,
                    name: $0.name,
                    daysLeft: ReminderDaysLeft(daysLeft: $0.daysLeft),
                    estimated: $0.estimated
                )
            },
            moreLines: foods.count - shown.count
        )
    }

    /// The name, cut to `maxName` characters with an ellipsis at the end. A character is a `Character`, so that the
    /// cut does not break an emoji or a letter with an accent.
    public static func short(_ name: String) -> String {
        if name.count <= maxName {
            return name
        }
        var cut = Substring(name.prefix(maxName - 1))
        while let last = cut.last, last.isWhitespace {
            cut = cut.dropLast()
        }
        return cut + "…"
    }
}
