import SwiftUI
import UIKit

// The colour tokens, the spacing, the corner radii, and the text styles of the app.
//
// The colours are the values of `LightScheme`, `DarkScheme`, `LightStatus`, `DarkStatus`, `LightBrand`, and
// `DarkBrand` in `ui/theme/Tokens.kt` and `ui/theme/Brand.kt` of the Android app. They are a Material 3 colour scheme
// from the green of FridgeFriend, #53D181. iOS has no wallpaper colours, so this scheme is the only one.
// Do not change one value by hand. Change the values in the cvkefridge repository first, and copy them to the two
// apps.

/// The colour tokens, as dynamic colours for the light and the dark appearance.
///
/// The names are the names of the Material roles, because the two apps share the values. A colour and its "on" colour
/// are a pair with a contrast of 4.5:1 or more: put `onPrimary` on `primary`, `onSurface` on each `surface…`, and so
/// on. `primary` is the tint of the app.
///
/// With Increase Contrast on, the muted text has the colour of the usual text, and the outlines are one step stronger.
enum Palette {
    // MARK: Accent

    /// The accent: the tint of controls, links, and selected parts.
    static let primary = dynamic(light: 0x006D38, dark: 0x71EE9B)
    static let onPrimary = dynamic(light: 0xFFFFFF, dark: 0x00391A)
    /// The seed green #53D181. It is the same in light and in dark.
    static let primaryContainer = dynamic(light: 0x53D181, dark: 0x53D181)
    static let onPrimaryContainer = dynamic(light: 0x00562B, dark: 0x00562B)

    /// The quiet green of tiles, selected chips, and tonal buttons.
    static let secondary = dynamic(light: 0x3C6848, dark: 0xA2D2AB)
    static let onSecondary = dynamic(light: 0xFFFFFF, dark: 0x09381D)
    static let secondaryContainer = dynamic(light: 0xBAECC3, dark: 0x265234)
    static let onSecondaryContainer = dynamic(
        light: 0x406C4C, dark: 0x94C49D, highContrastLight: 0x00562B, highContrastDark: 0xBAECC3
    )

    /// The apricot. It is the colour of "Thrown away".
    static let tertiary = dynamic(light: 0x924B2B, dark: 0xFFCAB5)
    static let onTertiary = dynamic(light: 0xFFFFFF, dark: 0x571E03)
    static let tertiaryContainer = dynamic(light: 0xFFA37D, dark: 0xFFA37D)
    static let onTertiaryContainer = dynamic(light: 0x783719, dark: 0x783719)

    // MARK: Error

    /// A problem, and the status "expired".
    static let error = dynamic(light: 0xBA1A1A, dark: 0xFFB4AB)
    static let onError = dynamic(light: 0xFFFFFF, dark: 0x690005)
    static let errorContainer = dynamic(light: 0xFFDAD6, dark: 0x93000A)
    static let onErrorContainer = dynamic(light: 0x93000A, dark: 0xFFDAD6)

    // MARK: Surfaces

    /// The background of each screen.
    static let surface = dynamic(light: 0xF4FBF2, dark: 0x0E150F)
    /// The same value as `surface`. Material has the two names.
    static let background = surface
    /// The usual text and icons.
    static let onSurface = dynamic(light: 0x171D17, dark: 0xDDE4DB)
    static let surfaceVariant = dynamic(light: 0xD8E6D7, dark: 0x3D4A3F)
    /// The muted text and icons.
    static let onSurfaceVariant = dynamic(
        light: 0x3D4A3F, dark: 0xBCCABC, highContrastLight: 0x171D17, highContrastDark: 0xDDE4DB
    )
    static let surfaceDim = dynamic(light: 0xD5DCD3, dark: 0x0E150F)
    static let surfaceBright = dynamic(light: 0xF4FBF2, dark: 0x343B34)
    static let surfaceContainerLowest = dynamic(light: 0xFFFFFF, dark: 0x09100A)
    /// The fill of a card in a list (a food card).
    static let surfaceContainerLow = dynamic(light: 0xEFF6EC, dark: 0x171D17)
    /// The fill of a large card (the totals of Home, the summary of History).
    static let surfaceContainer = dynamic(light: 0xE9F0E6, dark: 0x1B211B)
    static let surfaceContainerHigh = dynamic(light: 0xE3EAE1, dark: 0x252C26)
    /// The fill of a part on a card (a count tile), and of the sample banner.
    static let surfaceContainerHighest = dynamic(light: 0xDDE4DB, dark: 0x303630)

