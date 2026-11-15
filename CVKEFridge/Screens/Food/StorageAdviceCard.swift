import CVKEFridgeFeatures
import SwiftUI

/// The storage tips of a food. The text from the package has a check mark and the words "From the package": it is
/// about this product. The advice of the table of foods has no check mark, and the card says that it is about the
/// food in general. The card names the source of each part. It takes the place of `ui/StorageAdviceCard.kt` of the
/// Android app.
///
/// ```swift
/// if let advice = StorageAdvices.of(storageText: product.storageText, food: food) {
///     StorageAdviceCard(advice: advice)
/// }
/// ```
struct StorageAdviceCard: View {
    let advice: StorageAdvice

    var body: some View {
        SurfaceCard(.low) {
            VStack(alignment: .leading, spacing: Space.s3) {
                Text("Storage tips")
                    .font(Typography.label)
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .accessibilityAddTraits(.isHeader)
                if let text = advice.packageText {
                    packagePart(text)
                }
                if advice.packageText != nil, advice.general != nil {
                    Hairline()
                }
                if let general = advice.general {
                    generalPart(general)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("storage_advice")
    }

    /// The storage text of the product, with the check mark.
    private func packagePart(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s2) {
                // The words say what the check mark means, so VoiceOver does not need the icon.
                Image(icon: .done, filled: true)
                    .foregroundStyle(Palette.primary)
                    .accessibilityHidden(true)
                Text("From the package")
                    .font(Typography.secondary.weight(.semibold))
            }
            Text(verbatim: text)
                .font(Typography.secondary)
            Text("This text is about this product. It comes from Open Food Facts.")
                .font(Typography.caption)
                .foregroundStyle(Palette.onSurfaceVariant)
        }
        .foregroundStyle(Palette.onSurface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("storage_advice_package")
    }

    /// The advice of the table of foods: the usual place, and one line for each storage kind.
    private func generalPart(_ general: GeneralAdvice) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text("General advice for \(general.foodName)", comment: "The value is the name of a food of the table of foods, for example \"Bananas\".")
                .font(Typography.secondary.weight(.semibold))
            if let kind = general.usualKind {
                Text("Usual place: \(kind.label)", comment: "The value is a storage kind: Pantry, Fridge, or Freezer.")
                    .font(Typography.secondary)
            }
            ForEach(general.kinds, id: \.kind) { line in
                Text(kindLine(line))
                    .font(Typography.secondary)
                    .accessibilityIdentifier("storage_advice_\(line.kind.rawValue)")
            }
            Text("This advice is about the food in general, not about this product. It comes from the USDA FoodKeeper data.")
                .font(Typography.caption)
                .foregroundStyle(Palette.onSurfaceVariant)
        }
        .foregroundStyle(Palette.onSurface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("storage_advice_general")
    }

    /// One storage kind: its name with more weight, the time that the food keeps there, and the tip.
    private func kindLine(_ line: KindAdvice) -> AttributedString {
        var name = AttributedString(line.kind.label)
        name.font = Typography.secondary.weight(.semibold)
        let details = [line.time.map { Wording.text($0) }, line.tip].compactMap { $0 }.joined(separator: " ")
        return name + AttributedString("  \(details)")
    }
}
