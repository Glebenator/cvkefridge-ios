import SwiftUI

/// An empty state: the slice of the house brand above the title, an optional message, and the actions. It is for a
/// screen or a group with no food. It is not for a search or a filter with no result: use `ListMessage` for that.
///
/// ```swift
/// EmptyStateView("No food yet") {
///     Button("Scan a barcode", systemImage: AppIcon.scan.symbol) { … }.buttonStyle(.secondary(.compact))
///     Button("Add by hand", systemImage: AppIcon.addByHand.symbol) { … }.buttonStyle(.secondary(.compact))
/// }
/// ```
///
/// Use one empty state on a screen, because the slice moves. The actions go to the next line when they do not fit.
struct EmptyStateView<Actions: View>: View {
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey?
    private let actions: Actions

    init(_ title: LocalizedStringKey, message: LocalizedStringKey? = nil, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: Space.s4) {
            SliceComposition()
            VStack(spacing: Space.s1) {
                Text(title)
                    .font(Typography.cardTitle)
                    .foregroundStyle(Palette.onSurface)
                    .accessibilityAddTraits(.isHeader)
                if let message {
                    Text(message)
                        .font(Typography.secondary)
                        .foregroundStyle(Palette.onSurfaceVariant)
                }
            }
            .multilineTextAlignment(.center)
            FlowLayout(alignment: .center) { actions }
                // In a row of a list, a label of the system has a large icon in a column of its own. The buttons of
                // an empty state look the same in a list and out of a list.
                .labelStyle(InlineLabelStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.s8)
    }
}

/// A label with its icon and its title side by side, with the space of a button between them, in a list and out of
/// a list.
struct InlineLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Space.s2) {
            configuration.icon
            configuration.title
        }
    }
}

extension EmptyStateView where Actions == EmptyView {
    init(_ title: LocalizedStringKey, message: LocalizedStringKey? = nil) {
        self.init(title, message: message) { EmptyView() }
    }
}

/// The app is busy: the spinner and words, on a quiet card or with no card. Content that comes after it comes with
/// `Motion.enter`.
///
/// ```swift
/// LoadingView()                              // "Loading…" on a card, in the place of a list
/// LoadingView("Looking up the product…", style: .plain)
/// ```
///
/// VoiceOver reads the words. The spinner has no label of its own.
struct LoadingView: View {
    enum Style: Sendable {
        /// On a quiet card, in the place of the content of a group.
        case card
        /// With no card, in the centre of the available width.
        case plain
    }

    var text: LocalizedStringKey = "Loading…"
    var style: Style = .card

    init(_ text: LocalizedStringKey = "Loading…", style: Style = .card) {
        self.text = text
        self.style = style
    }

    var body: some View {
        switch style {
        case .card:
            SurfaceCard(.low) { row }
        case .plain:
            row
                .frame(maxWidth: .infinity)
                .padding(Space.s8)
        }
    }

    private var row: some View {
        HStack(spacing: Space.s3) {
            BrandSpinner(label: nil)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(Palette.onSurfaceVariant)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// A load failed: the problem sign, what failed and what to do, and the button that tries again. It is in the place
/// of the content.
///
/// ```swift
/// ErrorStateView("The food could not be read from this phone. Try again.") { reload() }
/// ```
struct ErrorStateView: View {
    private let message: LocalizedStringKey
    private let actionTitle: LocalizedStringKey
    private let action: () -> Void

    init(_ message: LocalizedStringKey, actionTitle: LocalizedStringKey = "Try again", action: @escaping () -> Void) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Space.s4) {
            VStack(spacing: Space.s3) {
                Image(icon: .alert, filled: true)
                    .font(.title)
                    .foregroundStyle(Palette.error)
                    .accessibilityHidden(true)
                Text(message)
                    .font(Typography.body)
                    .foregroundStyle(Palette.onSurface)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .accessibilityElement(children: .combine)
            Button(actionTitle, action: action)
                .buttonStyle(.primary(.compact))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.s8)
    }
}

/// One line in the place of a list, with an optional action below it: no food is there for the filters and the
/// search text.
///
/// ```swift
/// ListMessage("No food for these filters") {
///     Button("Clear the filters") { … }.buttonStyle(.quiet)
/// }
/// ```
struct ListMessage<Actions: View>: View {
    private let text: LocalizedStringKey
    private let actions: Actions

    init(_ text: LocalizedStringKey, @ViewBuilder actions: () -> Actions) {
        self.text = text
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: Space.s2) {
            Text(text)
                .font(Typography.body)
                .foregroundStyle(Palette.onSurfaceVariant)
                .multilineTextAlignment(.center)
            actions
        }
        .frame(maxWidth: .infinity)
        .padding(Space.s8)
    }
}

extension ListMessage where Actions == EmptyView {
    init(_ text: LocalizedStringKey) {
        self.init(text) { EmptyView() }
    }
}
