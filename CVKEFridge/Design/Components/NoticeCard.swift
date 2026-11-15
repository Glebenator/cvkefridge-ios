import SwiftUI

/// The kind of a floating message. It gives the icon, the colour of the icon, and the haptic signal.
enum NoticeKind: Sendable, CaseIterable {
    /// The action worked: food added, food used.
    case done
    /// The action deleted something.
    case deleted
    /// Information with no result of an action.
    case information
    /// The action failed, or the app refused it.
    case problem

    var icon: AppIcon {
        switch self {
        case .done: .done
        case .deleted: .delete
        case .information: .info
        case .problem: .alert
        }
    }

    var color: Color {
        switch self {
        case .done: Palette.Status.fresh
        case .deleted: Palette.onSurfaceVariant
        case .information: Palette.primary
        case .problem: Palette.error
        }
    }

    /// The signal to give when the message comes, or nil for no signal.
    var haptic: Haptic? {
        switch self {
        case .done: .success
        case .deleted: .warning
        case .information: nil
        case .problem: .error
        }
    }
}

/// The floating message: an icon for the kind of the message, the text, and an optional button ("Undo",
/// "Try again"), on a Liquid Glass surface. It takes the place of the snackbar of the Android app.
///
/// This view is only the look. The part that shows it gives the position above the tab bar, the time on the screen,
/// the haptic of `NoticeKind`, and the VoiceOver announcement:
///
/// ```swift
/// NoticeCard(verbatim: notice.text, kind: notice.kind, actionTitle: "Undo") { undo() }
///     .swipeToDismiss { model.dismissNotice() }
///     .transition(.rise)
/// ```
///
/// The text has 3 lines at most. With an accessibility text size, it has 6 lines at most and the button is below the
/// text. The card is not wider than `Metrics.noticeMaxWidth`. With Reduce Transparency on, the surface is opaque.
struct NoticeCard: View {
    private let text: Text
    private let kind: NoticeKind
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?
    private var onFocusChange: ((Bool) -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The part of the card that has the focus of VoiceOver or Switch Control, or nil.
    @AccessibilityFocusState private var focusedPart: Part?

    /// The parts of the card that VoiceOver reads one at a time.
    private enum Part: Hashable {
        case text
        case button
    }

    init(
        _ text: LocalizedStringKey,
        kind: NoticeKind,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.init(text: Text(text), kind: kind, actionTitle: actionTitle, action: action)
    }

    /// A message whose text has a name of the person in it, or is already localized.
    init(
        verbatim text: String,
        kind: NoticeKind,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.init(text: Text(verbatim: text), kind: kind, actionTitle: actionTitle, action: action)
    }

    private init(text: Text, kind: NoticeKind, actionTitle: LocalizedStringKey?, action: (() -> Void)?) {
        self.text = text
        self.kind = kind
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: Space.s2))
            : AnyLayout(HStackLayout(spacing: Space.s3))
        layout {
            HStack(alignment: .firstTextBaseline, spacing: Space.s3) {
                Image(icon: kind.icon, filled: true)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(kind.color)
                    .accessibilityHidden(true)
                text
                    .font(Typography.secondary)
                    .foregroundStyle(Palette.onSurface)
                    .lineLimit(stacked ? 6 : 3)
                    .frame(maxWidth: stacked ? .infinity : nil, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityFocused($focusedPart, equals: .text)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.secondary(.compact))
                    .accessibilityFocused($focusedPart, equals: .button)
            }
        }
        .padding(.leading, Space.s4 + 2)
        .padding(.trailing, action == nil ? Space.s5 : Space.s2)
        .padding(.vertical, Space.s2)
        .frame(minHeight: 56)
        .floatingGlass(in: Radius.shape(Radius.extraLarge))
        .frame(maxWidth: Metrics.noticeMaxWidth)
        .onChange(of: focusedPart != nil) { _, focused in
            onFocusChange?(focused)
        }
    }

    /// Calls `perform` with true when VoiceOver or Switch Control moves to the text or to the button of the card, and
    /// with false when the focus leaves the card. The text and the button are two elements, so a focus state on the
    /// card does not see them.
    func onAccessibilityFocusChange(_ perform: @escaping (Bool) -> Void) -> NoticeCard {
        var card = self
        card.onFocusChange = perform
        return card
    }
}

extension View {
    /// Lets the person move the view to one side or down to remove it. It is for a floating message.
    ///
    /// The view follows the finger and becomes transparent. A drag of a third of its width, a drag of half of its
    /// height down, or a fast flick removes it: the view goes away, and then `onDismiss` runs. A shorter drag lets the
    /// view go back. VoiceOver has the same action as the escape gesture.
    ///
    /// - Parameter onHold: Called with true when a drag starts and with false when it ends, so that the time of the
    ///   message can stop while a finger moves it.
    func swipeToDismiss(onHold: @escaping (Bool) -> Void = { _ in }, onDismiss: @escaping () -> Void) -> some View {
        modifier(SwipeToDismiss(onHold: onHold, onDismiss: onDismiss))
    }
}

private struct SwipeToDismiss: ViewModifier {
    let onHold: (Bool) -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGSize = .zero
    @State private var size: CGSize = .init(width: 1, height: 1)
    @State private var held = false

    /// How far the view is on its way out, from 0 to 1.
    private var progress: CGFloat {
        min(max(abs(offset.width) / size.width, offset.height / size.height), 1)
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = CGSize(width: max($0.width, 1), height: max($0.height, 1)) }
            .offset(offset)
            .opacity(1 - progress)
            .simultaneousGesture(drag)
            .accessibilityAction(.escape, onDismiss)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if !held {
                    held = true
                    onHold(true)
                }
                // The view follows the direction in which the drag is larger. It does not move up.
                let translation = value.translation
                offset = abs(translation.width) >= abs(translation.height)
                    ? CGSize(width: translation.width, height: 0)
                    : CGSize(width: 0, height: max(translation.height, 0))
            }
            .onEnded { value in
                held = false
                onHold(false)
                let sideways = offset.width != 0
                let flick = sideways
                    ? abs(value.predictedEndTranslation.width) > size.width
                    : value.predictedEndTranslation.height > size.height * 1.5
                let away = sideways ? abs(offset.width) > size.width / 3 || flick : offset.height > size.height / 2 || flick
                guard away else {
                    withMotion(Motion.settle, reduceMotion: reduceMotion) { offset = .zero }
                    return
                }
                Haptic.commit.play()
                let target = sideways
                    ? CGSize(width: (offset.width < 0 ? -1.2 : 1.2) * size.width, height: 0)
                    : CGSize(width: 0, height: size.height * 1.2)
                withAnimation(Motion.resolved(Motion.exit, reduceMotion: reduceMotion)) {
                    offset = target
                } completion: {
                    onDismiss()
                }
            }
    }
}
