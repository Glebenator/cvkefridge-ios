import SwiftUI

// Liquid Glass is the material of the controls that float above the content: bars, floating buttons, and floating
// messages. The system bars (the tab bar, the navigation bar, a toolbar, a sheet) get glass from the system. The
// parts in this file are for the controls that the app makes itself. Content (cards, tiles, chips, rows) is opaque.
// Do not put glass on glass.

extension View {
    /// Gives the view a Liquid Glass surface in the `shape`. Use it for a control that floats above the content.
    ///
    /// With Reduce Transparency on, the surface is an opaque surface of the scheme with a line and a shadow.
    ///
    /// - Parameters:
    ///   - shape: The shape of the surface.
    ///   - tint: A colour for the glass, for the one prominent control. Nil for clear glass.
    ///   - interactive: True for a control that the person can tap. The glass then reacts to the touch.
    func floatingGlass(in shape: some Shape = Capsule(), tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(FloatingGlass(shape: shape, tint: tint, interactive: interactive))
    }
}

private struct FloatingGlass<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let shape: S
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(tint ?? Palette.surfaceContainerHighest, in: shape)
                .overlay { shape.stroke(Palette.outlineVariant, lineWidth: 1) }
                .shadow(color: Palette.scrim.opacity(0.18), radius: 12, y: 4)
        } else {
            content.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        }
    }
}

/// A capsule of Liquid Glass with a row of controls, which floats above the content: the controls of the scanner,
/// or a group of icon buttons. Put `GlassBarButton` parts in it.
///
/// ```swift
/// GlassCapsuleBar {
///     GlassBarButton(.flashlightOn, label: "Turn the light on") { … }
///     GlassBarButton(.keyboard, label: "Type the barcode") { … }
/// }
/// ```
struct GlassCapsuleBar<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    init(spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        HStack(spacing: spacing) { content }
            .padding(.horizontal, Space.s1)
            .floatingGlass(in: Capsule())
    }
}

/// A button with only an icon, for a `GlassCapsuleBar`. It has no surface of its own. Its target is 44 points or more.
///
/// As the icons of the system bars, the icon grows with the text size only to the first accessibility size. With a
/// larger text size, a long press shows the icon and its name at a large size.
struct GlassBarButton: View {
    private let icon: AppIcon
    private let filled: Bool
    private let label: LocalizedStringKey
    private let action: () -> Void

    /// - Parameter label: The name of the action, for VoiceOver and for the pointer.
    init(_ icon: AppIcon, filled: Bool = false, label: LocalizedStringKey, action: @escaping () -> Void) {
        self.icon = icon
        self.filled = filled
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(icon: icon, filled: filled)
                .font(.body.weight(.medium))
                .frame(minWidth: Metrics.minTarget + 4, minHeight: Metrics.minTarget + 4)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.onSurface)
        .barIcon(icon, label: label)
    }
}

/// A round Liquid Glass button with only an icon, which floats above the content: the add button at the tab bar,
/// the close button of the scanner.
///
/// ```swift
/// GlassIconButton(.add, label: "Add food", prominent: true) { … }
/// ```
///
/// The icon grows with the text size as the icon of a `GlassBarButton` does.
struct GlassIconButton: View {
    private let icon: AppIcon
    private let label: LocalizedStringKey
    private let prominent: Bool
    private let action: () -> Void

    /// - Parameters:
    ///   - label: The name of the action, for VoiceOver and for the pointer.
    ///   - prominent: True for the one main action. The glass then has the accent colour.
    init(_ icon: AppIcon, label: LocalizedStringKey, prominent: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.prominent = prominent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(icon: icon)
                .font(.title3.weight(.semibold))
                .frame(minWidth: 32, minHeight: 32)
        }
        .buttonStyle(AppButtonStyle(kind: prominent ? .floatingPrimary : .floatingSecondary, circle: true))
        .barIcon(icon, label: label)
    }
}

private extension View {
    /// The behaviour of a button with only an icon in the layer of controls: the name for VoiceOver, a limit for
    /// the text size, and the large view of the system for the larger text sizes.
    func barIcon(_ icon: AppIcon, label: LocalizedStringKey) -> some View {
        dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .accessibilityLabel(Text(label))
            .accessibilityShowsLargeContentViewer {
                Image(icon: icon)
                Text(label)
            }
    }
}

