import CVKEFridgeFeatures
import SwiftUI

/// The group "Needs attention" of Home: the expired and the expiring batches, in a row of cards that scrolls
/// sideways. "View all" shows My Fridge with no filter.
///
/// In the place of the cards, the group shows the loading line, the empty state with the two ways to add food, or
/// "All fresh". "All fresh" is for food that is there: an inventory with no food says "No items yet".
struct AttentionSection: View {
    /// The content of the inventory, or nil while it is not loaded.
    let overview: InventoryContent?

    @Environment(Navigator.self) private var navigator

    /// What the group shows.
    private enum Phase: Equatable {
        case loading
        case noItems
        case allFresh
        case list
    }

    private var phase: Phase {
        guard let overview else {
            return .loading
        }
        if overview.foodCount == 0 {
            return .noItems
        }
        return overview.attention.isEmpty ? .allFresh : .list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            SectionHeader("Needs attention", actionTitle: "View all") {
                navigator.showMyFridge()
            }
            // The content comes in the place of the loading line with a fade.
            ZStack(alignment: .topLeading) {
                switch phase {
                case .loading:
                    LoadingView()
                        .accessibilityIdentifier("loading")
                case .noItems:
                    EmptyStateView("No items yet") {
                        AddFoodButtons()
                    }
                case .allFresh:
                    AllFreshCard()
                case .list:
                    cards(overview?.attention ?? [])
                }
            }
            .motion(Motion.enter, value: phase)
        }
    }

    /// The row of cards. It scrolls to the two sides of the screen, so it has no margin of its own.
    private func cards(_ batches: [AttentionBatch]) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: Space.s3) {
                ForEach(batches, id: \.id) { batch in
                    AttentionCard(batch: batch) {
                        navigator.open(.food(productId: batch.productId))
                    }
                }
            }
            // Each card is as high as the highest card.
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Space.screenMargin)
        }
        .scrollIndicators(.hidden)
        .fadingEdges()
        .padding(.horizontal, -Space.screenMargin)
        .motion(Motion.list, value: batches.map(\.id))
        .accessibilityIdentifier("attention_list")
    }
}

/// The two ways to add food, for an empty state: the scanner, and the form.
struct AddFoodButtons: View {
    @Environment(Navigator.self) private var navigator

    var body: some View {
        Button("Scan a barcode", systemImage: AppIcon.scan.symbol) {
            navigator.scan()
        }
        .buttonStyle(.secondary(.compact))
        .accessibilityIdentifier("empty_scan")
        Button("Add by hand", systemImage: AppIcon.addByHand.symbol) {
            navigator.addFood()
        }
        .buttonStyle(.secondary(.compact))
        .accessibilityIdentifier("empty_add")
    }
}

/// Good news: no batch is expired, and no batch expires soon.
private struct AllFreshCard: View {
    var body: some View {
        let days = Freshness.expiringWithinDays
        SurfaceCard(.positive) {
            HStack(spacing: Space.s4) {
                Image(icon: .done, filled: true)
                    .font(.title)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("All fresh")
                        .font(Typography.cardTitle)
                    Text(
                        verbatim: days == 1
                            ? String(localized: "Nothing has expired, and nothing expires in the next day.")
                            : String(localized: "Nothing has expired, and nothing expires in the next \(days) days.")
                    )
                    .font(Typography.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("all_fresh")
    }
}

/// One batch that needs attention: the photo of the product or the icon of its category, its name, its quantity,
/// its category, and the days left. The card has the error colours for an expired batch and the amber for an
/// expiring batch. The days left say the same in words, with the icon of the status. A tap opens the food.
/// VoiceOver reads the card as one button.
private struct AttentionCard: View {
    let batch: AttentionBatch
    let onOpen: () -> Void

    /// The width at the default text size. It grows with the text size, to 300 points at most.
    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 180

    var body: some View {
        let tone: CardTone = batch.freshness == .expired ? .expired : .expiring
        let quantity = Wording.quantity(batch.quantity, unit: batch.unit)
        let expiry = Wording.expiry(daysLeft: batch.daysLeft, expiry: batch.expiry)
        Button(action: onOpen) {
            SurfaceCard(tone) {
                VStack(alignment: .leading, spacing: Space.s1) {
                    ProductImage(productId: batch.productId, category: batch.category, tone: .on(tone))
                        .padding(.bottom, Space.s2)
                    Text(verbatim: batch.name)
                        .font(Typography.cardTitle)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    // "600 g • Meat"
                    Text(verbatim: "\(quantity) \(Wording.separator) \(batch.category.label)")
                        .font(Typography.secondary)
                    Spacer(minLength: Space.s2)
                    StatusLabel(verbatim: expiry, freshness: batch.freshness, showsIcon: true, tinted: false)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: min(width, 300))
        }
        .buttonStyle(.card)
        .accessibilityLabel(Text(verbatim: batch.name))
        .accessibilityValue(Text(verbatim: "\(expiry), \(quantity), \(batch.category.label)"))
        .accessibilityHint(Text("Opens the food."))
        .accessibilityIdentifier("attention_\(batch.id)")
    }
}
