import SwiftUI

extension View {
    /// Makes the content of a scroll view that scrolls sideways fade out over the last `width` points, at each side
    /// where the row continues. A side with no more content has no fade. Put it on the `ScrollView`.
    ///
    /// ```swift
    /// ScrollView(.horizontal) { HStack { … }.padding(.horizontal, Space.screenMargin) }
    ///     .scrollIndicators(.hidden)
    ///     .fadingEdges()
    /// ```
    ///
    /// The fade goes to transparent, so it is correct on each background.
    func fadingEdges(width: CGFloat = 40) -> some View {
        modifier(FadingEdges(width: width))
    }
}

private struct FadingEdges: ViewModifier {
    let width: CGFloat

    /// The sides of the screen where the row continues.
    private struct Continues: Equatable {
        var left = false
        var right = false
    }

    @State private var continues = Continues()

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Continues.self) { geometry in
                let left = geometry.contentOffset.x + geometry.contentInsets.leading
                let right = geometry.contentSize.width + geometry.contentInsets.trailing
                    - geometry.contentOffset.x - geometry.containerSize.width
                return Continues(left: left > 1, right: right > 1)
            } action: { _, new in
                continues = new
            }
            .mask {
                HStack(spacing: 0) {
                    edge(visible: continues.left, from: .leading)
                    Rectangle()
                    edge(visible: continues.right, from: .trailing)
                }
                // The scroll offset is a distance from the left side in each layout direction.
                .environment(\.layoutDirection, .leftToRight)
                .animation(Motion.exit, value: continues)
            }
    }

    /// The mask of one side: a fade from transparent at the `start` side when the row continues there.
    private func edge(visible: Bool, from start: UnitPoint) -> some View {
        LinearGradient(
            colors: [.black.opacity(visible ? 0 : 1), .black],
            startPoint: start,
            endPoint: start == .leading ? .trailing : .leading
        )
        .frame(width: width)
    }
}
