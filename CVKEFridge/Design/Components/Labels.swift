import CVKEFridgeCore
import SwiftUI

/// Says that the food on the screen is the sample of the debug build.
struct SampleBanner: View {
    var text: LocalizedStringKey = "Sample data"

    var body: some View {
        Text(text)
            .font(Typography.label)
            .foregroundStyle(Palette.onSurfaceVariant)
            .padding(.horizontal, Space.s3)
            .padding(.vertical, Space.s2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surface(Palette.surfaceContainerHighest, radius: Radius.small)
            .accessibilityIdentifier("sample_note")
    }
}

/// The title of a group, with an optional button at the end ("View all").
///
/// ```swift
/// SectionHeader("Needs attention", actionTitle: "View all") { openMyFridge() }
/// SectionHeader("2 batches")
/// SectionHeader(verbatim: day, style: .group)        // A day of History
/// ```
///
/// The title is a heading for VoiceOver. With large text, the button goes below the title.
struct SectionHeader: View {
    enum Style: Sendable {
        /// The title of a group of a screen.
        case section
        /// The small title of a group in a list, in the accent colour.
        case group
    }

    private let title: Text
    private let style: Style
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?

    init(
        _ title: LocalizedStringKey,
        style: Style = .section,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = Text(title)
        self.style = style
        self.actionTitle = actionTitle
        self.action = action
    }

    /// A header whose title is text of the person, or text that is already localized (a date).
    init(
        verbatim title: String,
        style: Style = .section,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = Text(verbatim: title)
        self.style = style
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        AdaptiveStack(verticalAlignment: .firstTextBaseline, spacing: Space.s1) {
            title
                .font(style == .section ? Typography.sectionTitle : Typography.label.weight(.semibold))
                .foregroundStyle(style == .section ? Palette.onSurface : Palette.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.quiet)
            }
        }
    }
}

extension Freshness {
    /// The colour of text and icons for this freshness, on a surface.
    var color: Color {
        switch self {
        case .fresh: Palette.Status.fresh
        case .expiring: Palette.Status.expiring
        case .expired: Palette.Status.expired
        case .noExpiryDate: Palette.onSurfaceVariant
        }
    }

    /// The icon for this freshness: a check mark, a clock, a problem sign, or a calendar for no expiry date.
    var icon: AppIcon {
        switch self {
        case .fresh: .done
        case .expiring: .clock
        case .expired: .alert
        case .noExpiryDate: .calendar
        }
    }
}

/// Words about the freshness of a batch, in the colour of the freshness. Colour is never the only sign of a status:
/// the words name the status ("Expires tomorrow", "Expired yesterday"), and the label can show the icon also.
///
/// ```swift
/// StatusLabel(verbatim: expiryText, freshness: row.freshness)                  // "Expires in 3d" in green
/// StatusLabel(verbatim: expiryText, freshness: .expired, showsIcon: true)      // With the icon of the status
/// ```
///
/// To put the words in a longer line, use `Text(…).foregroundStyle(freshness.color)` in a text with other parts.
/// On a card that has a colour (`CardTone.expiring`, `.expired`), give `tinted: false`: the text then has the colour
/// of the content of the card.
struct StatusLabel: View {
    private let text: Text
    private let freshness: Freshness
    private let showsIcon: Bool
    private let tinted: Bool

    init(_ text: LocalizedStringKey, freshness: Freshness, showsIcon: Bool = false, tinted: Bool = true) {
        self.init(text: Text(text), freshness: freshness, showsIcon: showsIcon, tinted: tinted)
    }

    init(verbatim text: String, freshness: Freshness, showsIcon: Bool = false, tinted: Bool = true) {
        self.init(text: Text(verbatim: text), freshness: freshness, showsIcon: showsIcon, tinted: tinted)
    }

    private init(text: Text, freshness: Freshness, showsIcon: Bool, tinted: Bool) {
        self.text = text
        self.freshness = freshness
        self.showsIcon = showsIcon
        self.tinted = tinted
    }

    var body: some View {
        if tinted {
            label.foregroundStyle(freshness.color)
        } else {
            label
        }
    }

    @ViewBuilder private var label: some View {
        Group {
            if showsIcon {
                HStack(alignment: .firstTextBaseline, spacing: Space.s1 + 2) {
                    Image(icon: freshness.icon, filled: true)
                        .accessibilityHidden(true)
                    text
                }
            } else {
                text
            }
        }
        .font(Typography.label)
    }
}

/// A thin line that divides the parts of a card, in the colour `Palette.outlineVariant`.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Palette.outlineVariant)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}
