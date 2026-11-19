import SwiftUI

// The brand parts of My Design Language, the design system of the owner: the signature gradient, the slice of the
// house brand (cvke), and the spinner. It is the port of `ui/theme/Brand.kt` of the Android app. The colours are
// `Palette.Brand`, and the motion values are `Motion`. The interface itself stays the system design of iOS.

/// The signature gradient with its grain. It fills the space that it gets.
///
/// The gradient goes around the point at 55% of the width and 55% of the height, from the green of the product to
/// the green blended to apricot, and back. The grain is a fine noise that makes the colour bands soft. The colours do
/// not change with the appearance. A shape on the gradient has the colour `Palette.Brand.gradientInk`.
///
/// Use it one time on a screen, with no text on it. For a shape, use `brandGradient(in:)`.
struct BrandGradient: View {
    var body: some View {
        Rectangle()
            .fill(Self.sweep)
            .overlay {
                if let grain = Self.grain {
                    Rectangle().fill(ImagePaint(image: grain))
                }
            }
            .accessibilityHidden(true)
    }

    /// The gradient with no grain, as a style for a shape or a line.
    ///
    /// It is `conic-gradient(from 210deg at 55% 55%, start, end, start)` of the design system. An angle of SwiftUI
    /// starts at 3 o'clock, which is 90 degrees after the start of a CSS angle. The colours mix in a perceptual
    /// colour space, as in the Android app.
    static var sweep: some ShapeStyle {
        .conicGradient(
            Gradient(colors: [Palette.Brand.gradientStart, Palette.Brand.gradientStop, Palette.Brand.gradientStart])
                .colorSpace(.perceptual),
            center: UnitPoint(x: 0.55, y: 0.55),
            angle: .degrees(120)
        )
    }

    /// The grain: a square of 64 x 64 pixels of black with an opacity from 0% to 14%, which repeats.
    @MainActor private static let grain: Image? = {
        let side = 64
        var random = SplitMix64(state: 7)
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        for pixel in 0 ..< side * side {
            pixels[pixel * 4 + 3] = UInt8(random.next() % 36)
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                  width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: side * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              )
        else {
            return nil
        }
        return Image(decorative: image, scale: 3)
    }()
}

/// A small random number generator with a fixed start, so that the grain is the same each time.
private struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

extension View {
    /// Puts the signature gradient with its grain behind the view, in the `shape`.
    func brandGradient(in shape: some Shape) -> some View {
        background { BrandGradient().clipShape(shape) }
    }
}

/// The icon of the product in the app: the fridge on the signature gradient, in the shape of the house icon.
/// It is decorative. Home has it on the card of the totals, and About has it above the name.
struct BrandTile: View {
    /// The side of the tile at the default text size.
    var size: CGFloat = 64

    var body: some View {
        Image(icon: .fridge, filled: true)
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.46, height: size * 0.46)
            .foregroundStyle(Palette.Brand.gradientInk)
            .frame(width: size, height: size)
            .brandGradient(in: Radius.shape(size * 0.22))
            .accessibilityHidden(true)
    }
}

/// A composition of the house slice, for an empty state: the disc with its slice cut out, the slice beside it, a dot,
/// and a bar. The product has no motif of its own, so the slice is in its place.
///
/// The slice moves out and back, which is the brand loop of the design system. It does not move when Reduce Motion is
/// on. Use one composition on a screen. It is decorative.
struct SliceComposition: View {
    /// The width at the default size. The height is two thirds of the width.
    var width: CGFloat = 96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var out = false

    var body: some View {
        // One unit is 1 point at the width of 96 points.
        let unit = width / 96
        let disc = 44 * unit
        let drift = (reduceMotion ? 6 : out ? 11 : 5) * unit
        ZStack(alignment: .topLeading) {
            Color.clear
            // The cut is 70 degrees wide, with its opening to the right.
            Wedge(start: .degrees(35), end: .degrees(325))
                .fill(Palette.Brand.houseBlue)
                .frame(width: disc, height: disc)
                .offset(x: 4 * unit, y: 10 * unit)
            Wedge(start: .degrees(-35), end: .degrees(35))
                .fill(Palette.Brand.apricot)
                .frame(width: disc, height: disc)
                .offset(x: 4 * unit + drift, y: 10 * unit)
            Circle()
                .fill(Palette.Brand.houseInk)
                .frame(width: 7 * unit, height: 7 * unit)
                .offset(x: 80.5 * unit, y: 10.5 * unit)
            Capsule()
                .fill(Palette.Brand.houseInk)
                .frame(width: 18 * unit, height: 6 * unit)
                .offset(x: 74 * unit, y: 46 * unit)
        }
        .frame(width: width, height: width * 2 / 3)
        .animation(
            out && !reduceMotion ? .easeInOut(duration: Motion.brandLoopSeconds).repeatForever(autoreverses: true) : nil,
            value: out
        )
        .onAppear { out = true }
        .onDisappear { out = false }
        .accessibilityHidden(true)
    }
}

/// A part of a disc from the `start` angle to the `end` angle, clockwise. An angle of 0 is at 3 o'clock.
private struct Wedge: Shape {
    let start: Angle
    let end: Angle

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: centre)
        path.addArc(center: centre, radius: min(rect.width, rect.height) / 2, startAngle: start, endAngle: end, clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// The spinner of the design system: a ring that goes from transparent to the green and then to the end colour of the
/// gradient. It shows that the app is busy. It does not turn when Reduce Motion is on, so put words next to it (see
/// `LoadingView`).
///
/// VoiceOver reads the `label`. Give nil when the words next to the spinner say the same.
struct BrandSpinner: View {
    /// The diameter at the default text size. It grows with the text size, to 1.5 times at most.
    var size: CGFloat = 20
    var label: LocalizedStringKey? = "Loading"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
    @State private var turning = false

    var body: some View {
        let side = size * min(scale, 1.5)
        let line = side * 0.12
        Circle()
            .inset(by: line / 2)
            .stroke(
                AngularGradient(
                    stops: [
                        .init(color: Palette.primary.opacity(0), location: 0),
                        .init(color: Palette.primary, location: 0.7),
                        .init(color: Palette.Brand.gradientEnd, location: 1),
                    ],
                    center: .center
                ),
                lineWidth: line
            )
            .frame(width: side, height: side)
            .rotationEffect(.degrees(turning && !reduceMotion ? 360 : 0))
            .animation(
                turning && !reduceMotion ? .linear(duration: Motion.spinnerTurnSeconds).repeatForever(autoreverses: false) : nil,
                value: turning
            )
            .onAppear { turning = true }
            .onDisappear { turning = false }
            .accessibilityElement()
            .accessibilityLabel(label.map { Text($0) } ?? Text(verbatim: ""))
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityHidden(label == nil)
    }
}
