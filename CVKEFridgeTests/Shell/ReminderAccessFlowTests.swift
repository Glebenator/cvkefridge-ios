import CVKEFridgeFeatures
import Testing
@testable import CVKEFridge

/// The steps that turn reminders on with the notification permission of iOS, for the switch of Settings and the offer
/// on Home.
struct ReminderAccessFlowTests {
    @Test func withNotificationsAllowedRemindersGoOnAtOnce() {
        var flow = ReminderAccessFlow()
        #expect(flow.turnOn(access: .allowed) == .turnOn)
        #expect(flow.dialog == nil)
    }

    @Test func withNoAccessYetNothingOccurs() {
        var flow = ReminderAccessFlow()
        #expect(flow.turnOn(access: nil) == .none)
        #expect(flow == ReminderAccessFlow())
    }

    @Test func theExplanationComesBeforeTheQuestionOfIOS() {
        var flow = ReminderAccessFlow()
        #expect(flow.turnOn(access: .ask) == .none)
        #expect(flow.dialog == .explain)

        #expect(flow.continueToSystem() == .askSystem)
        #expect(flow.dialog == nil)
        #expect(flow.asking)
        // A second "Continue" while iOS asks does nothing.
        #expect(flow.continueToSystem() == .none)

        #expect(flow.systemAnswered(.allowed) == .turnOn)
        #expect(!flow.asking)
    }

    @Test func aNoToTheQuestionOfIOSIsDeclined() {
        var flow = ReminderAccessFlow()
        _ = flow.turnOn(access: .ask)
        _ = flow.continueToSystem()
        #expect(flow.systemAnswered(.blocked) == .declined)
    }

    @Test func notNowClosesTheExplanationAndChangesNothing() {
        var flow = ReminderAccessFlow()
        _ = flow.turnOn(access: .ask)
        flow.dismiss()
        #expect(flow == ReminderAccessFlow())
    }

    @Test func withNotificationsOffTheSettingsAppTurnsThemOn() {
        var flow = ReminderAccessFlow()
        #expect(flow.turnOn(access: .alertsOff) == .none)
        #expect(flow.dialog == .openSettings(.alertsOff))
        #expect(flow.openSettings() == .openSettings)
        #expect(flow.dialog == nil)
        #expect(flow.inSettings)

        #expect(flow.returned(access: .allowed) == .turnOn)
        #expect(!flow.inSettings)
    }

    @Test func aReturnWithNotificationsStillOffForgetsTheVisit() {
        var flow = ReminderAccessFlow()
        _ = flow.turnOn(access: .blocked)
        _ = flow.openSettings()
        #expect(flow.returned(access: .blocked) == .none)
        #expect(!flow.inSettings)
        // A later change of the access, for example from the switch of Settings, does not turn reminders on here.
        #expect(flow.returned(access: .allowed) == .none)
    }

    @Test func aReturnWithNoVisitDoesNothing() {
        var flow = ReminderAccessFlow()
        #expect(flow.returned(access: .allowed) == .none)
    }

    @Test func theCardOfAnAccessProblemExplainsOrOpensTheSettingsApp() {
        var flow = ReminderAccessFlow()
        #expect(flow.fix(.ask) == .none)
        #expect(flow.dialog == .explain)
        flow.dismiss()

        #expect(flow.fix(.alertsOff) == .openSettings)
        #expect(flow.inSettings)
        #expect(flow.dialog == nil)
        #expect(flow.returned(access: .allowed) == .turnOn)

        #expect(flow.fix(.allowed) == .none)
        #expect(flow == ReminderAccessFlow())
    }
}
