import CVKEFridgeFeatures
import SwiftUI

/// What the person can do with a food from its card.
enum FoodCardAction: Sendable {
    /// Records all of the oldest batch as used or as thrown away. It is the action of a swipe.
    case useOldest
    case throwAwayOldest
    /// Asks for a quantity, and records it as used or as thrown away.
    case use
    case throwAway
    /// Opens the add form for a new batch of the food.
    case addBatch
    /// Opens the form that edits the food.
    case edit
    /// Deletes the batches of the card, for a mistake.
    case delete
}

/// One food in one storage area, as a card: the photo of the product or the icon of its category, its name, its
/// quantity, the days left of the batch to use first in the colour of its freshness, and its category. A food with
/// batches of different expiry dates says how many. The note of the product is on one line. A tap opens the food.
/// It takes the place of `ui/FoodCard.kt` of the Android app.
///
/// The card is the content of a row of a `List`. The list gives the swipes: `foodCardSwipes(_:)`. The same actions
/// are in the menu of the card (the "More" button, and a touch and hold), and VoiceOver has them as actions of the
/// card. "Delete" is only in the menu, because it is for a mistake.
///
/// The days left always have words ("Expires tomorrow", "Expired yesterday"), and an expiring or an expired food
/// has the icon of its status also. Colour is not the only sign.
struct FoodCard: View {
    let row: FoodRow
    /// True on the tab of all storage areas. The card then names its storage area, because one food can have a
    /// card in each storage area.
    let showsArea: Bool
    let onOpen: () -> Void
    let onAction: (FoodCardAction) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // With an accessibility text size, the name has two lines and the category is below the other lines.
        let large = dynamicTypeSize.isAccessibilitySize
        HStack(spacing: 0) {
            Button(action: onOpen) {
                HStack(spacing: Space.s3) {
                    ProductImage(productId: row.productId, category: row.category)
                    VStack(alignment: .leading, spacing: 2) {
                        // The category is at the end of the line of the name, so the days left have all of the
                        // width.
                        HStack(alignment: .firstTextBaseline, spacing: Space.s2) {
                            Text(verbatim: row.name)
                                .font(Typography.cardTitle)
                                .foregroundStyle(Palette.onSurface)
                                .lineLimit(large ? 2 : 1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if !large {
                                category
                            }
                        }
                        status
                        if row.expiryDateCount > 1 {
                            Text(verbatim: Wording.expiryDateCount(row.expiryDateCount))
                        }
                        if let note {
                            Text(verbatim: note)
                                .italic()
                                .lineLimit(1)
                        }
                        if large {
                            category
                        }
                        if showsArea {
                            Text(verbatim: row.areaDisplayName)
                                .font(Typography.caption)
                        }
                    }
                    .font(Typography.secondary)
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, Space.s4)
                .padding(.vertical, Space.s3)
                .frame(minHeight: 64)
                .contentShape(.rect)
            }
            .buttonStyle(.card)
            .accessibilityLabel(Text(verbatim: row.name))
            .accessibilityValue(Text(verbatim: spoken))
            .accessibilityHint(Text("Opens the food."))
            .accessibilityAction(named: Text("Used")) { onAction(.use) }
            .accessibilityAction(named: Text("Thrown away")) { onAction(.throwAway) }
            .accessibilityAction(named: Text("Add a batch")) { onAction(.addBatch) }
            .accessibilityAction(named: Text("Edit")) { onAction(.edit) }
            .accessibilityAction(named: Text("Delete")) { onAction(.delete) }
            .accessibilityIdentifier("food_\(row.key)")

            Menu {
                FoodCardMenu(onAction: onAction)
            } label: {
                Image(icon: .more)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .frame(minWidth: Metrics.minTarget, minHeight: Metrics.minTarget)
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, Space.s1)
                    .contentShape(.rect)
            }
            .accessibilityLabel(Text("More actions for \(row.name)"))
            .accessibilityIdentifier("food_menu_\(row.key)")
        }
        .surface(Palette.surfaceContainerLow)
        .contextMenu {
            FoodCardMenu(onAction: onAction)
        }
    }

    /// "600 g • Expires in 3d": the quantity, and the days left in the colour of the freshness. An expiring or an
    /// expired food has the icon of its status before the days left.
    private var status: Text {
        var line = AttributedString("\(Wording.quantity(row.quantity, unit: row.unit)) \(Wording.separator) ")
        var days = AttributedString(Wording.expiry(daysLeft: row.daysLeft, expiry: row.expiry))
        days.foregroundColor = row.freshness.color
        switch row.freshness {
        case .expiring, .expired:
            let icon = Text(Image(icon: row.freshness.icon, filled: true)).foregroundStyle(row.freshness.color)
            return Text("\(Text(line))\(icon) \(Text(days))", comment: "The quantity of a food, the icon of its status, and its days left.")
        case .fresh, .noExpiryDate:
            line.append(days)
            return Text(line)
        }
    }

    /// The category of the food.
    private var category: some View {
        Text(verbatim: row.category.label)
            .font(Typography.caption.weight(.medium))
            .foregroundStyle(Palette.onSurfaceVariant)
            .lineLimit(1)
    }

    /// The note of the product on one line, or nil. The screen of the food shows all of it.
    private var note: String? {
        row.note.map { note in
            note.split(whereSeparator: \.isNewline).joined(separator: " ")
        }
    }

    /// What VoiceOver reads after the name: the days left first, because they are why the person looks at the list.
    private var spoken: String {
        var parts = [
            Wording.expiry(daysLeft: row.daysLeft, expiry: row.expiry),
            Wording.quantity(row.quantity, unit: row.unit),
        ]
        if row.expiryDateCount > 1 {
            parts.append(Wording.expiryDateCount(row.expiryDateCount))
        }
        parts.append(row.category.label)
        if showsArea {
            parts.append(row.areaDisplayName)
        }
        if let note {
            parts.append(note)
        }
        return parts.joined(separator: ", ")
    }
}