    /// The line of a control that the person can change (a chip that is off, a text field).
    static let outline = dynamic(
        light: 0x6D7A6E, dark: 0x879487, highContrastLight: 0x3D4A3F, highContrastDark: 0xBCCABC
    )
    /// A line that divides content.
    static let outlineVariant = dynamic(
        light: 0xBCCABC, dark: 0x3D4A3F, highContrastLight: 0x6D7A6E, highContrastDark: 0x879487
    )

    static let inverseSurface = dynamic(light: 0x2B322C, dark: 0xDDE4DB)
    static let inverseOnSurface = dynamic(light: 0xECF3E9, dark: 0x2B322C)
    static let inversePrimary = dynamic(light: 0x61DE8C, dark: 0x006D38)
    static let scrim = Color(rgb: 0x000000)

    /// The colours of the freshness of a batch. Fresh stays green and expiring stays amber.
    ///
    /// The green of "fresh" is near the green of the accent, so a status always has an icon or a word with its colour
    /// (see `StatusLabel`). Colour is never the only sign.
    enum Status {
        /// Fresh: text and icons on a surface.
        static let fresh = Palette.dynamic(light: 0x006D34, dark: 0x3EE27B)
        /// Expiring: text and icons on a surface.
        static let expiring = Palette.dynamic(light: 0x835500, dark: 0xFFB955)
        /// Expiring: the fill of a card or a tile.
        static let expiringContainer = Palette.dynamic(light: 0xFFDDB5, dark: 0x633F00)
        /// Text and icons on `expiringContainer`.
        static let onExpiringContainer = Palette.dynamic(light: 0x2A1800, dark: 0xFFDDB5)
        /// Expired: text and icons on a surface. It is the error colour.
        static let expired = Palette.error
        /// Expired: the fill of a card or a tile.
        static let expiredContainer = Palette.errorContainer
        /// Text and icons on `expiredContainer`.
        static let onExpiredContainer = Palette.onErrorContainer
    }

    /// The colours of the brand parts: the slice of the house brand and the signature gradient.
    enum Brand {
        static let houseBlue = Palette.dynamic(light: 0x0A5CFF, dark: 0x6F9BFF)
        static let apricot = Palette.dynamic(light: 0xD9661F, dark: 0xF5A578)
        static let houseInk = Palette.dynamic(light: 0x161A1F, dark: 0xE9EDF1)
        /// The end colour of the spinner. It is `gradient-end` in `design/product.css` of the cvkefridge repository.
        static let gradientEnd = Palette.dynamic(light: 0xC6904B, dark: 0xDBA75E)
        /// The first stop of the signature gradient. It is the same in light and in dark.
        static let gradientStart = Color(rgb: 0x53D181)
        /// The second stop of the signature gradient. It is the same in light and in dark.
        static let gradientStop = Color(rgb: 0xDBA75E)
        /// The colour of a shape on the signature gradient. It is the same in light and in dark.
        static let gradientInk = Color(rgb: 0x161A1F)
    }

    /// A colour from 0xRRGGBB values for the light and the dark appearance. The high-contrast values are for Increase
    /// Contrast. With no high-contrast value, the usual value stays.
    static func dynamic(
        light: UInt32,
        dark: UInt32,
        highContrastLight: UInt32? = nil,
        highContrastDark: UInt32? = nil
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let highContrast = traits.accessibilityContrast == .high
            if traits.userInterfaceStyle == .dark {
                return UIColor(rgb: highContrast ? highContrastDark ?? dark : dark)
            }
            return UIColor(rgb: highContrast ? highContrastLight ?? light : light)
        })
    }
}

