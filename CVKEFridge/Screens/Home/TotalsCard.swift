import CVKEFridgeFeatures
import SwiftUI

/// The card of the totals on Home: the number of foods, the icon of the product on the signature gradient, and the
/// numbers of expiring and expired batches. Each of the two numbers of batches is a button that shows My Fridge
/// with that freshness.
///
/// Before the inventory is loaded, give nil. The numbers then show the sign for "no value", and the two buttons are
/// off.
struct TotalsCard: View {
    /// The content of the inventory, or nil while it is not loaded.
    let overview: InventoryContent?
    /// Shows My Fridge with the food of one freshness.
    let onShow: (Freshness) -> Void

    var body: some View {
        SurfaceCard(.standard, radius: Radius.extraLarge) {
            VStack(alignment: .leading, spacing: Space.s4) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Total items")
                            .font(Typography.label)
                            .foregroundStyle(Palette.onSurfaceVariant)
                            // VoiceOver reads these words with the number.
                            .accessibilityHidden(true)
                        Text(verbatim: text(overview?.foodCount))
                            .heroNumber()
                            .contentTransition(.numericText())
                            .accessibilityValue(Text("Total items"))
                            .accessibilityIdentifier("hero_total")
                    }
                    Spacer(minLength: Space.s3)
                    // The icon of the product. It is the one place on Home with the signature gradient.
                    BrandTile()
                }
                .padding(.horizontal, Space.s2)
                .padding(.top, Space.s2)
                Hairline()
                    .padding(.horizontal, Space.s2)
                // The two numbers are side by side. With large text, the second is below the first.
                AdaptiveStack {
                    StatTile("Expiring", value: text(overview?.expiringCount), kind: .expiring) {
                        onShow(.expiring)
                    }
                    .accessibilityIdentifier("metric_expiring")
                    StatTile("Expired", value: text(overview?.expiredCount), kind: .expired) {
                        onShow(.expired)
                    }
                    .accessibilityIdentifier("metric_expired")
                }
                .accessibilityHint(Text("Show in My Fridge"))
                .disabled(overview == nil)
            }
        }
        .motion(Motion.enter, value: [overview?.foodCount, overview?.expiringCount, overview?.expiredCount])
    }

    /// The number in the format of the locale, or the sign for "no value".
    private func text(_ count: Int?) -> String {
        count.map { Wording.number($0) } ?? Wording.noValue
    }
}
