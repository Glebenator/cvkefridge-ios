#if DEBUG
import CVKEFridgeCore
import SwiftUI

/// The tiles and the cards.
struct GalleryTilesAndCards: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s5) {
            GalleryItem("IconTile: standard, accent, neutral, expiring, expired, photo") {
                FlowLayout(spacing: Space.s3) {
                    IconTile(.produce)
                    IconTile(.bell, tone: .accent)
                    IconTile(.info, tone: .neutral)
                    IconTile(.clock, tone: .expiring)
                    IconTile(.alert, tone: .expired)
                    IconTile(.produce, photo: Image(systemName: "photo.fill"))
                    IconTile(.dairy, size: 72)
                }
            }
            GalleryItem("SurfaceCard: low, standard, highest") {
                VStack(spacing: Space.cardGap) {
                    SurfaceCard { Text(verbatim: "CardTone.low: a card in a list") }
                    SurfaceCard(.standard) { Text(verbatim: "CardTone.standard: a large card") }
                    SurfaceCard(.highest) { Text(verbatim: "CardTone.highest: a part on a card") }
                }
                .font(Typography.secondary)
            }
            GalleryItem("SurfaceCard: positive, expiring, expired") {
                VStack(spacing: Space.cardGap) {
                    SurfaceCard(.positive) {
                        HStack(spacing: Space.s4) {
                            Image(icon: .done, filled: true)
                                .font(.title)
                            VStack(alignment: .leading) {
                                Text(verbatim: "All fresh").font(Typography.cardTitle)
                                Text(verbatim: "No food expires in the next 2 days.").font(Typography.secondary)
                            }
                        }
                    }
                    SurfaceCard(.expiring) {
                        StatusLabel(verbatim: "Expires tomorrow", freshness: .expiring, showsIcon: true, tinted: false)
                    }
                    SurfaceCard(.expired) {
                        StatusLabel(verbatim: "Expired yesterday", freshness: .expired, showsIcon: true, tinted: false)
                    }
                }
            }
            GalleryItem("StatTile in AdaptiveStack; disabled") {
                VStack(spacing: Space.s2) {
                    AdaptiveStack {
                        StatTile("Expiring", value: "3", kind: .expiring) {}
                        StatTile("Expired", value: "1", kind: .expired) {}
                    }
                    AdaptiveStack {
                        StatTile("Expiring", value: "–", kind: .expiring) {}
                        StatTile("Expired", value: "–", kind: .expired) {}
                    }
                    .disabled(true)
                }
            }
            GalleryItem("SampleBanner") { SampleBanner() }
            GalleryItem("SectionHeader: section, group") {
                VStack(alignment: .leading, spacing: Space.s2) {
                    SectionHeader("Needs attention", actionTitle: "View all") {}
                    SectionHeader("2 batches")
                    SectionHeader(verbatim: "Sunday, November 8, 2026", style: .group)
                }
            }
        }
    }
}

/// The button styles.
struct GalleryButtons: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s5) {
            GalleryItem(".primary, .secondary, .quiet") {
                FlowLayout(spacing: Space.s3) {
                    Button("Add again", systemImage: AppIcon.add.symbol) {}
                        .buttonStyle(.primary)
                    Button("Add a batch", systemImage: AppIcon.add.symbol) {}
                        .buttonStyle(.secondary)
                    Button("View all") {}
                        .buttonStyle(.quiet)
                }
            }
            GalleryItem(".primary(.compact), .secondary(.compact)") {
                FlowLayout(spacing: Space.s3) {
                    Button("Try again") {}
                        .buttonStyle(.primary(.compact))
                    Button("Scan a barcode", systemImage: AppIcon.scan.symbol) {}
                        .buttonStyle(.secondary(.compact))
                    Button("Add by hand", systemImage: AppIcon.addByHand.symbol) {}
                        .buttonStyle(.secondary(.compact))
                }
            }
            GalleryItem("fullWidth, destructive, disabled") {
                VStack(spacing: Space.s2) {
                    Button("Save changes") {}
                        .buttonStyle(.primary(fullWidth: true))
                    Button("Thrown away", systemImage: AppIcon.delete.symbol) {}
                        .buttonStyle(.secondary(fullWidth: true))
                    Button("Delete", role: .destructive) {}
                        .buttonStyle(.primary(fullWidth: true))
                    Button("Delete", role: .destructive) {}
                        .buttonStyle(.secondary(fullWidth: true))
                    Button("Save changes") {}
                        .buttonStyle(.primary(fullWidth: true))
                        .disabled(true)
                }
            }
        }
    }
}

