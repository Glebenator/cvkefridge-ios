import CVKEFridgeFeatures
import SwiftUI

/// Home, the first tab. It takes the place of `ui/HomeScreen.kt` of the Android app, with the same contents in the
/// same order: the greeting and the title, the card of the totals, the note of the sample, the offer of reminders,
/// and the batches that need attention.
///
/// - The screen is the first screen of the navigation stack of the Home tab (`RootView` makes the stack). It sets
///   its navigation title, and it does not make a `NavigationStack`.
/// - The greeting and the large title are content, because the greeting is above the title. The navigation bar
///   shows the title when the large title is out of view, as a large title of the system does.
/// - Settings is a tab on iOS, so the bar has only the About button. About opens as a sheet.
/// - A tap on the number of expiring or expired batches shows My Fridge with that freshness. "View all" shows My
///   Fridge with no filter. A tap on a batch that needs attention opens its food.
/// - Before the inventory is loaded, the totals have the sign for "no value" and the group shows the loading line.
///   A failed load shows what failed, with "Try again".
struct HomeScreen: View {
    @Environment(FridgeModel.self) private var model
    @Environment(Navigator.self) private var navigator
    @Environment(\.scenePhase) private var scenePhase

    @State private var greeting = Wording.greeting()
    @State private var showsAbout = false
    /// True when the large title is behind the navigation bar.
    @State private var titleInBar = false

    var body: some View {
        let content = model.content
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, Space.s5)
                TotalsCard(overview: content?.overview) { freshness in
                    navigator.showMyFridge(FoodFilter(freshness: [freshness]))
                }
                if let content {
                    notes(content)
                }
                attention
                    .padding(.top, Space.sectionGap)
            }
            .padding(.horizontal, Space.screenMargin)
            .padding(.top, Space.s2)
            .padding(.bottom, Space.s8)
            .contentWidth()
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 48
        } action: { _, behind in
            titleInBar = behind
        }
        .background(Palette.surface.ignoresSafeArea())
        .navigationTitle("Your Kitchen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Your Kitchen")
                    .font(.headline)
                    .foregroundStyle(Palette.onSurface)
                    .opacity(titleInBar ? 1 : 0)
                    .motion(Motion.selection, value: titleInBar)
                    .accessibilityHidden(true)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("About", systemImage: AppIcon.info.symbol) {
                    showsAbout = true
                }
                .accessibilityHint(Text("Shows the version and the maker of the app."))
                .accessibilityIdentifier("about_button")
            }
        }
        .sheet(isPresented: $showsAbout) {
            AboutSheet()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                greeting = Wording.greeting()
            }
        }
        .accessibilityIdentifier("home_screen")
    }

    /// The greeting, and the title of the screen below it.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: greeting)
                .font(Typography.greeting)
                .foregroundStyle(Palette.onSurfaceVariant)
                .accessibilityIdentifier("home_greeting")
            Text("Your Kitchen")
                .font(Typography.screenTitle)
                .foregroundStyle(Palette.onSurface)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("home_title")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The notes below the totals: the sample, the lines of the inventory file that the app did not read, and the
    /// offer of reminders.
    @ViewBuilder
    private func notes(_ content: FridgeContent) -> some View {
        if content.overview.sample {
            SampleBanner()
                .padding(.top, Space.s4)
        }
        if content.skippedChanges > 0 {
            SkippedChangesNote(count: content.skippedChanges)
                .padding(.top, Space.s4)
        }
        ReminderOffer(overview: content.overview)
    }

    /// The group "Needs attention", or the failed load in its place.
    @ViewBuilder private var attention: some View {
        switch model.state {
        case .failed:
            ErrorStateView(Wording.loadFailed) { model.load() }
                .accessibilityIdentifier("load_failed")
        case .loading:
            AttentionSection(overview: nil)
        case .ready(let content):
            AttentionSection(overview: content.overview)
        }
    }
}

/// Says that some lines of the inventory file are not changes, so the app did not read them. The other food is on
/// the screens. The message at the start of the app says the same, but it goes away.
private struct SkippedChangesNote: View {
    let count: Int

    var body: some View {
        Label {
            Text(verbatim: NoticeText.changesNotRead(count: count).text)
                .font(Typography.secondary)
        } icon: {
            Image(icon: .alert, filled: true)
        }
        .foregroundStyle(Palette.onErrorContainer)
        .padding(.horizontal, Space.s3)
        .padding(.vertical, Space.s2 + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(Palette.errorContainer, radius: Radius.small)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("skipped_changes_note")
    }
}
