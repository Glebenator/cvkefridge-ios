import CVKEFridgeFeatures
import SwiftUI

/// "Used" and "Thrown away" for the whole food, as two buttons with different looks, one at each side of the screen.
/// A person then does not select the wrong one (`docs/research/competitor-apps.md` in the cvkefridge repository,
/// section 8.2, item 10). With large text, or when the two do not fit side by side, one is above the other.
struct FoodTakeButtons: View {
    let onTake: (Outcome) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            column
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.s4) {
                    used(fullWidth: false)
                    Spacer(minLength: 0)
                    thrownAway(fullWidth: false)
                }
                column
            }
        }
    }

    private var column: some View {
        VStack(spacing: Space.s2) {
            used(fullWidth: true)
            thrownAway(fullWidth: true)
        }
    }

    private func used(fullWidth: Bool) -> some View {
        Button {
            onTake(.used)
        } label: {
            Label("Used", icon: .check)
        }
        .buttonStyle(.secondary(.large, fullWidth: fullWidth))
        .accessibilityIdentifier("food_used")
    }

    private func thrownAway(fullWidth: Bool) -> some View {
        Button {
            onTake(.thrownAway)
        } label: {
            Label("Thrown away", icon: .delete)
        }
        .buttonStyle(.outline(.large, fullWidth: fullWidth))
        .accessibilityIdentifier("food_thrown_away")
    }
}

/// What a person can do with one batch on the screen of a food.
struct BatchActions {
    /// Records a quantity of the batch as used or as thrown away. The app asks for the quantity.
    let take: (Outcome) -> Void
    /// Opens the form that edits the batch.
    let edit: () -> Void
    /// Deletes the batch, for a batch that was a mistake.
    let delete: () -> Void
    /// Gives the batch a later expiry date, because the food is still good.
    let moveExpiry: (CalendarDate) -> Void
    /// Opens the calendar for a later expiry date. The value is the first date that the person can select.
    let pickExpiry: (CalendarDate) -> Void
}

