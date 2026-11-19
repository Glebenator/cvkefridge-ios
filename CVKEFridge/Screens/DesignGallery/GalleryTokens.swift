#if DEBUG
import SwiftUI

/// Each colour token, as a swatch with its "on" colour.
struct GalleryColours: View {
    private struct Swatch: Identifiable {
        let name: String
        let fill: Color
        let on: Color
        var id: String { name }
    }

    private let scheme: [Swatch] = [
        Swatch(name: "primary", fill: Palette.primary, on: Palette.onPrimary),
        Swatch(name: "primaryContainer", fill: Palette.primaryContainer, on: Palette.onPrimaryContainer),
        Swatch(name: "secondary", fill: Palette.secondary, on: Palette.onSecondary),
        Swatch(name: "secondaryContainer", fill: Palette.secondaryContainer, on: Palette.onSecondaryContainer),
        Swatch(name: "tertiary", fill: Palette.tertiary, on: Palette.onTertiary),
        Swatch(name: "tertiaryContainer", fill: Palette.tertiaryContainer, on: Palette.onTertiaryContainer),
        Swatch(name: "error", fill: Palette.error, on: Palette.onError),
        Swatch(name: "errorContainer", fill: Palette.errorContainer, on: Palette.onErrorContainer),
    ]

    private let surfaces: [Swatch] = [
        Swatch(name: "surface", fill: Palette.surface, on: Palette.onSurface),
        Swatch(name: "surfaceContainerLowest", fill: Palette.surfaceContainerLowest, on: Palette.onSurface),
        Swatch(name: "surfaceContainerLow", fill: Palette.surfaceContainerLow, on: Palette.onSurface),
        Swatch(name: "surfaceContainer", fill: Palette.surfaceContainer, on: Palette.onSurface),
        Swatch(name: "surfaceContainerHigh", fill: Palette.surfaceContainerHigh, on: Palette.onSurface),
        Swatch(name: "surfaceContainerHighest", fill: Palette.surfaceContainerHighest, on: Palette.onSurface),
        Swatch(name: "surfaceVariant", fill: Palette.surfaceVariant, on: Palette.onSurfaceVariant),
        Swatch(name: "surfaceDim", fill: Palette.surfaceDim, on: Palette.onSurface),
        Swatch(name: "surfaceBright", fill: Palette.surfaceBright, on: Palette.onSurface),
        Swatch(name: "inverseSurface", fill: Palette.inverseSurface, on: Palette.inverseOnSurface),
        Swatch(name: "outline", fill: Palette.outline, on: Palette.surface),
        Swatch(name: "outlineVariant", fill: Palette.outlineVariant, on: Palette.onSurface),
    ]

    private let status: [Swatch] = [
        Swatch(name: "Status.fresh", fill: Palette.surface, on: Palette.Status.fresh),
        Swatch(name: "Status.expiring", fill: Palette.surface, on: Palette.Status.expiring),
        Swatch(name: "Status.expired", fill: Palette.surface, on: Palette.Status.expired),
        Swatch(name: "Status.expiringContainer", fill: Palette.Status.expiringContainer, on: Palette.Status.onExpiringContainer),
        Swatch(name: "Status.expiredContainer", fill: Palette.Status.expiredContainer, on: Palette.Status.onExpiredContainer),
    ]

    private let brand: [Swatch] = [
        Swatch(name: "Brand.houseBlue", fill: Palette.Brand.houseBlue, on: Palette.surface),
        Swatch(name: "Brand.apricot", fill: Palette.Brand.apricot, on: Palette.surface),
        Swatch(name: "Brand.houseInk", fill: Palette.Brand.houseInk, on: Palette.surface),
        Swatch(name: "Brand.gradientEnd", fill: Palette.Brand.gradientEnd, on: Palette.Brand.gradientInk),
        Swatch(name: "Brand.gradientStart", fill: Palette.Brand.gradientStart, on: Palette.Brand.gradientInk),
        Swatch(name: "Brand.gradientStop", fill: Palette.Brand.gradientStop, on: Palette.Brand.gradientInk),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s5) {
            GalleryItem("Palette: accent and error") { grid(scheme) }
            GalleryItem("Palette: surfaces and lines") { grid(surfaces) }
            GalleryItem("Palette.Status") { grid(status) }
            GalleryItem("Palette.Brand") { grid(brand) }
        }
    }

    private func grid(_ swatches: [Swatch]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Space.s2)], spacing: Space.s2) {
            ForEach(swatches) { swatch in
                Text(verbatim: swatch.name)
                    .font(Typography.caption.weight(.medium))
                    .foregroundStyle(swatch.on)
                    .padding(Space.s3)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .bottomLeading)
                    .background(swatch.fill, in: Radius.shape(Radius.small))
                    .overlay { Radius.shape(Radius.small).strokeBorder(Palette.outlineVariant, lineWidth: 1) }
            }
        }
    }
}

