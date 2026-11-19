import CVKEFridgeFeatures
import Testing

/// The notification access from what iOS says. The Android test `NotificationAccessTest` has the same cases for the
/// values of Android. The case "before Android 13" has no iOS form: iOS always asks for the permission.
struct NotificationAccessTests {
    private func access(
        _ authorization: NotificationAuthorization = .authorized,
        shownSomewhere: Bool = true
    ) -> NotificationAccess {
        NotificationAccess.of(authorization: authorization, shownSomewhere: shownSomewhere)
    }

    @Test func theAppAsksExplainsAndThenSendsToTheSettings() {
        // iOS shows the question one time. After a refusal, only the Settings app can turn notifications on.
        #expect(access(.notDetermined, shownSomewhere: false) == .ask)
        #expect(access(.denied, shownSomewhere: false) == .blocked)
        #expect(access() == .allowed)
        #expect(access(.provisional) == .allowed)
        #expect(access(.ephemeral) == .allowed)
    }

    @Test func theAlertsCanBeOffAlone() {
        #expect(access(shownSomewhere: false) == .alertsOff)
        #expect(access(.provisional, shownSomewhere: false) == .alertsOff)
        // The permission of the whole app comes first.
        #expect(access(.denied, shownSomewhere: false) == .blocked)
        #expect(access(.denied, shownSomewhere: true) == .blocked)
    }
}
