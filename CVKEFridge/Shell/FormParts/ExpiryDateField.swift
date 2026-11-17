import CVKEFridgeFeatures
import SwiftUI

/// The expiry date of a form, as rows of a `Form`. The first row shows the date and says if it is an estimated date.
/// A tap opens the calendar for the printed date. The rows below select no expiry date, or the estimated date again.
/// Such a row is there only when it changes the date. It takes the place of `ExpiryField` of `ui/FormParts.kt` of the
/// Android app.
///
/// The source of the date changes only when the person selects a different date in the calendar. "Done" with the
/// same date keeps an estimated date an estimated date, and a chosen date a chosen date. In the Android app, "OK"
/// always makes the date a printed date.
///
/// ```swift
/// Section {
///     ExpiryDateField(input: $form.expiry, expiry: expiry, suggested: suggested, estimateHint: hint, today: content.today)
/// }
/// ```
struct ExpiryDateField: View {
    @Binding private var input: ExpiryInput
    private let expiry: ExpiryDate?
    private let suggested: ExpiryDate?
    private let estimateHint: String?
    private let today: CalendarDate
    private let earliest: CalendarDate?

    @State private var picking = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// - Parameters:
    ///   - input: What the person selected for the expiry date.
    ///   - expiry: The expiry date that the form saves now (`ExpiryChoice.expiry`).
    ///   - suggested: The estimated date, or nil when there is no estimate.
    ///   - estimateHint: Where the estimate comes from (`Wording.estimateHint`), or nil.
    ///   - today: The date of the device. The calendar starts there when the form has no date.
    ///   - earliest: The first date that the person can select, or nil for no limit.
    init(
        input: Binding<ExpiryInput>,
        expiry: ExpiryDate?,
        suggested: ExpiryDate?,
        estimateHint: String?,
        today: CalendarDate,
        earliest: CalendarDate? = nil
    ) {
        _input = input
        self.expiry = expiry
        self.suggested = suggested
        self.estimateHint = estimateHint
        self.today = today
        self.earliest = earliest
    }

    var body: some View {
        // The words below the field are a part of the button. The row is one element for VoiceOver and for a tap:
        // with the largest text, the words are most of the row, and a tap on them opens the calendar also.
        Button {
            picking = true
        } label: {
            VStack(alignment: .leading, spacing: Space.s1 + 2) {
                LabeledContent {
                    HStack(spacing: Space.s2) {
                        Text(verbatim: value)
                            // With an accessibility text size, the value is below the name of the field, and
                            // its lines start at the leading edge as the name does.
                            .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
                        Image(icon: .calendar)
                            .foregroundStyle(Palette.primary)
                            .accessibilityHidden(true)
                    }
                } label: {
                    Text("Expiry date")
                }
                Text(verbatim: help)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .multilineTextAlignment(.leading)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(verbatim: help))
        .accessibilityIdentifier("field_expiry")
        .sheet(isPresented: $picking) {
            DatePickerSheet(
                "Expiry date",
                initial: expiry?.date ?? max(today, earliest ?? today),
                earliest: earliest
            ) { date in
                // The same date keeps its source.
                if date != expiry?.date {
                    input = .printed(date)
                }
            }
        }
        if expiry != nil {
            Button("No expiry date") { input = .noExpiryDate }
                .accessibilityIdentifier("expiry_none")
        }
        if input != .suggested, suggested != nil {
            Button("Use the estimated date") { input = .suggested }
                .accessibilityIdentifier("expiry_suggested")
        }
    }

    /// The text of the field: the date, the date with ", estimated", or "No expiry date".
    private var value: String {
        guard let expiry else {
            return String(localized: "No expiry date")
        }
        let date = Wording.date(expiry.date)
        return expiry.source == .estimated ? Wording.estimated(date) : date
    }

    /// The text below the field: where the date comes from, and what a tap does.
    private var help: String {
        switch expiry?.source {
        case .estimated:
            let source = estimateHint ?? String(localized: "The app suggested this date.")
            return String(localized: "\(source) Select the field to enter the printed date.", comment: "The value says where an estimated date comes from.")
        case .chosen:
            return String(localized: "Your date: you said that the food is still good. Select the field to enter a printed date.")
        case .printed:
            return String(localized: "Printed date, from the package.")
        case nil:
            return input == .noExpiryDate
                ? String(localized: "This batch has no expiry date. Select the field to enter the printed date.")
                : String(localized: "The app has no estimate for this food here. Select the field to enter the printed date.")
        }
    }
}

/// A date of a form that always has a value, as a row of a `Form` with the compact date control of the system: the
/// date added of a batch.
///
/// ```swift
/// CalendarDateField("Date added", date: $form.dateAdded, latest: content.today)
/// ```
struct CalendarDateField: View {
    private let label: LocalizedStringKey
    @Binding private var date: CalendarDate
    private let earliest: CalendarDate?
    private let latest: CalendarDate?

