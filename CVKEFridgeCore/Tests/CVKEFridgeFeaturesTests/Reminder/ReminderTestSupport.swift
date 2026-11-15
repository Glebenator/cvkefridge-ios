import CVKEFridgeFeatures
import Foundation

/// Inventories for the reminder tests, made with the replay of the core.
enum ReminderInventory {
    static func date(_ text: String) -> CalendarDate {
        guard let date = CalendarDate.parse(text) else {
            preconditionFailure("Not a date: \(text)")
        }
        return date
    }

    static func product(_ id: String, _ name: String? = nil) -> ChangeBody {
        .productSaved(
            product: Product(id: id, name: name ?? id, category: .other, unit: .pcs, barcode: nil, foodId: nil)
        )
    }

    static func batch(
        _ id: String,
        _ product: String,
        expires: String?,
        added: String = "2026-11-01",
        source: ExpirySource = .printed,
        area: String = "fridge"
    ) -> ChangeBody {
        .batchAdded(
            batch: Batch(
                id: id,
                productId: product,
                quantity: 1000,
                storageAreaId: area,
                dateAdded: date(added),
                expiry: expires.map { ExpiryDate(date: date($0), source: source) }
            )
        )
    }

    static func inventory(_ bodies: [ChangeBody]) -> Inventory {
        Inventory.replay(bodies.enumerated().map { Change(id: "c\($0.offset)", at: $0.offset, origin: "test", body: $0.element) })
    }

    static func inventory(_ bodies: ChangeBody...) -> Inventory {
        inventory(bodies)
    }
}

/// The English words of the Android string resources (`values/strings.xml`) for a reminder, with the plural rule of
/// English. The app makes these words from its string catalog. The tests use them to compare the same texts as the
/// Android tests.
enum EnglishReminder {
    struct Text: Equatable {
        let title: String
        let text: String
        let lines: [String]
    }

    static func text(_ message: ReminderMessage) -> Text {
        let names = message.names.joined(separator: ", ")
        var lines = message.lines.map(line)
        if message.moreLines > 0 {
            lines.append("And \(message.moreLines) more")
        }
        return Text(
            title: message.count == 1 ? "1 item needs attention" : "\(message.count) items need attention",
            text: message.moreNames > 0 ? "\(names) and \(message.moreNames) more" : names,
            lines: lines
        )
    }

    private static func line(_ line: ReminderLine) -> String {
        let daysLeft: String
        switch line.daysLeft {
        case .expiredYesterday:
            daysLeft = "Expired yesterday"
        case .expiresToday:
            daysLeft = "Expires today"
        case .expiresTomorrow:
            daysLeft = "Expires tomorrow"
        case .expiresInDays(let days):
            daysLeft = days == 1 ? "Expires in 1 day" : "Expires in \(days) days"
        }
        let shown = line.estimated ? "\(daysLeft), estimated" : daysLeft
        return "\(shown): \(line.name)"
    }
}
