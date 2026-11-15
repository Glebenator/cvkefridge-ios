import SwiftUI

/// The button styles of the app. Each is a system style with the colours of the scheme, so each has the system
/// behaviour for the press, the pointer, the keyboard, and the text size.
///
/// | Style | System style | Android | Use |
/// | --- | --- | --- | --- |
/// | `.primary` | Bordered prominent | Button | The one main action of a screen or a card: "Add again", "Turn on", "Try again" |
/// | `.secondary` | Bordered | FilledTonalButton, OutlinedButton | Each other action with a border: "Scan a barcode", "Add a batch", "Undo" |
/// | `.quiet` | Borderless | TextButton | An action in a line of text or a header: "View all", "Not now" |
/// | `.floatingPrimary` | Glass prominent | | The main action of a bar that floats above the content: "Save" |
/// | `.floatingSecondary` | Glass | | Each other action of a floating bar: "Save and add another" |
///
/// ```swift
/// Button("Add again", systemImage: AppIcon.add.symbol) { … }.buttonStyle(.primary)
/// Button("Try again") { … }.buttonStyle(.primary(.compact))
/// Button("Save") { … }.buttonStyle(.primary(fullWidth: true))
/// Button("Delete", role: .destructive) { … }.buttonStyle(.secondary)
/// ```
///
/// A button with the role `.destructive` has the error colour. Each button is 44 points high or more.
/// Use a glass style only in the layer of controls above the content (see `BottomActionBar`), not on a card.
struct AppButtonStyle: PrimitiveButtonStyle {
    enum Kind: Sendable {
        case primary
        case secondary
        case quiet
        case floatingPrimary
        case floatingSecondary
    }

    enum Size: Sendable {
        /// 50 points high. For the action of a screen.
        case large
        /// 44 points high. For an action on a card or in a message.
        case compact
    }

    let kind: Kind
    var size: Size = .large
    /// True for a button that takes all of the width that it gets.
    var fullWidth = false
    /// True for a round button with only an icon.
    var circle = false

    func makeBody(configuration: Configuration) -> some View {
        AppButtonBody(style: self, configuration: configuration)
    }
}

extension PrimitiveButtonStyle where Self == AppButtonStyle {
    static var primary: AppButtonStyle { AppButtonStyle(kind: .primary) }
    static var secondary: AppButtonStyle { AppButtonStyle(kind: .secondary) }
    static var quiet: AppButtonStyle { AppButtonStyle(kind: .quiet) }
    static var floatingPrimary: AppButtonStyle { AppButtonStyle(kind: .floatingPrimary) }
    static var floatingSecondary: AppButtonStyle { AppButtonStyle(kind: .floatingSecondary) }

    static func primary(_ size: AppButtonStyle.Size = .large, fullWidth: Bool = false) -> AppButtonStyle {
        AppButtonStyle(kind: .primary, size: size, fullWidth: fullWidth)
    }

    static func secondary(_ size: AppButtonStyle.Size = .large, fullWidth: Bool = false) -> AppButtonStyle {
        AppButtonStyle(kind: .secondary, size: size, fullWidth: fullWidth)
    }
}

private struct AppButtonBody: View {
    let style: AppButtonStyle
    let configuration: PrimitiveButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled

    private var destructive: Bool { configuration.role == .destructive }
    private var accent: Color { destructive ? Palette.error : Palette.primary }
    private var onAccent: Color { destructive ? Palette.onError : Palette.onPrimary }

    var body: some View {
        switch style.kind {
        case .primary:
            button(label: onAccent)
                .buttonStyle(.borderedProminent)
                .modifier(Chrome(style: style, tint: accent))
        case .secondary:
            button(label: accent)
                .buttonStyle(.bordered)
                .modifier(Chrome(style: style, tint: accent))
        case .quiet:
            Button(role: configuration.role, action: configuration.trigger) {
                configuration.label
                    .font(Typography.label.weight(.semibold))
                    .foregroundStyle(isEnabled ? accent : Self.disabled)
                    .frame(minHeight: Metrics.minTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .tint(accent)
        case .floatingPrimary:
            button(label: onAccent)
                .buttonStyle(.glassProminent)
                .modifier(Chrome(style: style, tint: accent))
        case .floatingSecondary:
            button(label: destructive ? accent : Palette.onSurface)
                .buttonStyle(.glass)
                .modifier(Chrome(style: style, tint: nil))
        }
    }

    /// The colour of the label of a button that is off: 38% of the usual text colour, as in the Android app.
    private static let disabled = Palette.onSurface.opacity(0.38)

    /// The button with its label in the `label` colour.
    ///
    /// The style gives the colour, not the system. On a prominent button the system gives white, which has too little
    /// contrast on the green of the dark appearance. On each other button the system gives the colour of the text
    /// around the button, which is not the accent on a card.
    private func button(label: Color) -> some View {
        Button(role: configuration.role, action: configuration.trigger) {
            configuration.label
                .font(style.size == .compact ? Typography.label.weight(.semibold) : .body.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(isEnabled ? label : Self.disabled)
                .padding(.vertical, style.size == .compact ? 6 : 0)
        }
    }

    /// The shape, the size, and the tint that the bordered styles and the glass styles share.
    private struct Chrome: ViewModifier {
        let style: AppButtonStyle
        let tint: Color?

        func body(content: Content) -> some View {
            let shaped = content
                .buttonBorderShape(style.circle ? .circle : .capsule)
                .controlSize(style.size == .large ? .large : .regular)
                .tint(tint)
            // With no value here, the button keeps the sizing of the place that it is in.
            if style.fullWidth {
                shaped.buttonSizing(.flexible)
            } else {
                shaped
            }
        }
    }
}
