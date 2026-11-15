import SwiftUI

/// The fill of a tile and the colour of the icon on it.
struct TileTone: Equatable, Sendable {
    let fill: Color
    let content: Color

    /// The usual tile: the icon of a category on a food card.
    static let standard = TileTone(fill: Palette.secondaryContainer, content: Palette.onSecondaryContainer)
    /// A tile that asks for attention to a new thing: the bell of the reminder offer.
    static let accent = TileTone(fill: Palette.primaryContainer, content: Palette.onPrimaryContainer)
    /// A quiet tile on a card.
    static let neutral = TileTone(fill: Palette.surfaceContainerHighest, content: Palette.onSurfaceVariant)
    static let expiring = TileTone(fill: Palette.Status.expiringContainer, content: Palette.Status.onExpiringContainer)
    static let expired = TileTone(fill: Palette.Status.expiredContainer, content: Palette.Status.onExpiredContainer)

    /// A tile on a card that has a colour: the `content` colour of the card, with 10% of it as the fill.
    static func on(_ card: CardTone) -> TileTone {
        TileTone(fill: card.content.opacity(0.1), content: card.content)
    }
}

/// A rounded square with an icon, or with the photo of a product. It is decorative: the name of the thing is next to
/// it, so VoiceOver does not read it.
///
/// ```swift
/// IconTile(.clock, tone: .expiring, filled: false)          // A count tile
/// IconTile(category.icon, photo: photo)                     // A food card: the photo, or the icon of the category
/// IconTile(category.icon, tone: .on(.expired), size: 40)    // On a card of a batch that is expired
/// IconTile(category.icon, photo: photo, size: 72)           // The top of the Food screen
/// ```
///
/// The side grows with the text size, to 1.4 times at most.
struct IconTile: View {
    private let icon: AppIcon
    private let tone: TileTone
    private let photo: Image?
    private let size: CGFloat
    private let filled: Bool

    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    /// - Parameters:
    ///   - photo: The photo of the product. With nil, the tile shows the icon.
    ///   - size: The side at the default text size.
    ///   - filled: False for the outline form of the icon.
    init(_ icon: AppIcon, tone: TileTone = .standard, photo: Image? = nil, size: CGFloat = 40, filled: Bool = true) {
        self.icon = icon
        self.tone = tone
        self.photo = photo
        self.size = size
        self.filled = filled
    }

    var body: some View {
        let side = size * min(scale, 1.4)
        let shape = Radius.shape(Radius.tile(side))
        Group {
            if let photo {
                photo
                    .resizable()
                    .scaledToFill()
                    .frame(width: side, height: side)
                    .clipShape(shape)
            } else {
                Image(icon: icon, filled: filled)
                    .resizable()
                    .scaledToFit()
                    .frame(width: side * 0.5, height: side * 0.5)
                    .foregroundStyle(tone.content)
                    .frame(width: side, height: side)
                    .background(tone.fill, in: shape)
            }
        }
        .accessibilityHidden(true)
    }
}