/// The items of the menu of a card: "Used…" and "Thrown away…" ask for a quantity (with one item left, they record
/// it with no question), then the two forms, and "Delete" below a line.
private struct FoodCardMenu: View {
    let onAction: (FoodCardAction) -> Void

    var body: some View {
        Section {
            Button {
                onAction(.use)
            } label: {
                Label("Used…", icon: .check)
            }
            .accessibilityIdentifier("menu_used")
            Button {
                onAction(.throwAway)
            } label: {
                Label("Thrown away…", icon: .delete)
            }
            .accessibilityIdentifier("menu_thrown_away")
        }
        Section {
            Button {
                onAction(.addBatch)
            } label: {
                Label("Add a batch", icon: .add)
            }
            .accessibilityIdentifier("menu_add_batch")
            Button {
                onAction(.edit)
            } label: {
                Label("Edit", icon: .edit)
            }
            .accessibilityIdentifier("menu_edit")
        }
        Section {
            Button(role: .destructive) {
                onAction(.delete)
            } label: {
                Label("Delete", icon: .delete)
            }
            .accessibilityIdentifier("menu_delete")
        }
    }
}

extension View {
    /// The swipes of a food card in a list: a swipe from the leading side records the oldest batch as used, and a
    /// swipe from the trailing side records it as thrown away. A full swipe does the action. The two sides have
    /// different colours, icons, and words, and the person can undo each one with the message.
    ///
    /// The colours are dark tones of the green and of the apricot of the scheme, the same in light and in dark, so
    /// that the white icon of the system has enough contrast on them.
    func foodCardSwipes(_ onAction: @escaping (FoodCardAction) -> Void) -> some View {
        swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Haptic.commit.play()
                onAction(.useOldest)
            } label: {
                Label("Used", icon: .check)
            }
            .tint(Palette.onPrimaryContainer)
            .accessibilityIdentifier("swipe_used")
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                Haptic.commit.play()
                onAction(.throwAwayOldest)
            } label: {
                Label("Thrown away", icon: .delete)
            }
            .tint(Palette.onTertiaryContainer)
            .accessibilityIdentifier("swipe_thrown_away")
        }
    }
}
