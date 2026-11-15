import CVKEFridgeFeatures
import SwiftUI

/// The summary at the top of History: the number of batches that were used and that were thrown away in a period,
/// each with its quantities, and the foods that were thrown away most often. The menu at the top changes the period.
/// It has counts and quantities only.
///
/// The two numbers are side by side when they fit. With large text, the second number is below the first.
struct HistorySummaryCard: View {
    let summary: HistorySummary
    @Binding var period: HistoryPeriod

    var body: some View {
        SurfaceCard(.standard, radius: Radius.extraLarge, padding: Space.s5) {
            VStack(alignment: .leading, spacing: Space.s3) {
                header
                if summary.isEmpty {
                    Text("Nothing was used or thrown away in this time.")
                        .font(Typography.body)
                        .foregroundStyle(Palette.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("summary_none")
                } else {
                    AdaptiveStack(verticalAlignment: .top, spacing: Space.s4) {
                        OutcomeNumber(outcome: .used, total: summary.used)
                            .accessibilityIdentifier("summary_used")
                        OutcomeNumber(outcome: .thrownAway, total: summary.thrownAway)
                            .accessibilityIdentifier("summary_thrown_away")
                    }
                    if !summary.mostThrownAway.isEmpty {
                        mostThrownAway
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history_summary")
    }

    /// The title and the menu of the period.
    private var header: some View {
        AdaptiveStack(verticalAlignment: .center, spacing: 0) {
            Text("Used and thrown away")
                .font(Typography.cardTitle)
                .foregroundStyle(Palette.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Picker("Period", selection: $period) {
                ForEach(HistoryPeriod.allCases, id: \.self) { option in
                    Text(verbatim: option.label).tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(Palette.primary)
            .frame(minHeight: Metrics.minTarget)
            // The menu button has its own inset. This puts its text on the line of the card content.
            .padding(.horizontal, -Space.s3)
            .haptic(.selection, trigger: period)
            .accessibilityIdentifier("history_period")
        }
    }

    /// The line, the heading, and the three foods with the most batches that were thrown away.
    private var mostThrownAway: some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Hairline()
                .padding(.top, Space.s1)
                .padding(.bottom, Space.s2)
            Text("Thrown away most often")
                .font(Typography.label)
                .foregroundStyle(Palette.onSurfaceVariant)
                .accessibilityAddTraits(.isHeader)
            ForEach(summary.mostThrownAway, id: \.productId) { product in
                MostThrownAwayRow(product: product)
            }
        }
    }
}

/// One number of the summary: the icon of the outcome, the number of batches, its words, and the quantities.
private struct OutcomeNumber: View {
    let outcome: Outcome
    let total: OutcomeTotal

    /// The number is larger than a count of a tile: headlineMedium of Android.
    private static let numberFont = Font.title.weight(.bold)

    var body: some View {
        let count = Wording.number(total.batchCount)
        let label = HistoryLook.batchesLabel(outcome, count: total.batchCount)
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s2) {
                Image(icon: HistoryLook.icon(outcome))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HistoryLook.color(outcome))
                Text(verbatim: count)
                    .font(Self.numberFont)
                    .foregroundStyle(Palette.onSurface)
                    .contentTransition(.numericText(value: Double(total.batchCount)))
            }
            Text(verbatim: label)
                .font(Typography.secondary)
                .foregroundStyle(Palette.onSurfaceVariant)
            if !total.quantities.isEmpty {
                Text(verbatim: HistoryLook.totals(total.quantities))
                    .font(Typography.secondary)
                    .foregroundStyle(Palette.onSurface)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        // VoiceOver reads one item, with a pause between the sums: "3 batches used, 6 pcs, 1 l, 1 bottle".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: ([count + " " + label] + total.quantities.map(HistoryLook.total)).joined(separator: ", ")))
    }
}

/// A food that was thrown away often: its picture, its name, and the number of its batches. A tap opens the food.
private struct MostThrownAwayRow: View {
    let product: ThrownAwayProduct

    @Environment(Navigator.self) private var navigator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let count = Wording.batchCount(product.batchCount)
        Button {
            navigator.open(.food(productId: product.productId))
        } label: {
            HStack(spacing: Space.s3) {
                ProductImage(productId: product.productId, category: product.category, size: 32)
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 2) {
                        name
                        countText(count)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    name
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    countText(count)
                }
            }
            .frame(minHeight: Metrics.minTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.card)
        .accessibilityLabel(Text(verbatim: "\(product.name), \(count)"))
        .accessibilityInputLabels([Text(verbatim: product.name)])
        .accessibilityIdentifier("most_thrown_away_\(product.productId)")
    }

    private var name: some View {
        Text(verbatim: product.name)
            .font(Typography.body)
            .foregroundStyle(Palette.onSurface)
            .multilineTextAlignment(.leading)
    }

    private func countText(_ count: String) -> some View {
        Text(verbatim: count)
            .font(Typography.secondary)
            .foregroundStyle(Palette.onSurfaceVariant)
    }
}
