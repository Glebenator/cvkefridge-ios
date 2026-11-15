import SwiftUI

/// One count of the card of the totals, as a button: the icon of the status on a tile, the number in the colour of
/// the status, its name, and an arrow that shows that a tap opens something.
///
/// ```swift
/// AdaptiveStack {
///     StatTile("Expiring", value: "3", kind: .expiring) { show(.expiring) }
///     StatTile("Expired", value: "1", kind: .expired) { show(.expired) }
/// }
/// ```
///
/// Before the inventory is loaded, give the sign for "no value" and add `.disabled(true)`. The tile then has no
/// arrow. VoiceOver reads the name and the number as one button. Add `accessibilityHint` for what the tap opens.
struct StatTile: View {
    enum Kind: Sendable {
        case expiring
        case expired

        var icon: AppIcon {
            switch self {
            case .expiring: .clock
            case .expired: .alert
            }
        }

        var color: Color {
            switch self {
            case .expiring: Palette.Status.expiring
            case .expired: Palette.Status.expired
            }
        }

        var tile: TileTone {
            switch self {
            case .expiring: .expiring
            case .expired: .expired
            }
        }
    }

    private let label: LocalizedStringKey
    private let value: String
    private let kind: Kind
    private let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    /// - Parameters:
    ///   - label: The name of the count.
    ///   - value: The number, in the format of the locale of the person.
    init(_ label: LocalizedStringKey, value: String, kind: Kind, action: @escaping () -> Void) {
        self.label = label
        self.value = value
        self.kind = kind
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s2) {
                IconTile(kind.icon, tone: kind.tile, filled: false)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: value)
                        .font(Typography.metricValue)
                        .foregroundStyle(kind.color)
                        .contentTransition(.numericText())
                    Text(label)
                        .font(Typography.label)
                        .foregroundStyle(Palette.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isEnabled {
                    Image(icon: .forward)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.onSurfaceVariant)
                        .accessibilityHidden(true)
                }
            }
            .padding(.leading, Space.s2)
            .padding(.trailing, Space.s3)
            .padding(.vertical, Space.s2)
            .frame(minHeight: 64)
            .surface(Palette.surfaceContainerHighest, radius: Radius.medium)
        }
        .buttonStyle(.card)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(verbatim: value))
    }
}
