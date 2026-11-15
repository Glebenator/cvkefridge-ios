import SwiftUI

/// The motion values of the app. Use these names, not literal animations, so that each screen moves the same.
///
/// The Android app has two values with the standard easing: 340 ms for things that arrive and 240 ms for things that
/// leave. The iOS app keeps the two durations, but as springs with no bounce, so that a change which starts during an
/// animation continues from the current speed.
///
/// | Name | Use |
/// | --- | --- |
/// | `enter` | A thing arrives: content after loading, a message, a new row |
/// | `exit` | A thing leaves. An exit is shorter than an entrance |
/// | `selection` | A selection changes: a chip, a segment, a check mark |
/// | `press` | A card or a tile goes down below the finger and comes back |
/// | `settle` | A thing that the finger moved goes back to its place, or goes away |
/// | `list` | Rows change place after a sort, a filter, or a deleted row |
///
/// Use `motion(_:value:)` or `withMotion(_:reduceMotion:_:)` to apply them. With Reduce Motion on, they give a short
/// fade and no movement.
enum Motion {
    static let enter: Animation = .smooth(duration: 0.34)
    static let exit: Animation = .smooth(duration: 0.24)
    static let selection: Animation = .snappy(duration: 0.25)
    static let press: Animation = .snappy(duration: 0.18)
    static let settle: Animation = .spring(response: 0.35, dampingFraction: 0.82)
    static let list: Animation = .smooth(duration: 0.3)

    /// The animation that takes the place of each other one when Reduce Motion is on: a short fade.
    static let reduced: Animation = .easeInOut(duration: 0.2)

    /// The time of one direction of the brand loop, in seconds.
    static let brandLoopSeconds: Double = 2.4
    /// The time of one turn of the spinner, in seconds.
    static let spinnerTurnSeconds: Double = 1

    /// The `animation`, or the short fade when Reduce Motion is on.
    static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : animation
    }
}

/// Runs the `body` with the `animation`, or with the short fade when Reduce Motion is on.
///
/// Read `@Environment(\.accessibilityReduceMotion)` in the view and give its value.
@MainActor
func withMotion<Result>(_ animation: Animation, reduceMotion: Bool, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(Motion.resolved(animation, reduceMotion: reduceMotion), body)
}

extension View {
    /// Animates the changes of the `value` with the `animation`, or with the short fade when Reduce Motion is on.
    func motion(_ animation: Animation, value: some Equatable) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }
}

private struct MotionModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {
        content.animation(Motion.resolved(animation, reduceMotion: reduceMotion), value: value)
    }
}

/// A thing that arrives from below: it fades in, moves up 16 points, and grows from 94%. It leaves down with a fade.
/// It is the transition of a floating message. With Reduce Motion on, it is a fade only.
///
/// ```swift
/// if let notice { NoticeCard(notice.text, kind: notice.kind).transition(.rise) }
/// ```
struct RiseTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(RiseEffect(phase: phase))
    }
}

private struct RiseEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let phase: TransitionPhase

    func body(content: Content) -> some View {
        let moves = !reduceMotion && !phase.isIdentity
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .scaleEffect(moves && phase == .willAppear ? 0.94 : 1)
            .offset(y: moves ? 16 : 0)
    }
}

extension Transition where Self == RiseTransition {
    /// See `RiseTransition`.
    static var rise: RiseTransition { RiseTransition() }
}
