import CVKEFridgeFeatures
import SwiftUI

/// The history of one food, below its batches: the heading, for each outcome the quantity and the number of batches
/// ("Used: 3 l from 2 batches"), and the entries, the newest first. It shows the first entries, and "Show all" shows
/// the others in place. It takes the place of `FoodHistoryHeader` and `FoodHistoryLine` of
/// `ui/FoodDetailScreen.kt` of the Android app.
struct FoodHistorySection: View {
    /// The entries of the food, the newest first.
    let lines: [HistoryLine]
    let today: CalendarDate
    @Binding var showsAll: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The number of entries that the history of a food shows before the person selects "Show all".
    static let firstCount = 5

    var body: some View {
        let used = HistoryContent.total(lines, outcome: .used)
        let thrownAway = HistoryContent.total(lines, outcome: .thrownAway)
        let shown = showsAll ? lines : Array(lines.prefix(Self.firstCount))
        VStack(alignment: .leading, spacing: Space.s1) {
            VStack(alignment: .leading, spacing: 2) {
                Text("History")
                    .font(Typography.cardTitle)
                    .foregroundStyle(Palette.onSurface)
                    .accessibilityAddTraits(.isHeader)
                if used.batchCount > 0 {
                    total(used, .used)
                }
                if thrownAway.batchCount > 0 {
                    total(thrownAway, .thrownAway)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("food_history")
            // A long history makes its rows when they come on the screen.
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(shown, id: \.changeId) { line in
                    FoodHistoryRow(line: line, today: today)
                        .transition(.opacity)
                }
            }
            if shown.count < lines.count {
                Button {
                    withMotion(Motion.list, reduceMotion: reduceMotion) { showsAll = true }
                } label: {
                    Text(verbatim: FoodWords.showAll(lines.count))
                }
                .buttonStyle(.quiet)
                .accessibilityIdentifier("food_history_all")
            }
        }
    }

    private func total(_ total: OutcomeTotal, _ outcome: Outcome) -> some View {
        let text = FoodWords.total(total, outcome: outcome)
        return Text(verbatim: text)
            .font(Typography.secondary)
            .foregroundStyle(Palette.onSurfaceVariant)
            .contentTransition(.numericText())
            .accessibilityLabel(Text(verbatim: FoodWords.spoken(text)))
    }
}

/// One entry of the history of the food: the outcome in words with its icon, the quantity, and the day. VoiceOver
/// reads it as one element.
private struct FoodHistoryRow: View {
    let line: HistoryLine
    let today: CalendarDate

    /// The width of the column of the icons. It grows with the text size.
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 28

    var body: some View {
        HStack(spacing: Space.s3) {
            // The words of the outcome are next to the icon, so colour is not the only sign.
            Image(icon: line.outcome == .used ? .check : .delete)
                .font(.body.weight(.medium))
                .foregroundStyle(line.outcome == .used ? Palette.primary : Palette.tertiary)
                .frame(width: iconWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: FoodWords.entry(line))
                    .font(Typography.body)
                    .foregroundStyle(Palette.onSurface)
                    .accessibilityLabel(Text(verbatim: FoodWords.spoken(FoodWords.entry(line))))
                Text(verbatim: FoodWords.day(line.date, today: today))
                    .font(Typography.secondary)
                    .foregroundStyle(Palette.onSurfaceVariant)
            }
        }
        .padding(.leading, Space.s1)
        .padding(.vertical, Space.s1)
        .frame(maxWidth: .infinity, minHeight: Metrics.minTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("food_history_\(line.changeId)")
    }
}
