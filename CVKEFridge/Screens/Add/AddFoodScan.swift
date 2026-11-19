import CVKEFridgeFeatures
import SwiftUI

// The two rows at the top of the add form that are about the barcode scanner. They take the place of `ScanCard` and
// `ScanNote` in `ui/AddFoodScreen.kt` of the Android app.

/// The large button at the top of the form for a new food: it opens the scanner, and the scan fills in the form. It
/// is larger than the fields, because a scan is the fast way to add food that has a barcode. It is a row of a `Form`
/// in the colour of the accent. It is content, so it is not Liquid Glass.
struct ScanCard: View {
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        Button(action: action) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.s3))
                : AnyLayout(HStackLayout(spacing: Space.s4))
            HStack(spacing: Space.s2) {
                layout {
                    Image(icon: .scan)
                        .font(.title2.weight(.medium))
                        .foregroundStyle(Palette.onPrimary)
                        .frame(width: side, height: side)
                        .background(Palette.primary, in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan a barcode")
                            .font(Typography.cardTitle)
                        Text("The barcode fills in the form")
                            .font(Typography.secondary)
                    }
                    .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(icon: .forward)
                    .font(.body.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Palette.onPrimaryContainer)
            .padding(Space.s4)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.card)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Palette.primaryContainer)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Opens the scanner."))
        .accessibilityIdentifier("name_scan")
    }

    /// The side of the circle with the icon: 56 points, and not more than 1.3 times that with large text.
    private var side: CGFloat {
        56 * min(scale, 1.3)
    }
}

/// Where the values of a scan come from, above the fields: "From Open Food Facts", or that the person must type the
/// name. It also shows the barcode that the food keeps. A product in the inventory needs no note: the name field says
/// that the form adds a batch to it.
struct ScanNote: View {
    let scan: Scanned

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s3) {
            Image(icon: .scan)
                .font(.title3)
                .foregroundStyle(Palette.primary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.s1) {
                Text(verbatim: source)
                    .font(Typography.body)
                    .foregroundStyle(Palette.onSurface)
                Text("Barcode \(scan.barcode). The app keeps it with the food, so the next scan finds it.")
                    .font(Typography.secondary)
                    .foregroundStyle(Palette.onSurfaceVariant)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("scan_note")
    }

    private var source: String {
        switch scan.source {
        case .found:
            String(localized: "From Open Food Facts. Check the values before you save.")
        case .notFound:
            String(localized: "Open Food Facts has no product with this barcode. Type the name.")
        case .notLookedUp:
            String(localized: "The app could not look up this barcode. Type the name.")
        case .inInventory:
            ""
        }
    }
}
