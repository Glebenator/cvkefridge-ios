import CVKEFridgeFeatures
import SwiftUI

// The words and the look that the parts of History share. The Android file `ui/HistoryScreen.kt` has the same values:
// `Outcome.icon()`, `outcomeColor`, `totalsText`, and the descriptions for screen readers.

/// The icons, the colours, and the words of the parts of History.
enum HistoryLook {
    /// The icon of an outcome: the check mark for "Used" and the bin for "Thrown away". It is the icon of the swipe and
    /// of the menu of a food card also.
    static func icon(_ outcome: Outcome) -> AppIcon {
        switch outcome {
        case .used: .check
        case .thrownAway: .delete
        }
    }

    /// The colour of the icon of an outcome. The words of the outcome are always next to the icon, so the colour is
    /// never the only sign.
    static func color(_ outcome: Outcome) -> Color {
        switch outcome {
        case .used: Palette.primary
        case .thrownAway: Palette.tertiary
        }
    }

    /// The words below the number of batches of the summary: "batch used", "batches thrown away".
    static func batchesLabel(_ outcome: Outcome, count: Int) -> String {
        switch outcome {
        case .used:
            count == 1
                ? String(localized: "batch used", comment: "Below the number of batches of the History summary.")
                : String(localized: "batches used", comment: "Below the number of batches of the History summary.")
        case .thrownAway:
            count == 1
                ? String(localized: "batch thrown away", comment: "Below the number of batches of the History summary.")
                : String(localized: "batches thrown away", comment: "Below the number of batches of the History summary.")
        }
    }

    /// One sum of the summary: "6 pcs", "1.5 l", or "2 with no unit".
    static func total(_ total: QuantityTotal) -> String {
        let text = Wording.quantity(total.quantity, unit: total.unit)
        guard total.unit == nil else {
            return text
        }
        return String(localized: "\(text) with no unit", comment: "A sum of the quantities of foods that have no unit.")
    }

    /// The sums in more than one unit, on one line: "6 pcs • 1 l • 1 bottle". A line breaks only between two sums, so
    /// that a number stays with its unit.
    static func totals(_ totals: [QuantityTotal]) -> String {
        totals
            .map { total($0).replacingOccurrences(of: " ", with: "\u{00A0}") }
            .joined(separator: " \(Wording.separator) ")
    }

    /// What VoiceOver reads for one entry: "Whole milk, 1 l, Used, Today".
    static func entryDescription(_ line: HistoryLine, day: DayName) -> String {
        let quantity = Wording.quantity(line.quantity, unit: line.unit)
        let outcome = line.outcome.label
        let dayText = Wording.day(day, date: line.date)
        return String(
            localized: "\(line.name), \(quantity), \(outcome), \(dayText)",
            comment: "For VoiceOver: one History entry. The values are the food, the quantity, Used or Thrown away, and the day."
        )
    }

    /// The name of the button of an entry that adds the food again: "Add Whole milk again".
    static func addAgainLabel(_ name: String) -> String {
        String(localized: "Add \(name) again", comment: "For VoiceOver: the button of a History entry. The value is the food.")
    }
}
