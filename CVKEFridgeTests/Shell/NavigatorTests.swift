import CVKEFridgeFeatures
import Testing
@testable import CVKEFridge

/// The sheets of the navigator: each showing of a sheet is a presentation, and the end of a save closes only its own
/// form.
@MainActor
struct NavigatorTests {
    private let scanned = Scanned(barcode: "4006381333931", source: .notFound)

    @Test func aSaveClosesTheFormAndTheScannerBelowIt() {
        let navigator = Navigator()
        navigator.scan()
        let form = SheetRoute.addFood(scan: scanned)
        navigator.present(form)
        let id = navigator.presentations.last?.id

        navigator.finishAddFood(form, presentation: id)
        #expect(navigator.sheets.isEmpty)
    }

    @Test func saveAndScanNextClosesOnlyTheForm() {
        let navigator = Navigator()
        navigator.scan()
        let form = SheetRoute.addFood(scan: scanned)
        navigator.present(form)

        navigator.finishAddFood(form, presentation: navigator.presentations.last?.id, scanNext: true)
        #expect(navigator.sheets == [.scan()])
    }

    @Test func aSaveThatEndsAfterItsFormClosedDoesNotCloseANewScanner() {
        let navigator = Navigator()
        navigator.scan()
        let form = SheetRoute.addFood(scan: scanned)
        navigator.present(form)
        let id = navigator.presentations.last?.id
        // The person closes the form while it saves, closes the scanner, and opens a new scanner.
        navigator.dismiss(form)
        navigator.dismiss()
        navigator.scan()

        navigator.finishAddFood(form, presentation: id)
        #expect(navigator.sheets == [.scan()])
        // Also with no presentation, a form that is not open closes nothing.
        navigator.finishAddFood(form)
        #expect(navigator.sheets == [.scan()])
    }

    @Test func aSaveOfAClosedFormDoesNotCloseANewFormWithTheSameRoute() {
        let navigator = Navigator()
        let form = SheetRoute.addFood()
        navigator.present(form)
        let old = navigator.presentations.last?.id
        navigator.dismiss(form)
        navigator.present(form)

        navigator.finishAddFood(form, presentation: old)
        #expect(navigator.sheets == [form])
        #expect(navigator.presentations.last?.id != old)
    }

    @Test func onlyTheScannerDirectlyBelowTheFormCloses() {
        let navigator = Navigator()
        navigator.scan()
        navigator.present(.storageAreas)
        let form = SheetRoute.addFood()
        navigator.present(form)

        navigator.finishAddFood(form, presentation: navigator.presentations.last?.id)
        #expect(navigator.sheets == [.scan(), .storageAreas])
    }

    // MARK: A tap on a reminder

    private let attention = FoodFilter(freshness: [.expiring, .expired])

    @Test func aReminderWithNoSheetShowsMyFridgeAtOnce() {
        let navigator = Navigator()
        navigator.showAttention()
        #expect(navigator.tab == .myFridge)
        #expect(navigator.myFridgeFilter == attention)
    }

    @Test func aReminderKeepsAnOpenFormAndShowsMyFridgeWhenTheFormCloses() {
        let navigator = Navigator()
        navigator.addFood()
        navigator.showAttention()
        // The form can have changes. It stays, so that its question about the changes decides.
        #expect(navigator.sheets == [.addFood()])
        #expect(navigator.tab == .home)
        #expect(navigator.myFridgeFilter != attention)

        navigator.dismiss()
        #expect(navigator.sheets.isEmpty)
        #expect(navigator.tab == .myFridge)
        #expect(navigator.myFridgeFilter == attention)
    }

    @Test func aReminderWaitsUntilTheLastSheetCloses() {
        let navigator = Navigator()
        navigator.scan()
        let scanner = navigator.presentations[0]
        navigator.present(.addFood(scan: scanned))
        navigator.showAttention()

        // The form closes, and the scanner stays.
        navigator.dismiss()
        #expect(navigator.sheets == [.scan()])
        #expect(navigator.tab == .home)

        // The person swipes the scanner down.
        navigator.closeSheets(from: scanner)
        #expect(navigator.tab == .myFridge)
        #expect(navigator.myFridgeFilter == attention)
    }

    @Test func aScreenThatThePersonOpensFromASheetReplacesTheWaitingReminder() {
        let navigator = Navigator()
        navigator.present(.storageAreas)
        navigator.showAttention()
        navigator.open(.food(productId: "milk"))
        #expect(navigator.tab == .home)
        #expect(navigator.paths[.home] == [.food(productId: "milk")])

        // The reminder does not come later.
        navigator.present(.storageAreas)
        navigator.dismiss()
        #expect(navigator.tab == .home)
    }

    @Test func aReplacementIsANewPresentation() {
        let navigator = Navigator()
        navigator.addFood()
        let form = navigator.presentations[0]
        navigator.replaceSheet(with: .scan())

        #expect(navigator.sheets == [.scan()])
        #expect(navigator.presentations[0].id != form.id)
        // The system closed the form after the replacement: the scanner stays.
        navigator.closeSheets(from: form)
        #expect(navigator.sheets == [.scan()])
    }
}
