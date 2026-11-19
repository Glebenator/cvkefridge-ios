import CVKEFridgeFeatures
import SwiftUI

/// The storage tips of a food, as a section of a `Form`. It takes the place of `ui/StorageAdviceCard.kt` of the
/// Android app (ADR 0012 in the cvkefridge repository).
///
/// The text from the package has a check mark and the words "From the package": it is about this product. The advice
/// of the table of foods has no check mark, and the section says that it is about the food in general. Each part
/// names its source.
///
/// ```swift
/// if let advice = form.storageAdvice(products: products, foods: foods) {
///     StorageTipsSection(advice: advice)
/// }
/// ```
struct StorageTipsSection: View {
    let advice: StorageAdvice

    var body: some View {
        Section {
            if let text = advice.packageText {
                packagePart(text)
            }
            if let general = advice.general {
                generalPart(general)
            }
        } header: {
            Text("Storage tips")
                .accessibilityIdentifier("storage_advice")
        }
    }

    /// The storage text of the product, with the check mark.
    private func packagePart(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            // The words say what the check mark means, so VoiceOver does not need the icon.
            HStack(alignment: .firstTextBaseline, spacing: Space.s1 + 2) {
                Image(icon: .done, filled: true)
                    .foregroundStyle(Palette.primary)
                    .accessibilityHidden(true)
                Text("From the package")
                    .foregroundStyle(Palette.onSurface)
                    .accessibilityAddTraits(.isHeader)
            }
            .font(Typography.label.weight(.semibold))
            Text(verbatim: text)
                .font(Typography.secondary)
                .foregroundStyle(Palette.onSurface)
                .accessibilityIdentifier("storage_advice_package")
            Text("This text is about this product. It comes from Open Food Facts.")
                .font(Typography.caption)
                .foregroundStyle(Palette.onSurfaceVariant)
        }
        .padding(.vertical, Space.s1)
    }

    /// The advice of the table of foods: the usual place, and one line for each storage kind.
    private func generalPart(_ general: GeneralAdvice) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text("General advice for \(general.foodName)")
                .font(Typography.label.weight(.semibold))
                .foregroundStyle(Palette.onSurface)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("storage_advice_general")
            if let kind = general.usualKind {
                Text("Usual place: \(kind.label)")
                    .font(Typography.secondary)
                    .foregroundStyle(Palette.onSurface)
                    .accessibilityIdentifier("storage_advice_usual")
            }
            ForEach(general.kinds, id: \.kind) { line in
                Text(kindLine(line))
                    .font(Typography.secondary)
                    .foregroundStyle(Palette.onSurface)
                    .accessibilityIdentifier("storage_advice_\(line.kind.rawValue)")
            }
            Text("This advice is about the food in general, not about this product. It comes from the USDA FoodKeeper data.")
                .font(Typography.caption)
                .foregroundStyle(Palette.onSurfaceVariant)
        }
        .padding(.vertical, Space.s1)
    }

    /// One storage kind: its name in a heavier weight, the time that the food keeps there, and the tip. The time is
    /// an estimate, and the text says so ("About 3 days.").
    private func kindLine(_ line: KindAdvice) -> AttributedString {
        var name = AttributedString(line.kind.label)
        name.font = Typography.secondary.weight(.semibold)
        let details = [line.time.map { Wording.text($0) }, line.tip].compactMap { $0 }.joined(separator: " ")
        return name + AttributedString("  " + details)
    }
}
