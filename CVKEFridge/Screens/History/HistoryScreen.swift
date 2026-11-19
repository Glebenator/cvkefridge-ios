import CVKEFridgeFeatures
import SwiftUI

/// History, the third tab: what was used and what was thrown away, the newest first, with a header for each day. It is
/// the port of `ui/HistoryScreen.kt` of the Android app.
///
/// Contract:
/// - The screen is the first screen of the navigation stack of the History tab. It sets its navigation title, and it
///   does not make a `NavigationStack`.
/// - `content.history` has all values, calculated off the main actor: `items(_:)` gives the rows for a
///   `HistoryFilter` (day headers and entries), and `summary(_:)` gives the summary of a `HistoryPeriod`.
/// - Words: `Wording.day(_:date:)` for a day header, `Outcome.label`, `HistoryFilter.label`, `HistoryPeriod.label`,
///   and `Wording.quantity(_:unit:)`.
/// - A tap on an entry calls `navigator.open(.food(productId:))`.
/// - "Add again" calls `navigator.present(.addFood(productId: line.productId, again: true))`.
///
/// The screen, from the top:
/// - The sample banner, when the content is the sample of the debug build.
/// - The summary of a period (`HistorySummaryCard`).
/// - The segmented control All, Used, Thrown away. It is the header of the list, so it stays below the navigation bar
///   while the list scrolls.
/// - The list: for each day its header and its entries (`HistoryEntryRow`). The list is lazy, and each row only reads
///   values that the model calculated, so a history of thousands of entries scrolls smoothly.
///
/// With no history, the screen says so and says when entries come. A filter with no entry says "Nothing used yet" or
/// "Nothing thrown away yet". While the change log loads, the screen shows the spinner. When the log cannot be read,
/// it says so and has "Try again". The filter and the period stay when the system stops the app in the background.
struct HistoryScreen: View {
    @Environment(FridgeModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @SceneStorage("history.filter") private var filter = HistoryFilter.all
    @SceneStorage("history.period") private var period = HistoryPeriod.thisMonth
    /// The space at each side of the content on a wide screen, so that the content is not wider than
    /// `Metrics.contentMaxWidth`.
    @State private var sideSpace: CGFloat = 0

    var body: some View {
        List {
            switch model.state {
            case .loading:
                LoadingView(style: .plain)
                    .accessibilityIdentifier("loading")
                    .historyRow()
            case .failed:
                ErrorStateView(Wording.loadFailed) { model.load() }
                    .accessibilityIdentifier("load_failed")
                    .historyRow()
            case .ready(let content):
                ready(content)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Palette.surface.ignoresSafeArea())
        .contentMargins(.horizontal, sideSpace, for: .scrollContent)
        .onGeometryChange(for: CGFloat.self) { geometry in
            max((geometry.size.width - Metrics.contentMaxWidth) / 2, 0).rounded()
        } action: { space in
            sideSpace = space
        }
        .navigationTitle("History")
        .accessibilityIdentifier("history_screen")
    }

    @ViewBuilder
    private func ready(_ content: FridgeContent) -> some View {
        let history = content.history
        let sample = content.overview.sample
        if history.lines.isEmpty {
            if sample {
                SampleBanner()
                    .historyRow(top: Space.s2)
            }
            EmptyStateView(
                "Nothing used or thrown away yet",
                message: "When you record food as used or as thrown away, it shows here."
            )
            .accessibilityIdentifier("history_empty")
            .historyRow()
        } else {
            Section {
                if sample {
                    SampleBanner()
                        .historyRow(top: Space.s2, bottom: 0)
                }
                HistorySummaryCard(summary: history.summary(period), period: animatedPeriod)
                    .historyRow(top: Space.s3, bottom: 0)
            }
            let items = history.items(filter)
            Section {
                if items.isEmpty {
                    ListMessage(filter == .used ? "Nothing used yet" : "Nothing thrown away yet")
                        .accessibilityIdentifier("history_no_match")
                        .historyRow()
                }
                ForEach(items, id: \.key) { item in
                    switch item {
                    case .day(let date, let name):
                        HistoryDayHeader(date: date, name: name)
                            .historyRow()
                    case .entry(let line, let day):
                        HistoryEntryRow(line: line, day: day)
                            .historyRow(trailing: Space.s1)
                    }
                }
            } header: {
                HistoryFilterControl(filter: animatedFilter)
            }
        }
    }

    /// The filter. A change moves the rows with `Motion.list`. When the filter shows no entry, VoiceOver says so.
    private var animatedFilter: Binding<HistoryFilter> {
        Binding(
            get: { filter },
            set: { new in
                withMotion(Motion.list, reduceMotion: reduceMotion) { filter = new }
                if new != .all, model.content?.history.items(new).isEmpty == true {
                    let text = new == .used
                        ? String(localized: "Nothing used yet")
                        : String(localized: "Nothing thrown away yet")
                    AccessibilityNotification.Announcement(text).post()
                }
            }
        )
    }

    /// The period of the summary. The numbers change with `Motion.selection`.
    private var animatedPeriod: Binding<HistoryPeriod> {
        Binding(
            get: { period },
            set: { new in withMotion(Motion.selection, reduceMotion: reduceMotion) { period = new } }
        )
    }
}

/// The segmented control that shows all entries, the used food, or the thrown-away food. It is the header of the list
/// section, so it stays at the top while the list scrolls.
private struct HistoryFilterControl: View {
    @Binding var filter: HistoryFilter

    var body: some View {
        Picker("Filter", selection: $filter) {
            ForEach(HistoryFilter.allCases, id: \.self) { option in
                Text(verbatim: option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .haptic(.selection, trigger: filter)
        .accessibilityIdentifier("history_filter")
        .padding(.horizontal, Space.screenMargin)
        .padding(.top, Space.s3)
        .padding(.bottom, Space.s2)
        // The rows scroll below the control. The fill of the screen, with a short fade at its top and below it, keeps
        // the rows out of the way, as the scroll edge of the navigation bar does. A plain list header has no fill of
        // its own. The top fade is in the top padding, so it does not cover the summary above the control.
        .background(alignment: .bottom) {
            VStack(spacing: 0) {
                LinearGradient(colors: [Palette.surface.opacity(0), Palette.surface], startPoint: .top, endPoint: .bottom)
                    .frame(height: Space.s3)
                Palette.surface
            }
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [Palette.surface, Palette.surface.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: Space.s3)
                    .offset(y: Space.s3)
            }
            .accessibilityHidden(true)
        }
        .listRowInsets(EdgeInsets())
    }
}

private extension View {
    /// A row of History: the margins of the screen, no fill, and no separator.
    func historyRow(top: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = Space.screenMargin) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: Space.screenMargin, bottom: bottom, trailing: trailing))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