extension UIColor {
    /// A colour from 0xRRGGBB.
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    /// A colour from 0xRRGGBB.
    init(rgb: UInt32) {
        self.init(uiColor: UIColor(rgb: rgb))
    }
}

/// The 4-point spacing steps.
enum Space {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32
    static let s10: CGFloat = 40

    /// The space between the content and the two sides of the screen.
    static let screenMargin = s4
    /// The space between two cards of a list.
    static let cardGap = s2
    /// The space between two groups of a screen.
    static let sectionGap = s6
}

/// The corner radii. Each shape has continuous corners (`RoundedRectangle(cornerRadius:style: .continuous)`).
enum Radius {
    /// A small banner.
    static let small: CGFloat = 10
    /// A part on a card: a count tile, a photo.
    static let medium: CGFloat = 16
    /// A card.
    static let large: CGFloat = 20
    /// A large card (the totals of Home), and a floating message.
    static let extraLarge: CGFloat = 28

    /// The radius of a tile with an icon: 30% of its side.
    static func tile(_ side: CGFloat) -> CGFloat {
        side * 0.3
    }

    /// A rectangle with continuous corners of this radius.
    static func shape(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

/// Fixed sizes.
enum Metrics {
    /// The maximum width of the content of a screen, so that lines stay short on a wide screen.
    static let contentMaxWidth: CGFloat = 720
    /// The minimum side of a touch target.
    static let minTarget: CGFloat = 44
    /// The maximum width of a floating message.
    static let noticeMaxWidth: CGFloat = 480
    /// The width of a card in a row that scrolls sideways, at the default text size. On an iPhone, the second card
    /// is then cut at the edge of the screen, which shows that the row scrolls. The longest days left ("Expired
    /// yesterday, estimated") have two lines in it.
    static let rowCardWidth: CGFloat = 200
    /// The maximum width of such a card with large text.
    static let rowCardMaxWidth: CGFloat = 300
}

extension View {
    /// Keeps the content not wider than `Metrics.contentMaxWidth`, in the centre of the available width.
    func contentWidth() -> some View {
        frame(maxWidth: Metrics.contentMaxWidth).frame(maxWidth: .infinity)
    }
}

/// The text styles. Each is a Dynamic Type text style, so each follows the text size of the person.
///
/// | Style | Android | Use |
/// | --- | --- | --- |
/// | `screenTitle` | headlineLarge, bold | The title of Home ("Your Kitchen") |
/// | `greeting` | titleMedium | The line above the title of Home ("Good afternoon") |
/// | `sectionTitle` | titleLarge | The title of a group ("Needs attention"), the name on the Food screen |
/// | `metricValue` | headlineSmall, bold | A count on a tile ("3" of Expiring) |
/// | `cardTitle` | titleMedium | The name of a food on a card, the title of a card |
/// | `body` | bodyLarge | Text |
/// | `secondary` | bodyMedium | The second line of a card |
/// | `label` | labelLarge | Chips, small headings, the words below a count |
/// | `caption` | labelMedium | Small notes |
///
/// The large number of the totals is `heroNumber()`, a modifier.
enum Typography {
    static let screenTitle = Font.largeTitle.weight(.bold)
    static let greeting = Font.body.weight(.medium)
    static let sectionTitle = Font.title2.weight(.semibold)
    static let metricValue = Font.title2.weight(.bold)
    static let cardTitle = Font.headline
    static let body = Font.body
    static let secondary = Font.subheadline
    static let label = Font.subheadline.weight(.medium)
    static let caption = Font.footnote
}

extension View {
    /// The style of the large number of the totals ("12" of Total items). It is larger than each system text style,
    /// so its size is 52 points at the default text size and it grows with the large title style. The number stays
    /// on one line and becomes smaller when the width is too small.
    func heroNumber() -> some View {
        modifier(HeroNumber())
    }
}

private struct HeroNumber: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 52

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.4)
    }
}
