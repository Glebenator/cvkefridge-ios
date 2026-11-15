import SwiftUI
import UIKit

/// The haptic signals of the app. Use only these, so that one signal always means one thing.
///
/// | Signal | When |
/// | --- | --- |
/// | `selection` | A selection changes with no other result: a chip, a segment, a sort order, a storage area tab |
/// | `success` | An action is done: food added, a batch recorded as used, a barcode read, a change saved |
/// | `warning` | The app did the action, but the result needs attention: food thrown away, a thing deleted that "Undo" can bring back |
/// | `error` | The action failed, or the app refused it: a save failed, a form has a wrong value, no product for a barcode |
/// | `commit` | A swipe goes past the point where the action will occur when the finger goes up |
///
/// A button that only opens a screen has no signal. The system gives its own signals for switches, pickers, and
/// menus. Do not add a second one.
///
/// In a view, use `haptic(_:trigger:)`. The system then makes the signal ready before it is necessary:
///
/// ```swift
/// .haptic(.success, trigger: savedCount)
/// .haptic(trigger: notice) { _, new in new?.kind == .problem ? .error : nil }
/// ```
///
/// Where no view sees the change (a model, a gesture), call `play()` on the main actor.
enum Haptic: Sendable {
    case selection
    case success
    case warning
    case error
    case commit

    /// The value for the `sensoryFeedback` modifiers of SwiftUI.
    var feedback: SensoryFeedback {
        switch self {
        case .selection: .selection
        case .success: .success
        case .warning: .warning
        case .error: .error
        case .commit: .impact(weight: .medium)
        }
    }

    /// Gives the signal now.
    @MainActor
    func play() {
        switch self {
        case .selection: UISelectionFeedbackGenerator().selectionChanged()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error: UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .commit: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

extension View {
    /// Gives the `haptic` each time the `trigger` changes.
    func haptic(_ haptic: Haptic, trigger: some Equatable) -> some View {
        sensoryFeedback(haptic.feedback, trigger: trigger)
    }

    /// Gives the signal that `haptic` returns for the old and the new value of the `trigger`, or no signal for nil.
    func haptic<Trigger: Equatable>(
        trigger: Trigger,
        _ haptic: @escaping (_ old: Trigger, _ new: Trigger) -> Haptic?
    ) -> some View {
        sensoryFeedback(trigger: trigger) { old, new in haptic(old, new)?.feedback }
    }
}
