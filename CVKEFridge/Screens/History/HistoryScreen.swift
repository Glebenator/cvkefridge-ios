import CVKEFridgeFeatures
import SwiftUI

/// History, the third tab. PLACEHOLDER: this file shows the entries in a plain list. The History agent replaces the
/// body. The signature `HistoryScreen()` stays.
///
/// Contract:
/// - The screen is the first screen of the navigation stack of the History tab. It sets its navigation title, and it
///   does not make a `NavigationStack`.
/// - `content.history` has all values, calculated off the main actor: `items(_:)` gives the rows for a
///   `HistoryFilter` (day headers and entries), and `summary(_:)` gives the summary of a `HistoryPeriod`.
/// - Words: `Wording.day(_:date:)` for a day header, `Outcome.label`, `HistoryFilter.label`, `HistoryPeriod.label`,
///   and `Wording.quantity(_:unit:)`.
/// - A tap on an entry calls `navigator.open(.food(productId:))`.
/// - "Add again" calls `navigator.present(.addFood(productId: line.productId, again: true))`.
struct HistoryScreen: View {
    @Environment(Navigator.self) private var navigator

    var body: some View {
        List {
            InventoryGate { content in
                let items = content.history.items(.all)
                if items.isEmpty {
                    Text("Nothing used or thrown away yet")
                }
                ForEach(items, id: \.key) { item in
                    switch item {
                    case .day(let date, let name):
                        Text(verbatim: Wording.day(name, date: date))
                            .font(Typography.label)
                            .foregroundStyle(Palette.primary)
                            .accessibilityAddTraits(.isHeader)
                    case .entry(let line, _):
                        Button {
                            navigator.open(.food(productId: line.productId))
                        } label: {
                            HStack(spacing: Space.s3) {
                                ProductImage(productId: line.productId, category: line.category)
                                VStack(alignment: .leading) {
                                    Text(verbatim: line.name)
                                        .foregroundStyle(Palette.onSurface)
                                    Text(verbatim: "\(Wording.quantity(line.quantity, unit: line.unit)) \(Wording.separator) \(line.outcome.label)")
                                        .font(Typography.secondary)
                                        .foregroundStyle(Palette.onSurfaceVariant)
                                }
                            }
                        }
                        .accessibilityIdentifier("history_\(line.changeId)")
                    }
                }
            }
        }
        .navigationTitle("History")
        .accessibilityIdentifier("history_screen")
    }
}