/// One batch on the screen of a food: its quantity, its days left with the icon and the colour of its freshness, its
/// expiry date with the source, its storage area, and its date added. It takes the place of `BatchCard` of
/// `ui/FoodDetailScreen.kt` of the Android app.
///
/// The actions of the batch are in the menu at the end of the card, in the context menu of the card, and in the
/// actions of VoiceOver: "Used…", "Thrown away…", "Edit batch", and "Delete batch".
///
/// A batch that is expiring or expired also has "Still good?" (see `StillGoodRow`).
struct BatchCard: View {
    let batch: BatchLine
    let unit: MeasureUnit?
    /// The name of the storage area of the batch, in the language of the person.
    let areaName: String
    /// True for the batch that a use takes from first, when the food has more than one batch.
    let usesFirst: Bool
    let today: CalendarDate
    let actions: BatchActions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                lines
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Space.s3)
                menu
                    .padding(.top, Space.s1)
            }
            if let expiry = batch.expiry, batch.freshness == .expiring || batch.freshness == .expired {
                StillGoodRow(batchId: batch.id, expiry: expiry.date, today: today, actions: actions)
                    .padding(.trailing, Space.s4)
                    .padding(.bottom, Space.s3)
                    .transition(.opacity)
            }
        }
        .padding(.leading, Space.s4)
        .padding(.trailing, Space.s1)
        .surface(CardTone.low.fill)
        .contentShape(.contextMenuPreview, Radius.shape(Radius.large))
        .contextMenu { menuItems }
    }

    /// The text of the card. VoiceOver reads it as one element, with the actions of the batch.
    private var lines: some View {
        VStack(alignment: .leading, spacing: 2) {
            if usesFirst {
                Text("Use first")
                    .font(Typography.label)
                    .foregroundStyle(Palette.primary)
                    .transition(.opacity)
            }
            Text(verbatim: Wording.quantity(batch.quantity, unit: unit))
                .font(Typography.cardTitle)
                .foregroundStyle(Palette.onSurface)
                .contentTransition(.numericText())
            // Colour is not the only sign of the freshness: the words name it, and the icon shows it.
            HStack(alignment: .firstTextBaseline, spacing: Space.s1 + 2) {
                Image(icon: batch.freshness.icon, filled: true)
                    .accessibilityHidden(true)
                Text(verbatim: Wording.expiry(daysLeft: batch.daysLeft, expiry: batch.expiry))
            }
            .font(Typography.body)
            .foregroundStyle(batch.freshness.color)
            if let expiry = batch.expiry {
                Text(verbatim: Wording.dateWithSource(expiry))
                    .font(Typography.secondary)
                    .foregroundStyle(Palette.onSurfaceVariant)
            }
            Text(verbatim: FoodWords.place(area: areaName, added: batch.dateAdded))
                .font(Typography.secondary)
                .foregroundStyle(Palette.onSurfaceVariant)
                .accessibilityLabel(
                    Text(verbatim: FoodWords.spoken(FoodWords.place(area: areaName, added: batch.dateAdded)))
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text("Used…")) { actions.take(.used) }
        .accessibilityAction(named: Text("Thrown away…")) { actions.take(.thrownAway) }
        .accessibilityAction(named: Text("Edit batch")) { actions.edit() }
        .accessibilityAction(named: Text("Delete batch")) { actions.delete() }
        .accessibilityIdentifier("batch_\(batch.id)")
    }

    private var menu: some View {
        Menu {
            menuItems
        } label: {
            Image(icon: .more)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.onSurfaceVariant)
                .frame(minWidth: Metrics.minTarget, minHeight: Metrics.minTarget)
                .contentShape(.rect)
        }
        .accessibilityLabel(Text("More actions for this batch"))
        .accessibilityIdentifier("batch_menu_\(batch.id)")
    }

    /// The actions of the batch, for the menu and for the context menu. A line divides "Delete batch" from the
    /// other actions, because a delete is for a mistake.
    @ViewBuilder private var menuItems: some View {
        Button {
            actions.take(.used)
        } label: {
            Label("Used…", icon: .check)
        }
        .accessibilityIdentifier("menu_used")
        Button {
            actions.take(.thrownAway)
        } label: {
            Label("Thrown away…", icon: .delete)
        }
        .accessibilityIdentifier("menu_thrown_away")
        Button {
            actions.edit()
        } label: {
            Label("Edit batch", icon: .edit)
        }
        .accessibilityIdentifier("menu_edit_batch")
        Divider()
        Button(role: .destructive) {
            actions.delete()
        } label: {
            Label("Delete batch", icon: .delete)
        }
        .accessibilityIdentifier("menu_delete_batch")
    }
}

/// "Still good?" with the quick choices for a later expiry date, and "Other date", which opens the calendar. A date
/// on a package or an estimate is not always right, and food can be good after it. The new date comes from
/// `LaterExpiry`: an expired batch starts from today.
///
/// The calendar of "Other date" starts on the day after the expiry date, or after today when the batch is expired,
/// and it has no earlier date. In the Android app, the person can select a date that is not later.
private struct StillGoodRow: View {
    let batchId: String
    let expiry: CalendarDate
    let today: CalendarDate
    let actions: BatchActions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Still good?")
                .font(Typography.label)
                .foregroundStyle(Palette.onSurfaceVariant)
            FlowLayout(spacing: Space.s2, lineSpacing: 0) {
                ForEach(LaterExpiry.quickDays, id: \.self) { days in
                    if let date = LaterExpiry.date(expiry: expiry, today: today, days: days) {
                        Button {
                            actions.moveExpiry(date)
                        } label: {
                            days == 7 ? Text("+1 week") : Text("+1 day")
                        }
                        .accessibilityLabel(
                            days == 7 ? Text("Still good: expires 1 week later") : Text("Still good: expires 1 day later")
                        )
                        .accessibilityIdentifier("later_expiry_\(days)")
                    }
                }
                if let first = LaterExpiry.date(expiry: expiry, today: today, days: 1) {
                    Button {
                        actions.pickExpiry(first)
                    } label: {
                        Label {
                            Text("Other date")
                        } icon: {
                            Image(icon: .calendar)
                                .foregroundStyle(Palette.primary)
                        }
                    }
                    .accessibilityLabel(Text("Still good: select a new expiry date"))
                    .accessibilityIdentifier("later_expiry_other")
                }
            }
            .buttonStyle(.outline(.compact))
        }
        .accessibilityElement(children: .contain)
    }
}
