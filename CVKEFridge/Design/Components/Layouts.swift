import SwiftUI

/// A row that becomes a column when its parts do not fit side by side, or when the text size is an accessibility
/// size. Use it for two parts that are side by side at the default text size: two count tiles, a title and a button.
///
/// ```swift
/// AdaptiveStack(spacing: Space.s2) {
///     StatTile("Expiring", value: "3", kind: .expiring) { … }
///     StatTile("Expired", value: "1", kind: .expired) { … }
/// }
/// ```
struct AdaptiveStack<Content: View>: View {
    var horizontalAlignment: HorizontalAlignment = .leading
    var verticalAlignment: VerticalAlignment = .center
    var spacing: CGFloat = Space.s2
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            column
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: verticalAlignment, spacing: spacing) { content }
                column
            }
        }
    }

    private var column: some View {
        VStack(alignment: horizontalAlignment, spacing: spacing) { content }
    }
}

/// A row whose parts go to the next line when the row is full, as words do. Use it for chips and for the buttons of
/// an empty state, so that large text does not cut a part and the row does not scroll sideways.
struct FlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = Space.s2
    var lineSpacing: CGFloat = Space.s2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = lines(for: subviews, width: proposal.width ?? .infinity)
        let width = lines.map(\.width).max() ?? 0
        let height = lines.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(lines.count - 1, 0))
        return CGSize(width: proposal.width.map { min($0, max(width, 0)) } ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in lines(for: subviews, width: bounds.width) {
            var x = bounds.minX
            switch alignment {
            case .center: x += (bounds.width - line.width) / 2
            case .trailing: x += bounds.width - line.width
            default: break
            }
            for index in line.indices {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// The parts of each line. A part that is wider than the `width` gets the `width`, so its text wraps.
    private func lines(for subviews: Subviews, width: CGFloat) -> [Line] {
        var lines: [Line] = []
        var line = Line()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            let extended = line.indices.isEmpty ? size.width : line.width + spacing + size.width
            if !line.indices.isEmpty, extended > width {
                lines.append(line)
                line = Line(indices: [index], width: size.width, height: size.height)
            } else {
                line.indices.append(index)
                line.width = extended
                line.height = max(line.height, size.height)
            }
        }
        if !line.indices.isEmpty {
            lines.append(line)
        }
        return lines
    }
}