/// The chips and the status labels.
struct GalleryChips: View {
    @State private var showsExpiring = true
    @State private var showsExpired = false
    @State private var category: CVKEFridgeCore.Category?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s5) {
            GalleryItem("MenuChip, FilterChip in FlowLayout") {
                FlowLayout {
                    MenuChip("Category", selection: category?.rawValue.capitalized) {
                        Picker("Category", selection: $category) {
                            Text(verbatim: "All categories").tag(CVKEFridgeCore.Category?.none)
                            ForEach(CVKEFridgeCore.Category.allCases, id: \.self) { category in
                                Label(verbatim: category.rawValue.capitalized, icon: category.icon)
                                    .tag(CVKEFridgeCore.Category?.some(category))
                            }
                        }
                    }
                    FilterChip("Expiring", count: "3", isOn: $showsExpiring)
                    FilterChip("Expired", count: "1", isOn: $showsExpired)
                }
            }
            GalleryItem("StatusLabel, Freshness.color, Freshness.icon") {
                VStack(alignment: .leading, spacing: Space.s2) {
                    StatusLabel(verbatim: "Expires in 8d", freshness: .fresh, showsIcon: true)
                    StatusLabel(verbatim: "Expires tomorrow", freshness: .expiring, showsIcon: true)
                    StatusLabel(verbatim: "Expired yesterday", freshness: .expired, showsIcon: true)
                    StatusLabel(verbatim: "No expiry date", freshness: .noExpiryDate, showsIcon: true)
                    StatusLabel(verbatim: "Expires in 3d, estimated", freshness: .fresh)
                }
            }
        }
    }
}

/// The empty state, the loading state, and the failed state.
struct GalleryStates: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s5) {
            GalleryItem("EmptyStateView") {
                EmptyStateView("No food yet", message: "Add the food that you have at home.") {
                    Button("Scan a barcode", systemImage: AppIcon.scan.symbol) {}
                        .buttonStyle(.secondary(.compact))
                    Button("Add by hand", systemImage: AppIcon.addByHand.symbol) {}
                        .buttonStyle(.secondary(.compact))
                }
            }
            GalleryItem("LoadingView: card, plain") {
                VStack(spacing: Space.s2) {
                    LoadingView()
                    LoadingView("Looking up the product…", style: .plain)
                }
            }
            GalleryItem("ErrorStateView") {
                ErrorStateView("The food could not be read from this phone. Try again.") {}
            }
            GalleryItem("ListMessage") {
                ListMessage("No food for these filters") {
                    Button("Clear the filters") {}
                        .buttonStyle(.quiet)
                }
            }
        }
    }
}

/// The Liquid Glass controls, above a part that has colour, so that the glass shows.
struct GalleryGlass: View {
    @Binding var showsBar: Bool
    @Binding var notice: NoticeKind?

    @State private var area = "all"
    @State private var lightOn = false

    private let areas = [
        GlassSegment(id: "all", title: "All"),
        GlassSegment(id: "fridge", title: "Fridge"),
        GlassSegment(id: "freezer", title: "Freezer"),
        GlassSegment(id: "pantry", title: "Pantry"),
        GlassSegment(id: "cellar", title: "Cellar"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s5) {
            GalleryItem("GlassSegmentedRow") {
                GlassSegmentedRow(areas, selection: $area, label: "Storage area")
                    .padding(.horizontal, -Space.screenMargin)
            }
            GalleryItem("GlassCapsuleBar, GlassBarButton, GlassIconButton") {
                FlowLayout(spacing: Space.s4) {
                    GlassCapsuleBar {
                        GlassBarButton(lightOn ? .flashlightOff : .flashlightOn, label: "Light") { lightOn.toggle() }
                        GlassBarButton(.keyboard, label: "Type the barcode") {}
                        GlassBarButton(.close, label: "Close") {}
                    }
                    GlassIconButton(.scan, label: "Scan a barcode") {}
                    GlassIconButton(.add, label: "Add food", prominent: true) {}
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Space.s4)
                .background { glassBackdrop }
            }
            GalleryItem("NoticeCard: done, deleted, information, problem") {
                VStack(spacing: Space.s3) {
                    NoticeCard("Chicken thighs now expires on Nov 20, 2026", kind: .done, actionTitle: "Undo") {}
                    NoticeCard("Greek yoghurt deleted", kind: .deleted, actionTitle: "Undo") {}
                    NoticeCard("Reminders are on", kind: .information)
                    NoticeCard("The change was not saved. The phone has no free space.", kind: .problem, actionTitle: "Try again") {}
                }
                .frame(maxWidth: .infinity)
                .padding(Space.s4)
                .background { glassBackdrop }
            }
            GalleryItem("floatingGlass(in:), swipeToDismiss, .rise: show a message") {
                FlowLayout {
                    ForEach(NoticeKind.allCases, id: \.self) { kind in
                        Button(String(describing: kind).capitalized) { notice = kind }
                            .buttonStyle(.secondary(.compact))
                    }
                }
            }
            GalleryItem("BottomActionBar, bottomActionBar") {
                Toggle("Show the bottom action bar", isOn: $showsBar)
                    .font(Typography.body)
            }
        }
    }

    /// A part with colour behind the glass controls.
    private var glassBackdrop: some View {
        ZStack {
            BrandGradient()
            LinearGradient(colors: [Palette.surface.opacity(0.2), Palette.surface.opacity(0.75)], startPoint: .top, endPoint: .bottom)
        }
        .clipShape(Radius.shape(Radius.large))
    }
}
#endif
