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
                        .transition(.scale.combined(with: .opacity))
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
private struct ChipBody<Content: View>: View {
    let selected: Bool
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: Space.s1 + 2) { content }
            .font(Typography.label)
            .lineLimit(1)
            .foregroundStyle(selected ? Palette.onSecondaryContainer : Palette.onSurfaceVariant)
            .padding(.horizontal, Space.s3 + 2)
            .padding(.vertical, Space.s1 + 2)
            .frame(minHeight: 36)
            .background(selected ? Palette.secondaryContainer : .clear, in: Capsule())
            .overlay {
                Capsule().strokeBorder(selected ? Palette.secondaryContainer : Palette.outline, lineWidth: 1)
            }
            // The capsule is 36 points high. The target is 44 points high.
            .frame(minHeight: Metrics.minTarget)
            .contentShape(.rect)
    }
}
