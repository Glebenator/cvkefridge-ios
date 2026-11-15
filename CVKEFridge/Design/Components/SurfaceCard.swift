import SwiftUI

/// The fill of a card and the colour of the content on it.
struct CardTone: Equatable, Sendable {
    let fill: Color
    let content: Color

    /// A card in a list: a food card, a batch card, a loading line.
    static let low = CardTone(fill: Palette.surfaceContainerLow, content: Palette.onSurface)
    /// A large card: the totals of Home, the summary of History.
    static let standard = CardTone(fill: Palette.surfaceContainer, content: Palette.onSurface)
    /// A part on a card that the person can tap: a count tile.
    static let highest = CardTone(fill: Palette.surfaceContainerHighest, content: Palette.onSurface)
    /// Good news: "All fresh".
    static let positive = CardTone(fill: Palette.secondaryContainer, content: Palette.onSecondaryContainer)
    /// A batch that expires soon.
    static let expiring = CardTone(fill: Palette.Status.expiringContainer, content: Palette.Status.onExpiringContainer)
    /// A batch that is expired, and a problem.
    static let expired = CardTone(fill: Palette.Status.expiredContainer, content: Palette.Status.onExpiredContainer)
}

/// The soft rounded card of Home, My Fridge, and History: an opaque surface in a tone of the scheme, with no shadow
/// and no line. A card is content. It is not Liquid Glass: glass is only for controls that float above the content.
///
/// ```swift
/// SurfaceCard(.standard, radius: Radius.extraLarge) { … }      // The totals of Home
/// SurfaceCard { … }                                            // A food card
/// Button { open() } label: { SurfaceCard(.expired) { … } }     // A card that the person can tap
///     .buttonStyle(.card)
/// ```
///
/// With Increase Contrast on, the card has a line around it.
struct SurfaceCard<Content: View>: View {
    private let tone: CardTone
    private let radius: CGFloat
    private let padding: CGFloat
    private let content: Content

    init(
        _ tone: CardTone = .low,
        radius: CGFloat = Radius.large,
        padding: CGFloat = Space.s4,
        @ViewBuilder content: () -> Content
    ) {
        self.tone = tone
        self.radius = radius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(tone.content)
            .surface(tone.fill, radius: radius)
    }
}

extension View {
    /// Puts an opaque rounded surface of the `fill` colour behind the view, and makes the rounded shape the shape
    /// for touches and for the pointer. With Increase Contrast on, the surface has a line around it.
    func surface(_ fill: Color, radius: CGFloat = Radius.large) -> some View {
        modifier(SurfaceModifier(fill: fill, radius: radius))
    }
}

private struct SurfaceModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    let fill: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        let shape = Radius.shape(radius)
        content
            .background(fill, in: shape)
            .overlay {
                if contrast == .increased {
                    shape.strokeBorder(Palette.outline, lineWidth: 1)
                }
            }
            .contentShape(.rect(cornerRadius: radius, style: .continuous))
            .contentShape(.hoverEffect, .rect(cornerRadius: radius, style: .continuous))
    }
}

/// The style of a button whose label is a card or a tile. The label goes down a little below the finger and becomes
/// darker. With Reduce Motion on, it only becomes darker.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CardButtonBody(configuration: configuration)
    }
}

private struct CardButtonBody: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    let configuration: ButtonStyleConfiguration

    var body: some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .hoverEffect(.highlight, isEnabled: isEnabled)
    }
}

extension ButtonStyle where Self == CardButtonStyle {
    /// See `CardButtonStyle`.
    static var card: CardButtonStyle { CardButtonStyle() }
}
