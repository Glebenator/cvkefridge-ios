import SwiftUI

/// A button with a line around it and no fill, in the shape of a capsule. It takes the place of the `OutlinedButton`
/// and of the `AssistChip` of the Android screen of a food.
///
/// The screen of a food has "Used" and "Thrown away" side by side. They have different looks, so that a person does
/// not select the wrong one: "Used" has the fill of `.secondary`, and "Thrown away" has this line. The choices of
/// "Still good?" have the small size.
///
/// ```swift
/// Button { … } label: { Label("Thrown away", icon: .delete) }.buttonStyle(.outline)
/// Button("+1 day") { … }.buttonStyle(.outline(.compact))
/// ```
///
/// It is content on a surface, not a floating control, so it is not Liquid Glass. Each button is 44 points high or
/// more.
struct OutlineButtonStyle: ButtonStyle {
    var size: AppButtonStyle.Size = .large
    /// True for a button that takes all of the width that it gets.
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        OutlineButtonBody(style: self, configuration: configuration)
    }
}

extension ButtonStyle where Self == OutlineButtonStyle {
    static var outline: OutlineButtonStyle { OutlineButtonStyle() }

    static func outline(_ size: AppButtonStyle.Size = .large, fullWidth: Bool = false) -> OutlineButtonStyle {
        OutlineButtonStyle(size: size, fullWidth: fullWidth)
    }
}

private struct OutlineButtonBody: View {
    let style: OutlineButtonStyle
    let configuration: ButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var compact: Bool { style.size == .compact }

    var body: some View {
        // The ends of a high capsule cut text that has more than one line, so large text gets round corners. A
        // rectangle with circular corners of a very large radius is a capsule.
        let wraps = dynamicTypeSize.isAccessibilitySize
        let shape = RoundedRectangle(cornerRadius: wraps ? Radius.large : 1_000, style: wraps ? .continuous : .circular)
        configuration.label
            .font(compact ? Typography.label.weight(.semibold) : .body.weight(.semibold))
            .multilineTextAlignment(.center)
            // 38% of the usual text colour for a button that is off, as the other buttons of the app.
            .foregroundStyle(isEnabled ? Palette.onSurface : Palette.onSurface.opacity(0.38))
            .padding(.horizontal, compact ? Space.s3 + 2 : Space.s5)
            .padding(.vertical, compact ? 6 : Space.s2)
            .frame(minHeight: compact ? 36 : 50)
            .frame(maxWidth: style.fullWidth ? .infinity : nil)
            .background {
                shape.fill(Palette.onSurface.opacity(configuration.isPressed ? 0.1 : 0))
            }
            .overlay {
                shape.strokeBorder(isEnabled ? Palette.outline : Palette.outline.opacity(0.38), lineWidth: 1)
            }
            // The small button is 36 points high. Its target is 44 points high.
            .frame(minHeight: Metrics.minTarget)
            .contentShape(.rect)
            .contentShape(.hoverEffect, shape)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .hoverEffect(.highlight, isEnabled: isEnabled)
    }
}
