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
/// Use `motion(_:value:)` or `withMotion(_:reduceMotion:_:)` to apply them, and the transitions of this file
/// (`.fade`, `.rise`, `.scaleFade`) for a thing that arrives or leaves.
///
/// With Reduce Motion on, nothing moves, grows, or becomes smaller:
///
/// - A change has no animation. Each part is in its new place at once, and a thing that leaves goes away at once.
/// - A thing that arrives with one of the transitions of this file fades in (`reduced`). It does not move and it
///   does not change its size.
/// - A press changes only the opacity, and the loops of the brand parts stop.
///
/// Do not use `.scale`, `.move`, `.slide`, `.offset`, or `matchedGeometryEffect` as a transition, and do not use
/// `withAnimation` or `.animation` with a literal animation. They move also with Reduce Motion on.
enum Motion {
    static let enter: Animation = .smooth(duration: 0.34)
    static let exit: Animation = .smooth(duration: 0.24)
    static let selection: Animation = .snappy(duration: 0.25)
    static let press: Animation = .snappy(duration: 0.18)
    static let settle: Animation = .spring(response: 0.35, dampingFraction: 0.82)
    static let list: Animation = .smooth(duration: 0.3)

    /// The short fade of a thing that arrives while Reduce Motion is on. Only the transitions of this file use it.
    static let reduced: Animation = .easeInOut(duration: 0.2)

    /// The time of one direction of the brand loop, in seconds.
    static let brandLoopSeconds: Double = 2.4
    /// The time of one turn of the spinner, in seconds.
    static let spinnerTurnSeconds: Double = 1

    /// The `animation`, or no animation when Reduce Motion is on. An animation of a change animates each position
    /// and each size that the change gives, so with Reduce Motion on the change has none.
    static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

/// Runs the `body` with the `animation`, or with no animation when Reduce Motion is on.
///
/// Read `@Environment(\.accessibilityReduceMotion)` in the view and give its value.
@MainActor
func withMotion<Result>(_ animation: Animation, reduceMotion: Bool, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(Motion.resolved(animation, reduceMotion: reduceMotion), body)
}

extension View {
    /// Animates the changes of the `value` with the `animation`, or with no animation when Reduce Motion is on.
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

/// A thing that arrives or leaves with a fade. Use it in the place of `.opacity`: with Reduce Motion on, the change
/// that shows the thing has no animation, and this transition has the short fade of its own.
///
/// ```swift
/// if isBusy { ProgressView().transition(.fade) }
/// ```
struct FadeTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(ArrivalEffect(phase: phase, arrivalScale: 1, leaveScale: 1, anchor: .center, offset: 0))
    }
}

/// A thing that arrives from below: it fades in, moves up 16 points, and grows from 94%. It leaves down with a fade.
/// It is the transition of a floating message. With Reduce Motion on, it only fades in.
///
/// ```swift
/// if let notice { NoticeCard(notice.text, kind: notice.kind).transition(.rise) }
/// ```
struct RiseTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(ArrivalEffect(phase: phase, arrivalScale: 0.94, leaveScale: 1, anchor: .center, offset: 16))
    }
}

/// A thing that arrives and leaves with a fade and a change of its size, from and to the `anchor`: a check mark in
/// a chip, a card that the person closes. With Reduce Motion on, it only fades in.
///
/// ```swift
/// if isOn { Image(icon: .check).transition(.scaleFade()) }
/// if let offer { card(offer).transition(.scaleFade(0.96, anchor: .top)) }
/// ```
struct ScaleFadeTransition: Transition {
    /// The size at the start and at the end, as a part of the full size.
    var scale: CGFloat = 0.5
    var anchor: UnitPoint = .center

    func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(ArrivalEffect(phase: phase, arrivalScale: scale, leaveScale: scale, anchor: anchor, offset: 0))
    }
}

/// The look of a view in a phase of a transition of the app.
private struct ArrivalEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let phase: TransitionPhase
    /// The size before the view arrives and after it left, as a part of the full size.
    let arrivalScale: CGFloat
    let leaveScale: CGFloat
    let anchor: UnitPoint
    /// The distance below its place, before the view arrives and after it left.
    let offset: CGFloat

    func body(content: Content) -> some View {
        let moves = !reduceMotion && !phase.isIdentity
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .scaleEffect(moves ? (phase == .willAppear ? arrivalScale : leaveScale) : 1, anchor: anchor)
            .offset(y: moves ? offset : 0)
            .transaction(value: phase) { transaction in
                // With Reduce Motion on, the change that shows the view has no animation. The view fades in. A view
                // that leaves gets no fade: the parts around it are in their new places at once, and it would be
                // above them for the time of the fade.
                if reduceMotion, phase.isIdentity {
                    transaction.animation = Motion.reduced
                }
            }
    }
}

extension Transition where Self == FadeTransition {
    /// See `FadeTransition`.
    static var fade: FadeTransition { FadeTransition() }
}

extension Transition where Self == RiseTransition {
    /// See `RiseTransition`.
    static var rise: RiseTransition { RiseTransition() }
}

extension Transition where Self == ScaleFadeTransition {
    /// See `ScaleFadeTransition`.
    static func scaleFade(_ scale: CGFloat = 0.5, anchor: UnitPoint = .center) -> ScaleFadeTransition {
        ScaleFadeTransition(scale: scale, anchor: anchor)
    }
}
