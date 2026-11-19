import SwiftUI

/// The scan window: the frame in the picture of the camera where the scanner reads a barcode. The picture outside it
/// is darker. The Android app draws the same window (`ScanWindow` in `ui/ScanScreen.kt`), but its reader reads all of
/// the picture. Here the camera reads only in the window.
enum ScanWindow {
    /// The radius of the corners.
    static let cornerRadius: CGFloat = 16
    /// The largest width.
    static let maxWidth: CGFloat = 340

    /// The window in the middle of the `area`: 80% of its width and not wider than `maxWidth`, with the shape of a
    /// barcode, and not higher than half of the `area`.
    static func rect(in area: CGRect) -> CGRect {
        guard area.width > 0, area.height > 0 else {
            return .zero
        }
        let width = min(area.width * 0.8, maxWidth)
        let height = min(width * 0.55, area.height * 0.5)
        return CGRect(x: area.midX - width / 2, y: area.midY - height / 2, width: width, height: height)
    }
}

/// The darker picture outside the scan window, and the frame of the window. It is above the picture of the camera,
/// and it takes no touches. VoiceOver does not read it.
struct ScanWindowShade: View {
    /// The window, in the coordinates of this view.
    let window: CGRect
    /// True while the camera reads. The frame is then bright.
    let isReading: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ScanWindow.cornerRadius, style: .continuous)
        ZStack {
            Outside(window: window)
                .fill(Palette.scrim.opacity(0.45), style: FillStyle(eoFill: true))
            if !window.isEmpty {
                shape
                    .stroke(Palette.primaryContainer.opacity(isReading ? 1 : 0.45), lineWidth: 3)
                    .frame(width: window.width, height: window.height)
                    .position(x: window.midX, y: window.midY)
                    .motion(Motion.selection, value: isReading)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// All of the view with the window cut out.
    private struct Outside: Shape {
        let window: CGRect

        func path(in rect: CGRect) -> Path {
            var path = Path(rect)
            if !window.isEmpty {
                path.addRoundedRect(
                    in: window,
                    cornerSize: CGSize(width: ScanWindow.cornerRadius, height: ScanWindow.cornerRadius),
                    style: .continuous
                )
            }
            return path
        }
    }
}

/// The point of a tap that focused the camera.
struct FocusMark: Equatable {
    /// A number that is different for each tap.
    let id: Int
    /// The point, in the coordinates of the picture of the camera.
    let point: CGPoint
}

/// The focus indicator: a frame at the point of the tap, which comes in from a larger size. It shows for a short
/// time. With Reduce Motion on, it does not change its size.
struct FocusMarkView: View {
    let mark: FocusMark

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    private static let side: CGFloat = 76

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Palette.primaryContainer, lineWidth: 2)
            .frame(width: Self.side, height: Self.side)
            .scaleEffect(settled || reduceMotion ? 1 : 1.35)
            .opacity(settled ? 1 : 0.4)
            .position(mark.point)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withMotion(Motion.settle, reduceMotion: reduceMotion) { settled = true }
            }
    }
}
