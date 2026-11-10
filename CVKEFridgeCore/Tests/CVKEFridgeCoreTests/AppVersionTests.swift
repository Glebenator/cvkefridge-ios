import Foundation
import Testing
@testable import CVKEFridgeCore

/// The same cases as the Android AppVersionTest.
struct AppVersionTests {
    @Test func labelShowsTheNameAndTheBuild() {
        #expect(AppVersion(name: "0.1.0", build: 1).label == "0.1.0 (1)")
    }

    @Test func labelKeepsAShortNameAndALargerBuild() {
        #expect(AppVersion(name: "1.2", build: 34).label == "1.2 (34)")
    }
}