/// One part of a `GlassSegmentedRow`.
struct GlassSegment<ID: Hashable & Sendable>: Identifiable, Sendable {
    let id: ID
    /// The name, as text of the person or text that is already localized.
    let title: String
}

/// A row of Liquid Glass capsules, one for each choice, with one selected. The row scrolls sideways when it is too
/// wide. It is for the storage areas of My Fridge, below the navigation bar.
///
/// ```swift
/// GlassSegmentedRow(areas.map { GlassSegment(id: $0.id, title: $0.name) }, selection: $areaId, label: "Storage area")
/// ```
///
/// A change of the selection gives the selection haptic, and the row scrolls to the selected capsule. VoiceOver
/// reads each capsule as a button that is selected or not.
struct GlassSegmentedRow<ID: Hashable & Sendable>: View {
    private let segments: [GlassSegment<ID>]
    @Binding private var selection: ID
    private let label: LocalizedStringKey

    /// - Parameter label: The name of the group of choices, for VoiceOver.
    init(_ segments: [GlassSegment<ID>], selection: Binding<ID>, label: LocalizedStringKey) {
        self.segments = segments
        _selection = selection
        self.label = label
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                GlassEffectContainer(spacing: Space.s2) {
                    HStack(spacing: Space.s2) {
                        ForEach(segments) { segment in
                            capsule(segment)
                        }
                    }
                    .padding(.horizontal, Space.screenMargin)
                    .padding(.vertical, Space.s1)
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .onChange(of: selection) { _, new in
                withAnimation(Motion.selection) { proxy.scrollTo(new, anchor: .center) }
            }
        }
        .haptic(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(label))
    }

    private func capsule(_ segment: GlassSegment<ID>) -> some View {
        let selected = segment.id == selection
        return Button {
            selection = segment.id
        } label: {
            Text(verbatim: segment.title)
                .font(Typography.label.weight(.semibold))
                .foregroundStyle(selected ? Palette.onPrimary : Palette.onSurface)
                .padding(.horizontal, Space.s4)
                .frame(minHeight: Metrics.minTarget)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .floatingGlass(in: Capsule(), tint: selected ? Palette.primary : nil, interactive: true)
        .motion(Motion.selection, value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .id(segment.id)
    }
}

/// The bar with the buttons of a form, which floats at the bottom edge above the content: "Save and add another"
/// and "Save". The buttons are Liquid Glass. The bar stays above the keyboard.
///
/// Put it on the scroll view of the form with `bottomActionBar`, so that the content scrolls below it with the soft
/// edge of the system:
///
/// ```swift
/// ScrollView { … }
///     .bottomActionBar {
///         Button("Save and add another") { … }.buttonStyle(.floatingSecondary)
///         Button("Save") { … }.buttonStyle(.floatingPrimary)
///     }
/// ```
///
/// Give the main action last. The buttons are side by side when they fit. With large text or a narrow screen, they
/// are one above the other, with the main action at the top.
struct BottomActionBar<Content: View>: View {
    private let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GlassEffectContainer(spacing: Space.s2) {
            if dynamicTypeSize.isAccessibilitySize {
                column
            } else {
                ViewThatFits(in: .horizontal) {
                    row
                    column
                }
            }
        }
        .padding(.horizontal, Space.screenMargin)
        .padding(.vertical, Space.s2)
        .contentWidth()
    }

    /// The buttons side by side. Each has the width of its label, and the last one takes the remaining width.
    private var row: some View {
        Group(subviews: content) { subviews in
            HStack(spacing: Space.s2) {
                ForEach(subviews.dropLast()) { subview in
                    subview.fixedSize(horizontal: true, vertical: false)
                }
                if let last = subviews.last {
                    last.buttonSizing(.flexible)
                }
            }
        }
    }

    /// The buttons one above the other, each as wide as the bar, in the opposite order.
    private var column: some View {
        Group(subviews: content) { subviews in
            VStack(spacing: Space.s2) {
                ForEach(subviews.reversed()) { subview in
                    subview.buttonSizing(.flexible)
                }
            }
        }
    }
}

extension View {
    /// Puts a `BottomActionBar` with the `buttons` at the bottom edge of the view. See `BottomActionBar`.
    func bottomActionBar(@ViewBuilder _ buttons: () -> some View) -> some View {
        safeAreaBar(edge: .bottom, spacing: 0) {
            BottomActionBar(content: buttons)
        }
    }
}
