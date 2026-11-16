import SwiftUI

/// A chip that is on or off, with an optional number: a filter of My Fridge ("Expiring 3").
///
/// ```swift
/// FlowLayout {
///     MenuChip("Category", selection: selectedName) { … }
///     FilterChip("Expiring", count: "3", isOn: $showsExpiring)
///     FilterChip("Expired", count: "1", isOn: $showsExpired)
/// }
/// ```
///
/// A chip that is on has a fill and a check mark, so colour is not the only sign. A change gives the selection
/// haptic. VoiceOver reads the chip as a switch with the name and the number. Add `accessibilityLabel` for a longer
/// name ("Freshness: Expiring, 3 foods"). The target is 44 points high.
struct FilterChip: View {
    private let title: LocalizedStringKey
    private let count: String?
    @Binding private var isOn: Bool

    /// - Parameter count: The number, in the format of the locale of the person, or nil for no number.
    init(_ title: LocalizedStringKey, count: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.count = count
        _isOn = isOn
    }

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ChipBody(selected: isOn) {
                if isOn {
                    Image(icon: .check)
                        .font(.footnote.weight(.bold))
                        .transition(.scaleFade())
                }
                Text(title)
                if let count {
                    Text(verbatim: count)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
        }
        .buttonStyle(.card)
        .motion(Motion.selection, value: isOn)
        .haptic(.selection, trigger: isOn)
        .accessibilityRepresentation {
            Toggle(isOn: $isOn) {
                Text(title)
                if let count {
                    Text(verbatim: count)
                }
            }
        }
    }
}

/// A chip that opens a menu: the category filter of My Fridge. It shows the `title`, or the `selection` in the
/// selected state when a value is selected. It always has an arrow, because it opens a list.
///
/// ```swift
/// MenuChip("Category", selection: category.map(name)) {
///     Picker("Category", selection: $category) { … }
/// }
/// ```
struct MenuChip<MenuContent: View>: View {
    private let title: LocalizedStringKey
    private let selection: String?
    private let menu: MenuContent

    /// - Parameter selection: The name of the selected value, or nil when no value is selected.
    init(_ title: LocalizedStringKey, selection: String? = nil, @ViewBuilder menu: () -> MenuContent) {
        self.title = title
        self.selection = selection
        self.menu = menu()
    }

    var body: some View {
        Menu {
            menu
        } label: {
            ChipBody(selected: selection != nil) {
                if let selection {
                    Text(verbatim: selection)
                } else {
                    Text(title)
                }
                Image(icon: .menuDown)
                    .font(.caption.weight(.bold))
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.card)
        .accessibilityLabel(Text(title))
        .accessibilityValue(selection.map { Text(verbatim: $0) } ?? Text(verbatim: ""))
    }
}

/// The look of a chip: a capsule with a line when it is off, and with a fill when it is selected.
///
/// At the accessibility text sizes, a long label can wrap to 3 lines, so that the full text shows. The shape is then
/// a rectangle with round corners, because the ends of a high capsule cut the text.
private struct ChipBody<Content: View>: View {
    let selected: Bool
    @ViewBuilder let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The height of the chip with one line of text.
    private static var lineHeight: CGFloat { 36 }

    var body: some View {
        let wraps = dynamicTypeSize.isAccessibilitySize
        let shape = ChipShape(wraps: wraps, cornerRadius: Self.lineHeight / 2)
        HStack(spacing: Space.s1 + 2) { content }
            .font(Typography.label)
            .lineLimit(wraps ? 3 : 1)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: wraps)
            .foregroundStyle(selected ? Palette.onSecondaryContainer : Palette.onSurfaceVariant)
            .padding(.horizontal, Space.s3 + 2)
            .padding(.vertical, Space.s1 + 2)
            .frame(minHeight: Self.lineHeight)
            .background(selected ? Palette.secondaryContainer : .clear, in: shape)
            .overlay {
                shape.strokeBorder(selected ? Palette.secondaryContainer : Palette.outline, lineWidth: 1)
            }
            // The capsule is 36 points high. The target is 44 points high.
            .frame(minHeight: Metrics.minTarget)
            .contentShape(.rect)
    }
}

/// The shape of a chip: a capsule, or a rectangle with round corners when the label can wrap.
private struct ChipShape: InsettableShape {
    let wraps: Bool
    let cornerRadius: CGFloat
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: inset, dy: inset)
        if wraps {
            return Radius.shape(max(cornerRadius - inset, 0)).path(in: box)
        }
        return Capsule().path(in: box)
    }

    func inset(by amount: CGFloat) -> ChipShape {
        var shape = self
        shape.inset += amount
        return shape
    }
}