/// Each text style.
struct GalleryTypography: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            GalleryItem("heroNumber()") { Text(verbatim: "12").heroNumber() }
            GalleryItem("Typography.screenTitle") { Text(verbatim: "Your Kitchen").font(Typography.screenTitle) }
            GalleryItem("Typography.greeting") { Text(verbatim: "Good afternoon").font(Typography.greeting) }
            GalleryItem("Typography.sectionTitle") { Text(verbatim: "Needs attention").font(Typography.sectionTitle) }
            GalleryItem("Typography.metricValue") { Text(verbatim: "3").font(Typography.metricValue) }
            GalleryItem("Typography.cardTitle") { Text(verbatim: "Chicken thighs").font(Typography.cardTitle) }
            GalleryItem("Typography.body") { Text(verbatim: "The food could not be read from this phone.").font(Typography.body) }
            GalleryItem("Typography.secondary") { Text(verbatim: "600 g • Expires in 3d").font(Typography.secondary) }
            GalleryItem("Typography.label") { Text(verbatim: "Total items").font(Typography.label) }
            GalleryItem("Typography.caption") { Text(verbatim: "Estimate for Milk (Fridge): 7 days").font(Typography.caption) }
        }
        .foregroundStyle(Palette.onSurface)
    }
}

/// The spacing steps and the corner radii.
struct GalleryMetrics: View {
    private let steps: [(String, CGFloat)] = [
        ("s1", Space.s1), ("s2", Space.s2), ("s3", Space.s3), ("s4", Space.s4), ("s5", Space.s5),
        ("s6", Space.s6), ("s8", Space.s8), ("s10", Space.s10),
    ]

    private let radii: [(String, CGFloat)] = [
        ("small", Radius.small), ("medium", Radius.medium), ("large", Radius.large), ("extraLarge", Radius.extraLarge),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s5) {
            GalleryItem("Space") {
                VStack(alignment: .leading, spacing: Space.s1) {
                    ForEach(steps, id: \.0) { step in
                        HStack(spacing: Space.s3) {
                            Text(verbatim: "\(step.0)  \(Int(step.1))")
                                .font(Typography.caption.monospaced())
                                .frame(minWidth: 64, alignment: .leading)
                            Capsule()
                                .fill(Palette.primaryContainer)
                                .frame(width: step.1, height: 12)
                        }
                    }
                }
            }
            GalleryItem("Radius") {
                FlowLayout(spacing: Space.s3) {
                    ForEach(radii, id: \.0) { radius in
                        Text(verbatim: "\(radius.0)  \(Int(radius.1))")
                            .font(Typography.caption.monospaced())
                            .padding(Space.s3)
                            .frame(minWidth: 96, minHeight: 72, alignment: .bottomLeading)
                            .background(Palette.surfaceContainerHighest, in: Radius.shape(radius.1))
                    }
                }
            }
            GalleryItem("Metrics.contentMaxWidth 720, Metrics.minTarget 44") {
                Color.clear.frame(height: 0)
            }
        }
        .foregroundStyle(Palette.onSurface)
    }
}

/// The brand parts.
struct GalleryBrand: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s5) {
            GalleryItem("BrandGradient, brandGradient(in:)") {
                Color.clear
                    .frame(height: 120)
                    .brandGradient(in: Radius.shape(Radius.large))
            }
            GalleryItem("BrandTile") {
                HStack(spacing: Space.s4) {
                    BrandTile()
                    BrandTile(size: 72)
                    BrandTile(size: 40)
                }
            }
            GalleryItem("SliceComposition") { SliceComposition() }
            GalleryItem("BrandSpinner") {
                HStack(spacing: Space.s4) {
                    BrandSpinner()
                    BrandSpinner(size: 32)
                    BrandSpinner(size: 48)
                }
            }
        }
    }
}

/// Each icon, in its usual form and in its filled form.
struct GalleryIcons: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: Space.s2)], spacing: Space.s2) {
            ForEach(Array(AppIcon.allCases.enumerated()), id: \.offset) { _, icon in
                VStack(spacing: Space.s2) {
                    HStack(spacing: Space.s3) {
                        Image(icon: icon)
                        Image(icon: icon, filled: true)
                    }
                    .font(.title3)
                    .foregroundStyle(Palette.onSurface)
                    .frame(minHeight: 28)
                    Text(verbatim: String(describing: icon))
                        .font(.caption2.monospaced())
                        .foregroundStyle(Palette.onSurfaceVariant)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.vertical, Space.s3)
                .frame(maxWidth: .infinity)
                .background(Palette.surfaceContainerLow, in: Radius.shape(Radius.small))
            }
        }
    }
}
#endif
