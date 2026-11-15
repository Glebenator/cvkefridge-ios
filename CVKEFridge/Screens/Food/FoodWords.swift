import CVKEFridgeFeatures
import Foundation

/// The words that only the screen of a food has. The English words are the words of `res/values/strings.xml` of the
/// Android app. A text with a count has two keys, as the texts of `Wording` have.
enum FoodWords {
    /// The category and the sum of the batches: "Dairy • 3 l". A food with no batch has only its category.
    static func summary(of detail: FoodDetail) -> String {
        let category = detail.product.category.label
        guard !detail.batches.isEmpty else {
            return category
        }
        return "\(category) \(Wording.separator) \(Wording.quantity(detail.total, unit: detail.product.unit))"
    }

    /// The storage area and the date added of a batch: "Fridge • Added Nov 7, 2026".
    static func place(area: String, added: CalendarDate) -> String {
        "\(area) \(Wording.separator) \(Wording.dateAdded(added))"
    }

    /// What one outcome came to in the history of a food: "Used: 3 l from 2 batches".
    static func total(_ total: OutcomeTotal, outcome: Outcome) -> String {
        let amount = sums(total.quantities)
        let count = total.batchCount
        switch outcome {
        case .used:
            return count == 1
                ? String(localized: "Used: \(amount) from \(count) batch")
                : String(localized: "Used: \(amount) from \(count) batches")
        case .thrownAway:
            return count == 1
                ? String(localized: "Thrown away: \(amount) from \(count) batch")
                : String(localized: "Thrown away: \(amount) from \(count) batches")
        }
    }

    /// Sums in more than one unit: "3.5 l • 12 pcs • 2 with no unit". A line breaks only between two sums, so that a
    /// number stays with its unit.
    static func sums(_ totals: [QuantityTotal]) -> String {
        totals
            .map { total -> String in
                let text = total.unit == nil
                    ? String(localized: "\(Wording.quantity(total.quantity, unit: nil)) with no unit",
                             comment: "A sum of quantities of food that has no unit. The value is a number.")
                    : Wording.quantity(total.quantity, unit: total.unit)
                return text.replacing(" ", with: "\u{00A0}")
            }
            .joined(separator: " \(Wording.separator) ")
    }

    /// One entry of the history of a food: "Used • 1 l".
    static func entry(_ line: HistoryLine) -> String {
        "\(line.outcome.label) \(Wording.separator) \(Wording.quantity(line.quantity, unit: line.unit))"
    }

    /// The day of an entry: "Today", "Yesterday", or the date in the medium format.
    static func day(_ date: CalendarDate, today: CalendarDate) -> String {
        let name = HistoryContent.dayName(date, today: today)
        return name == .date ? Wording.date(date) : Wording.day(name, date: date)
    }

    /// A text for VoiceOver: the same words with a comma in the place of each separator sign. VoiceOver reads the
    /// sign as a word.
    static func spoken(_ text: String) -> String {
        text.replacing(" \(Wording.separator) ", with: ", ")
    }

    /// The button that shows all entries of the history of a food. `count` is the number of entries.
    static func showAll(_ count: Int) -> String {
        count == 1 ? String(localized: "Show \(count) entry") : String(localized: "Show all \(count) entries")
    }
}
