import CVKEFridgeFeatures
import Testing

@Test func theFeaturesTargetSeesTheCore() {
    #expect(AppVersion(name: "1.0", build: 2).label == "1.0 (2)")
}
