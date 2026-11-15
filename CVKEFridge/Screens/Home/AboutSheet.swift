import CVKEFridgeFeatures
import SwiftUI

/// About: the icon and the name of the product, its version, the maker, and where the data of the app comes from.
/// It takes the place of `AboutSheet` in `ui/HomeScreen.kt` of the Android app. The maker is "Made by" with the cvke
/// letters, as the design system of the owner says. The sheet has the signature gradient on the icon of the product.
///
/// The two sources are the facts of `design/product.md` in the cvkefridge repository: the product lookup is Open
/// Food Facts, and the expiry estimates are from the USDA FoodKeeper data. The Android app does not name them on
/// About.
struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    BrandTile(size: 72)
                    Text(verbatim: "CVKE Fridge")
                        .font(Typography.sectionTitle)
                        .foregroundStyle(Palette.onSurface)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, Space.s4)
                    Text("Version \(AppVersion.current.label)")
                        .font(Typography.secondary)
                        .foregroundStyle(Palette.onSurfaceVariant)
                        .accessibilityIdentifier("about_app_version")
                    maker
                        .padding(.top, Space.s8)
                    sources
                        .padding(.top, Space.s8)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Space.s6)
                .padding(.bottom, Space.s8)
                .contentWidth()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                        .accessibilityIdentifier("about_close")
                }
            }
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .tint(Palette.primary)
        .accessibilityIdentifier("about")
    }

    /// "Made by" with the cvke letters. VoiceOver reads the two as one line.
    private var maker: some View {
        HStack(spacing: Space.s2) {
            Text("Made by")
                .font(Typography.label)
                .foregroundStyle(Palette.onSurfaceVariant)
            MakerMark()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("about_maker")
    }

    /// Where the product data and the expiry estimates come from.
    private var sources: some View {
        VStack(spacing: Space.s2) {
            Text("The product of a barcode comes from Open Food Facts.")
            Text("The expiry estimates and the storage advice come from the USDA FoodKeeper data.")
        }
        .font(Typography.caption)
        .foregroundStyle(Palette.onSurfaceVariant)
        .frame(maxWidth: 420)
        .accessibilityIdentifier("about_sources")
    }
}

/// The cvke letters, the mark of the maker: `assets/cvke-letters-light.svg` and `cvke-letters-dark.svg` of My Design
/// Language, with the same shapes and the same colours as `res/drawable/cvke_letters.xml` of the Android app. Do not
/// change the shapes or the colours.
///
/// The width grows with the text size. VoiceOver reads "cvke".
struct MakerMark: View {
    /// The width at the default text size. The height is 112/300 of the width.
    @ScaledMetric(relativeTo: .subheadline) private var width: CGFloat = 72

    var body: some View {
        ZStack {
            MakerLetters(part: .ink).fill(Palette.Brand.houseInk)
            MakerLetters(part: .apricot).fill(Palette.Brand.apricot)
        }
        .frame(width: width, height: width * MakerLetters.viewport.height / MakerLetters.viewport.width)
        // The letters read from left to right in each language.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "cvke"))
        .accessibilityAddTraits(.isImage)
    }
}

/// The shapes of the cvke letters of one colour, in a viewport of 300 x 112.
private struct MakerLetters: Shape {
    enum Part {
        case ink
        case apricot
    }

    static let viewport = CGSize(width: 300, height: 112)

    let part: Part

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch part {
        case .ink:
            // c: a disc with a cut that opens to the right.
            path.move(to: CGPoint(x: 32, y: 32))
            path.addArc(center: CGPoint(x: 32, y: 32), radius: 32, startAngle: .degrees(35.08), endAngle: .degrees(324.92), clockwise: false)
            path.closeSubpath()
            // v: a triangle that points down.
            path.move(to: CGPoint(x: 76, y: 0))
            path.addLine(to: CGPoint(x: 140, y: 0))
            path.addLine(to: CGPoint(x: 108, y: 62))
            path.closeSubpath()
            // k: the bar.
            path.addRoundedRect(in: CGRect(x: 152, y: -32, width: 16, height: 96), cornerSize: CGSize(width: 8, height: 8))
            // e: the top half of a disc.
            path.move(to: CGPoint(x: 218, y: 28))
            path.addArc(center: CGPoint(x: 250, y: 28), radius: 32, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            path.closeSubpath()
        case .apricot:
            // c: the slice.
            path.move(to: CGPoint(x: 41, y: 32))
            path.addArc(center: CGPoint(x: 41, y: 32), radius: 32, startAngle: .degrees(-35.08), endAngle: .degrees(35.08), clockwise: false)
            path.closeSubpath()
            // k: the triangle that points to the bar.
            path.move(to: CGPoint(x: 174, y: 32))
            path.addLine(to: CGPoint(x: 206, y: 0))
            path.addLine(to: CGPoint(x: 206, y: 64))
            path.closeSubpath()
            // e: the quarter of a disc below the bar.
            path.move(to: CGPoint(x: 250, y: 36))
            path.addLine(to: CGPoint(x: 218, y: 36))
            path.addArc(center: CGPoint(x: 250, y: 36), radius: 32, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
            path.closeSubpath()
        }
        // The shapes of the source file start at the point (6, 38) of the viewport.
        let scale = rect.width / Self.viewport.width
        return path.applying(
            CGAffineTransform(translationX: rect.minX, y: rect.minY)
                .scaledBy(x: scale, y: scale)
                .translatedBy(x: 6, y: 38)
        )
    }
}
