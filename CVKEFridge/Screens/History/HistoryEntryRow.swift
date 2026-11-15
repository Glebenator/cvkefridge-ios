import CVKEFridgeFeatures
import SwiftUI

/// One entry of History: the photo of the product or the icon of its category, the name of the food, the quantity, the
/// outcome in words with its icon, and the button that adds the food again.
///
/// - A tap opens the screen of the food.
/// - The plus button, a swipe to the right, and the context menu add the food again.
/// - VoiceOver reads the entry as one item with its day ("Whole milk, 1 l, Used, Today"), and has "Add again" as an
///   action of the item.
///
/// The row calculates only its words. The list gives it a line that the model calculated off the main actor.
struct HistoryEntryRow: View {
    let line: HistoryLine
    /// The name of the day of the entry, for VoiceOver.
    let day: DayName

    @Environment(Navigator.self) private var navigator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: Space.s1) {
            Button(action: open) {
                HStack(spacing: Space.s4) {
                    ProductImage(productId: line.productId, category: line.category)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: line.name)
                            .font(Typography.body)
                            .foregroundStyle(Palette.onSurface)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        outcome
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, Space.s2)
                .frame(minHeight: 56)
                .contentShape(.rect)
            }
            .buttonStyle(.card)

            Button(action: addAgain) {
                Image(icon: .add)
                    .font(.title3)
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .frame(minWidth: Metrics.minTarget, minHeight: Metrics.minTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(verbatim: HistoryLook.addAgainLabel(line.name)))
            .accessibilityShowsLargeContentViewer {
                Image(icon: .add)
                Text("Add again")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: HistoryLook.entryDescription(line, day: day)))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { open() }
        .accessibilityAction(named: Text("Add again")) { addAgain() }
        .accessibilityInputLabels([Text(verbatim: line.name)])
        .accessibilityIdentifier("history_\(line.changeId)")
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button("Add again", systemImage: AppIcon.add.symbol, action: addAgain)
                .tint(Palette.primary)
        }
        .contextMenu {
            Button("Add again", systemImage: AppIcon.add.symbol, action: addAgain)
        }
    }

    /// The icon of the outcome, the quantity, and the outcome in words: "✓ 1 bottle • Used".
    private var outcome: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(icon: HistoryLook.icon(line.outcome))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(HistoryLook.color(line.outcome))
            Text(verbatim: "\(Wording.quantity(line.quantity, unit: line.unit)) \(Wording.separator) \(line.outcome.label)")
                .font(Typography.secondary)
                .foregroundStyle(Palette.onSurfaceVariant)
        }
    }

    private func open() {
        navigator.open(.food(productId: line.productId))
    }

    private func addAgain() {
        navigator.present(.addFood(productId: line.productId, again: true))
    }
}

/// The header of a day of History: "Today", "Yesterday", or the date with the day of the week. VoiceOver can go from
/// one day to the next with the headings rotor.
struct HistoryDayHeader: View {
    let date: CalendarDate
    let name: DayName

    var body: some View {
        Text(verbatim: Wording.day(name, date: date))
            .font(Typography.label.weight(.semibold))
            .foregroundStyle(Palette.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Space.s4)
            .padding(.bottom, Space.s1)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("history_day_\(date.text)")
    }
}
