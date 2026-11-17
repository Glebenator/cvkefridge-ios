import CVKEFridgeFeatures
import SwiftUI

/// The panel of the scanner: a Liquid Glass surface that floats above the picture of the camera, at the bottom edge
/// or at the side. It shows one of three things:
///
/// - With no lookup: the hint for the camera, what leaves the phone, and the two other ways to add food. "Type the
///   barcode" and "Add by hand" are always there, so the scanner works with no camera and with no permission.
/// - During a lookup: the barcode, and "Cancel".
/// - After a failed lookup: what failed, and "Try again", "Enter by hand", and "Scan again". The app does not try
///   again by itself.
///
/// The content scrolls when it is higher than the panel, for example with a large text size.
struct ScanPanel: View {
    let lookup: LookupState
    /// The hint for the camera, or nil when the camera does not show a picture.
    let hint: String?
    /// True for the panel at the side of the camera. It then has the full height.
    let fillsHeight: Bool
    let onTypeBarcode: () -> Void
    let onAddByHand: () -> Void
    let onCancel: () -> Void
    let onTryAgain: (_ barcode: String) -> Void
    let onEnterByHand: (_ barcode: String) -> Void

    /// The kind of content, for the animation between two kinds.
    private var kind: Int {
        switch lookup {
        case .idle, .done: 0
        case .looking: 1
        case .failed: 2
        }
    }

    var body: some View {
        let shape = Radius.shape(Radius.extraLarge)
        ViewThatFits(in: .vertical) {
            content
            ScrollView {
                content
            }
            .scrollBounceBehavior(.basedOnSize)
            .clipShape(shape)
        }
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil)
        .floatingGlass(in: shape)
        .motion(Motion.enter, value: kind)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scan_panel")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            switch lookup {
            case .idle, .done:
                IdlePanel(hint: hint, onTypeBarcode: onTypeBarcode, onAddByHand: onAddByHand)
            case .looking(let barcode):
                LookingPanel(barcode: barcode, onCancel: onCancel)
            case .failed(let barcode, let failure):
                FailedPanel(
                    barcode: barcode,
                    failure: failure,
                    onScanAgain: onCancel,
                    onEnterByHand: { onEnterByHand(barcode) },
                    onTryAgain: { onTryAgain(barcode) }
                )
            }
        }
        .padding(Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        // A change of the kind of content is a new view, which fades in.
        .id(kind)
        .transition(.fade)
    }
}

/// The panel with no lookup.
private struct IdlePanel: View {
    let hint: String?
    let onTypeBarcode: () -> Void
    let onAddByHand: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let hint {
            Text(verbatim: hint)
                .font(Typography.cardTitle)
                .foregroundStyle(Palette.onSurface)
                .fixedSize(horizontal: false, vertical: true)
                .motion(Motion.enter, value: hint)
                .accessibilityIdentifier("scan_hint")
        }
        Label {
            Text("Only the barcode number goes to Open Food Facts, to find the product name. Nothing else leaves your phone.")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(icon: .info)
        }
        .font(Typography.secondary)
        .foregroundStyle(Palette.onSurfaceVariant)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("scan_privacy")
        if dynamicTypeSize.isAccessibilitySize {
            column
        } else {
            ViewThatFits(in: .horizontal) {
                // Each label stays on one line. The second button takes the remaining width.
                HStack(spacing: Space.s2) {
                    typeBarcode(fullWidth: false)
                        .fixedSize()
                    addByHand
                }
                column
            }
        }
    }

    private var column: some View {
        VStack(spacing: Space.s2) {
            typeBarcode(fullWidth: true)
            addByHand
        }
    }

    private func typeBarcode(fullWidth: Bool) -> some View {
        Button("Type the barcode", systemImage: AppIcon.keyboard.symbol, action: onTypeBarcode)
            .buttonStyle(.secondary(.compact, fullWidth: fullWidth))
            .accessibilityIdentifier("type_barcode")
    }

    private var addByHand: some View {
        Button("Add by hand", systemImage: AppIcon.addByHand.symbol, action: onAddByHand)
            .buttonStyle(.secondary(.compact, fullWidth: true))
            .accessibilityIdentifier("scan_add_by_hand")
    }
}

/// The panel during a lookup: the spinner, the barcode, and "Cancel".
private struct LookingPanel: View {
    let barcode: String
    let onCancel: () -> Void

    var body: some View {
        AdaptiveStack(horizontalAlignment: .leading, spacing: Space.s3) {
            HStack(spacing: Space.s3) {
                BrandSpinner(size: 24, label: nil)
                Text(verbatim: Wording.lookingUp(barcode: barcode))
                    .font(Typography.body)
                    .foregroundStyle(Palette.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(Wording.spokenLookingUp(barcode: barcode)))
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("lookup_looking")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Cancel", action: onCancel)
                .buttonStyle(.quiet)
                .accessibilityIdentifier("lookup_cancel")
        }
    }
}

/// The panel after a failed lookup: what failed, and three ways to continue. The barcode stays for "Try again" and
/// "Enter by hand".
private struct FailedPanel: View {
    let barcode: String
    let failure: LookupFailure
    let onScanAgain: () -> Void
    let onEnterByHand: () -> Void
    let onTryAgain: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var focused: Bool

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: Space.s1) {
                Text(verbatim: failure.title)
                    .font(Typography.cardTitle)
                    .foregroundStyle(Palette.onSurface)
                Text(verbatim: failure.message(barcode: barcode))
                    .font(Typography.secondary)
                    .foregroundStyle(Palette.onSurfaceVariant)
            }
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(icon: failure.icon)
                .foregroundStyle(Palette.error)
        }
        .accessibilityElement(children: .combine)
        .accessibilityFocused($focused)
        .accessibilityIdentifier("lookup_failed")
        .onAppear { focused = true }

        if dynamicTypeSize.isAccessibilitySize {
            // One above the other, with the main action first.
            VStack(spacing: Space.s2) {
                tryAgain(fullWidth: true)
                enterByHand(fullWidth: true)
                scanAgain
            }
        } else {
            FlowLayout(alignment: .trailing, spacing: Space.s2) {
                scanAgain
                enterByHand(fullWidth: false)
                tryAgain(fullWidth: false)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var scanAgain: some View {
        Button("Scan again", action: onScanAgain)
            .buttonStyle(.quiet)
            .accessibilityIdentifier("scan_again")
    }

    private func enterByHand(fullWidth: Bool) -> some View {
        Button("Enter by hand", action: onEnterByHand)
            .buttonStyle(.secondary(.compact, fullWidth: fullWidth))
            .accessibilityIdentifier("enter_by_hand")
    }

    private func tryAgain(fullWidth: Bool) -> some View {
        Button("Try again", action: onTryAgain)
            .buttonStyle(.primary(.compact, fullWidth: fullWidth))
            .accessibilityIdentifier("lookup_try_again")
    }
}
