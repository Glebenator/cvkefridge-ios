#if DEBUG
import SwiftUI

/// A drawn picture in the place of the camera, for the debug build. The Simulator has no camera, so the scanner
/// shows "No camera on this device" there. With the launch argument `-scanStandIn`, the scanner shows this picture
/// as the picture of a camera that is open and has a light. So the layout of the scan window, the panel, and the
/// light button can be seen and tested on the Simulator, in each appearance and text size.
///
/// The stand-in reads no barcode. The release build does not have this file.
enum ScanStandIn {
    /// True when the launch arguments ask for the stand-in.
    static let isOn = ProcessInfo.processInfo.arguments.contains("-scanStandIn")
}

/// The picture of the stand-in: a shelf with a package that has a barcode. A tap gives its point, as a tap on the
/// picture of the camera does.
struct ScanStandInPicture: View {
    /// The scan window, in the coordinates of this view. The package is in it.
    let scanWindow: CGRect
    let onFocus: (CGPoint) -> Void

    var body: some View {
        Canvas { context, size in
            let all = CGRect(origin: .zero, size: size)
            context.fill(
                Path(all),
                with: .linearGradient(
                    Gradient(colors: [Color(rgb: 0x6B5A45), Color(rgb: 0x2E2A26), Color(rgb: 0x8A7B63)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )
            // The shelves.
            for part in stride(from: 0.2, through: 0.9, by: 0.23) {
                let y = size.height * part
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 10)), with: .color(Color(rgb: 0x1F1B17)))
            }
            // The package, with the bars of a barcode.
            let package = scanWindow.isEmpty
                ? CGRect(x: size.width * 0.2, y: size.height * 0.4, width: size.width * 0.6, height: size.height * 0.15)
                : scanWindow.insetBy(dx: scanWindow.width * 0.12, dy: scanWindow.height * 0.1)
            context.fill(Path(roundedRect: package, cornerRadius: 6), with: .color(Color(rgb: 0xF2EFE8)))
            let bars = package.insetBy(dx: package.width * 0.12, dy: package.height * 0.18)
            let widths: [CGFloat] = [2, 1, 1, 3, 1, 2, 2, 1, 3, 1, 1, 2, 1, 3, 2, 1, 1, 2, 3, 1, 2, 1, 1, 3, 1, 2]
            let unit = bars.width / (widths.reduce(0, +) * 2)
            var x = bars.minX
            for width in widths {
                context.fill(Path(CGRect(x: x, y: bars.minY, width: width * unit, height: bars.height)), with: .color(.black))
                x += width * unit * 2
            }
        }
        .contentShape(.rect)
        .onTapGesture(coordinateSpace: .local) { point in onFocus(point) }
        .accessibilityElement()
        .accessibilityLabel(Text("Camera picture. Point the camera at a barcode."))
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("camera")
    }
}
#endif
