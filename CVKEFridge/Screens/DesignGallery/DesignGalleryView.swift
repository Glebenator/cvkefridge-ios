#if DEBUG
import SwiftUI

/// The design gallery of the debug build: each token and each component of `Design/`, in one screen that scrolls.
/// The app shows it when it starts with the argument `-gallery`. The text here is not in the string catalog.
///
/// Arguments for screenshots:
/// - `-gallerySection 7` scrolls to the group with this number. The first group is 0.
/// - `-galleryOffset 1200` scrolls to this distance from the top, or from the top of the group of `-gallerySection`.
/// - `-galleryBar YES` shows the bottom action bar.
/// - `-galleryNotice done` (or `deleted`, `information`, `problem`) shows a floating message.
struct DesignGalleryView: View {
    @State private var position = ScrollPosition(edge: .top)
    @State private var currentOffset: CGFloat = 0
    @State private var showsBar = UserDefaults.standard.bool(forKey: "galleryBar")
    @State private var notice: NoticeKind? = DesignGalleryView.noticeArgument()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s10) {
                    GallerySection(0, "Home, as an example") { GalleryHomeSample() }
                    GallerySection(1, "Lists, as an example") { GalleryListSample() }
                    GallerySection(2, "Colours") { GalleryColours() }
                    GallerySection(3, "Text styles") { GalleryTypography() }
                    GallerySection(4, "Spacing and corners") { GalleryMetrics() }
                    GallerySection(5, "Brand") { GalleryBrand() }
                    GallerySection(6, "Icons") { GalleryIcons() }
                    GallerySection(7, "Tiles and cards") { GalleryTilesAndCards() }
                    GallerySection(8, "Buttons") { GalleryButtons() }
                    GallerySection(9, "Chips and status") { GalleryChips() }
                    GallerySection(10, "States") { GalleryStates() }
                    GallerySection(11, "Liquid Glass controls") {
                        GalleryGlass(showsBar: $showsBar, notice: $notice)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, Space.screenMargin)
                .padding(.vertical, Space.s6)
                .contentWidth()
            }
            .scrollPosition($position)
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, new in
                currentOffset = new
            }
            .background(Palette.surface.ignoresSafeArea())
            .navigationTitle("Design gallery")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottom) {
                if let notice {
                    GalleryNotice(kind: notice) { self.notice = nil }
                        .padding(.horizontal, Space.screenMargin)
                        .padding(.bottom, Space.s3)
                        .transition(.rise)
                }
            }
            .motion(notice == nil ? Motion.exit : Motion.enter, value: notice)
            .haptic(trigger: notice) { _, new in new?.haptic }
            .modifier(GalleryBar(shown: showsBar))
        }
        .task {
            let defaults = UserDefaults.standard
            let offset = defaults.double(forKey: "galleryOffset")
            guard defaults.object(forKey: "gallerySection") != nil else {
                position.scrollTo(y: offset)
                return
            }
            // The grids above a group get their height when they come on the screen, so the first scroll can stop
            // at the wrong place. The second scroll corrects it.
            for _ in 0 ..< 2 {
                position.scrollTo(id: defaults.integer(forKey: "gallerySection"), anchor: .top)
                try? await Task.sleep(for: .milliseconds(250))
            }
            if offset > 0 {
                position.scrollTo(y: currentOffset + offset)
            }
        }
    }

    private static func noticeArgument() -> NoticeKind? {
        switch UserDefaults.standard.string(forKey: "galleryNotice") {
        case "done": .done
        case "deleted": .deleted
        case "information": .information
        case "problem": .problem
        default: nil
        }
    }
}

/// A group of the gallery, with its title.
struct GallerySection<Content: View>: View {
    private let number: Int
    private let title: String
    private let content: Content

    init(_ number: Int, _ title: String, @ViewBuilder content: () -> Content) {
        self.number = number
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            VStack(alignment: .leading, spacing: Space.s2) {
                Text(verbatim: title)
                    .font(Typography.label.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.primary)
                    .accessibilityAddTraits(.isHeader)
                Hairline()
            }
            content
        }
        .id(number)
    }
}

/// A part of a group, with a small name above it.
struct GalleryItem<Content: View>: View {
    private let name: String
    private let content: Content

    init(_ name: String, @ViewBuilder content: () -> Content) {
        self.name = name
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text(verbatim: name)
                .font(Typography.caption.monospaced())
                .foregroundStyle(Palette.onSurfaceVariant)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The floating message of the gallery. Each kind has an example text.
private struct GalleryNotice: View {
    let kind: NoticeKind
    let dismiss: () -> Void

    var body: some View {
        Group {
            switch kind {
            case .done:
                NoticeCard("Chicken thighs now expires on Nov 20, 2026", kind: .done, actionTitle: "Undo", action: dismiss)
            case .deleted:
                NoticeCard("Greek yoghurt deleted", kind: .deleted, actionTitle: "Undo", action: dismiss)
            case .information:
                NoticeCard("Reminders are on", kind: .information)
            case .problem:
                NoticeCard("The change was not saved. The phone has no free space.", kind: .problem, actionTitle: "Try again", action: dismiss)
            }
        }
        .swipeToDismiss(onDismiss: dismiss)
    }
}

/// Puts the bottom action bar of a form on the gallery.
private struct GalleryBar: ViewModifier {
    let shown: Bool

    func body(content: Content) -> some View {
        if shown {
            content.bottomActionBar {
                Button("Save and add another") {}
                    .buttonStyle(.floatingSecondary)
                Button("Save") {}
                    .buttonStyle(.floatingPrimary)
            }
        } else {
            content
        }
    }
}

#Preview {
    DesignGalleryView()
        .tint(Palette.primary)
}
#endif
