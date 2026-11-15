import Observation
import SwiftUI
import UIKit

// The floating message of the app. `FridgeModel.notice` has the message, `NoticeCard` is its look, and this file
// decides where and how long it shows. It takes the place of `ui/NoticeHost.kt` of the Android app.
//
// A view that can show the message has the modifier `noticeHost()`. The message shows at the bottom edge of that
// view, in its safe area: above the tab bar, above the bar with the buttons of a form, and above the keyboard.
//
// More than one host is on the screen at a time: the selected tab, and each sheet above it. Only one host shows the
// message: the host that is deepest in the views. So a message shows above a sheet when a sheet is open, and at the
// tab bar when the sheet closed.
//
// - The message comes up from below, and a new message replaces the one on the screen.
// - It stays 4 seconds, or 8 seconds with a button. With VoiceOver or Switch Control it stays longer.
// - The time stops while a finger is on the message, and while VoiceOver is on it. It starts again after that.
// - A swipe to the side or down removes it. VoiceOver has the escape gesture.
// - It gives the haptic signal of its kind, and VoiceOver reads it.
// - A shake of the phone undoes a message with "Undo", with the Undo question of the system.

extension View {
    /// Shows the messages of the model at the bottom edge of this view, above its bottom bars. Put it on the root
    /// view of a sheet that the screen shows itself. `RootView` and `FormSheet` already have it.
    func noticeHost() -> some View {
        modifier(NoticeHostModifier())
    }
}

extension EnvironmentValues {
    /// How many notice hosts are above a view. The deepest host shows the message.
    @Entry var noticeHostDepth = 0

    /// False for the hosts of a sheet that closes. The message then shows below the sheet at once, and it does not
    /// go away with the sheet.
    @Entry var noticeHostEnabled = true
}

/// The hosts that are on the screen, and which of them shows the message.
@Observable
@MainActor
final class NoticeStage {
    private struct Host: Equatable {
        let id: UUID
        var depth: Int
        var enabled: Bool
        let order: Int
    }

    private var hosts: [Host] = []
    @ObservationIgnored private var order = 0
    /// The newest message that got its haptic signal and its announcement.
    @ObservationIgnored private var announced = 0

    /// The host that shows the message: the deepest host that is enabled, and of two with the same depth the newer.
    var active: UUID? {
        hosts.filter(\.enabled).max { ($0.depth, $0.order) < ($1.depth, $1.order) }?.id
    }

    func register(_ id: UUID, depth: Int, enabled: Bool) {
        order += 1
        hosts.removeAll { $0.id == id }
        hosts.append(Host(id: id, depth: depth, enabled: enabled, order: order))
    }

    func setEnabled(_ id: UUID, _ enabled: Bool) {
        if let index = hosts.firstIndex(where: { $0.id == id }), hosts[index].enabled != enabled {
            hosts[index].enabled = enabled
        }
    }

    func unregister(_ id: UUID) {
        hosts.removeAll { $0.id == id }
    }

    /// True the first time for each message. A message that moves from one host to another gives its signal one
    /// time.
    func firstShow(of noticeId: Int) -> Bool {
        if noticeId <= announced {
            return false
        }
        announced = noticeId
        return true
    }
}

private struct NoticeHostModifier: ViewModifier {
    @Environment(NoticeStage.self) private var stage
    @Environment(\.noticeHostDepth) private var depth
    @Environment(\.noticeHostEnabled) private var enabled
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .environment(\.noticeHostDepth, depth + 1)
            .overlay(alignment: .bottom) {
                NoticeLayer(isActive: stage.active == id)
            }
            .onAppear { stage.register(id, depth: depth + 1, enabled: enabled) }
            .onChange(of: enabled) { _, new in stage.setEnabled(id, new) }
            .onDisappear { stage.unregister(id) }
    }
}

/// The place of the message in a host.
private struct NoticeLayer: View {
    let isActive: Bool
    @Environment(FridgeModel.self) private var model

    var body: some View {
        let notice = isActive ? model.notice : nil
        ZStack(alignment: .bottom) {
            if let notice {
                NoticeView(notice: notice)
                    .id(notice.id)
                    .transition(.rise)
            }
        }
        .padding(.horizontal, Space.screenMargin)
        .padding(.bottom, Space.s2)
        .motion(Motion.enter, value: notice?.id)
    }
}

/// One message on the screen: the card, its time, its gestures, its haptic signal, and its announcement.
private struct NoticeView: View {
    let notice: Notice

    @Environment(FridgeModel.self) private var model
    @Environment(NoticeStage.self) private var stage
    @Environment(\.undoManager) private var undoManager
    /// True while a finger is on the message. It goes back to false also when the system stops the gesture.
    @GestureState private var pressed = false
    @State private var undoTarget = UndoTarget()
    @AccessibilityFocusState private var focused: Bool

    /// The time on the screen of a message with no button, in seconds.
    private static let plainSeconds: Double = 4
    /// The time on the screen of a message with a button ("Undo", "Try again"), in seconds.
    private static let actionSeconds: Double = 8
    /// A person who uses VoiceOver or Switch Control needs more time to get to the button.
    private static let assistiveFactor: Double = 4

    private var held: Bool {
        pressed || focused
    }

    var body: some View {
        card
            .swipeToDismiss { model.noticeShown(notice.id) }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0).updating($pressed) { _, state, _ in state = true }
            )
            .accessibilityFocused($focused)
            .accessibilityIdentifier("notice")
            .task(id: held) {
                // The time starts again when the finger goes up, so "Undo" does not go away below the finger.
                guard !held else {
                    return
                }
                try? await Task.sleep(for: .seconds(seconds))
                if !Task.isCancelled {
                    model.noticeShown(notice.id)
                }
            }
            .onAppear(perform: arrive)
            .onDisappear {
                undoManager?.removeAllActions(withTarget: undoTarget)
            }
    }

    @ViewBuilder private var card: some View {
        if let action = notice.action {
            NoticeCard(verbatim: notice.text.text, kind: notice.text.kind, actionTitle: action.title) {
                perform()
            }
        } else {
            NoticeCard(verbatim: notice.text.text, kind: notice.text.kind)
        }
    }

    private var seconds: Double {
        let base = notice.action == nil ? Self.plainSeconds : Self.actionSeconds
        let assistive = UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
        return assistive ? base * Self.assistiveFactor : base
    }

    private func perform() {
        model.noticeAction(notice)
        model.noticeShown(notice.id)
    }

    /// The message came to this host. The first host of a message gives the haptic signal and the announcement.
    private func arrive() {
        if notice.action == .undo, let undoManager {
            let notice = notice
            let model = model
            undoManager.registerUndo(withTarget: undoTarget) { _ in
                guard model.canPerformAction(of: notice) else {
                    return
                }
                model.noticeAction(notice)
                model.noticeShown(notice.id)
            }
            undoManager.setActionName(notice.text.text)
        }
        guard stage.firstShow(of: notice.id) else {
            return
        }
        notice.text.kind.haptic?.play()
        var announcement = AttributedString(spoken)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }

    /// What VoiceOver says when the message comes: the text, and that the message has a button.
    private var spoken: String {
        guard let action = notice.action else {
            return notice.text.text
        }
        return String(
            localized: "\(notice.text.text). \(action.label) button available.",
            comment: "VoiceOver reads it when a message comes. The values are the message and the name of its button."
        )
    }
}

/// The object that the Undo of the system keeps for one message.
private final class UndoTarget {}