    /// - Parameters:
    ///   - earliest: The first date that the person can select, or nil for no limit.
    ///   - latest: The last date that the person can select, or nil for no limit.
    init(_ label: LocalizedStringKey, date: Binding<CalendarDate>, earliest: CalendarDate? = nil, latest: CalendarDate? = nil) {
        self.label = label
        _date = date
        self.earliest = earliest
        self.latest = latest
    }

    var body: some View {
        DatePicker(selection: instant, in: CalendarDateRange.range(earliest: earliest, latest: latest), displayedComponents: .date) {
            Text(label)
        }
        .calendarDates()
    }

    private var instant: Binding<Date> {
        Binding(
            get: { Wording.instant(of: date) },
            set: { new in
                if let picked = Wording.calendarDate(of: new) {
                    date = picked
                }
            }
        )
    }
}

/// The calendar of the system in a sheet, for one date. "Done" gives the date to `onConfirm` and closes the sheet.
/// The close button closes the sheet with no change.
///
/// ```swift
/// .sheet(isPresented: $picking) {
///     DatePickerSheet("Other date", initial: first, earliest: first) { date in perform(.moveExpiry(batchId: id, date: date)) }
/// }
/// ```
///
/// For "Other date" of "Still good?", give the day after today or after the expiry date as `earliest`, so that the
/// person cannot select a date that is not later.
struct DatePickerSheet: View {
    private let title: LocalizedStringKey
    private let earliest: CalendarDate?
    private let latest: CalendarDate?
    private let onConfirm: (CalendarDate) -> Void

    @State private var selection: Date
    @Environment(\.dismiss) private var dismiss

    /// - Parameters:
    ///   - initial: The date that is selected at the start. A date out of the limits starts at the nearest limit.
    ///   - earliest: The first date that the person can select, or nil for no limit.
    ///   - latest: The last date that the person can select, or nil for no limit.
    init(
        _ title: LocalizedStringKey,
        initial: CalendarDate,
        earliest: CalendarDate? = nil,
        latest: CalendarDate? = nil,
        onConfirm: @escaping (CalendarDate) -> Void
    ) {
        self.title = title
        self.earliest = earliest
        self.latest = latest
        self.onConfirm = onConfirm
        var start = initial
        if let earliest, start < earliest {
            start = earliest
        }
        if let latest, start > latest {
            start = latest
        }
        _selection = State(initialValue: Wording.instant(of: start))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                DatePicker(
                    selection: $selection,
                    in: CalendarDateRange.range(earliest: earliest, latest: latest),
                    displayedComponents: .date
                ) {
                    Text(title)
                }
                .datePickerStyle(.graphical)
                .calendarDates()
                .padding(.horizontal, Space.screenMargin)
                .contentWidth()
                .accessibilityIdentifier("date_picker")
            }
            .background(Palette.surface.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        if let date = Wording.calendarDate(of: selection) {
                            // The limits can change while the calendar is open, for example at midnight. A date
                            // out of the limits goes to the nearest limit, and the person confirms again.
                            if let earliest, date < earliest {
                                selection = Wording.instant(of: earliest)
                                return
                            }
                            if let latest, date > latest {
                                selection = Wording.instant(of: latest)
                                return
                            }
                            onConfirm(date)
                        }
                        dismiss()
                    }
                    .accessibilityIdentifier("date_confirm")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tint(Palette.primary)
    }
}

/// The limits of a date control, as instants.
private enum CalendarDateRange {
    /// The dates that the core has: the years 1 to 9999.
    private static let first = CalendarDate(year: 1, month: 1, day: 1)
    private static let last = CalendarDate(year: 9999, month: 12, day: 31)

    static func range(earliest: CalendarDate?, latest: CalendarDate?) -> ClosedRange<Date> {
        let start = Wording.instant(of: earliest ?? first ?? .init(year: 2000, month: 1, day: 1)!)
        let end = Wording.instant(of: latest ?? last ?? .init(year: 2100, month: 1, day: 1)!)
        return start...max(start, end)
    }
}

private extension View {
    /// Makes a date control read and write instants as calendar dates with no time zone: the calendar of the person,
    /// in UTC (see `Wording.instant(of:)`).
    func calendarDates() -> some View {
        var calendar = Calendar.current
        calendar.timeZone = .gmt
        return environment(\.calendar, calendar).environment(\.timeZone, .gmt)
    }
}
