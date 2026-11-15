import CVKEFridgeFeatures
import Testing

/// One package gives one scan, and a single wrong read gives none. The Android test `ScanDebouncerTest` has the same
/// cases.
struct ScanDebouncerTests {
    @Test func aBarcodeCountsAfterTwoReadsWithinOneSecond() {
        var debouncer = ScanDebouncer()
        #expect(debouncer.read("3017620422003", now: 0) == nil)
        #expect(debouncer.read("3017620422003", now: 100) == "3017620422003")
    }

    @Test func aDifferentReadOrALateReadStartsAgain() {
        var debouncer = ScanDebouncer()
        #expect(debouncer.read("3017620422003", now: 0) == nil)
        #expect(debouncer.read("5449000000996", now: 50) == nil)
        #expect(debouncer.read("3017620422003", now: 100) == nil)
        #expect(debouncer.read("3017620422003", now: 1200) == nil)
        #expect(debouncer.read("3017620422003", now: 1300) == "3017620422003")
    }

    @Test func theSamePackageDoesNotCountAgainForThreeSeconds() {
        var debouncer = ScanDebouncer()
        _ = debouncer.read("3017620422003", now: 0)
        _ = debouncer.read("3017620422003", now: 100)
        for step in 0..<10 {
            #expect(debouncer.read("3017620422003", now: 200 + step * 250) == nil)
        }
        // Another package counts at once.
        _ = debouncer.read("5449000000996", now: 2800)
        #expect(debouncer.read("5449000000996", now: 2900) == "5449000000996")
        #expect(debouncer.read("5449000000996", now: 3000) == nil)
    }

    @Test func anIgnoredBarcodeCountsAgainAfterTheTime() {
        var debouncer = ScanDebouncer()
        debouncer.ignore("3017620422003", now: 10_000)
        #expect(debouncer.read("3017620422003", now: 10_000) == nil)
        #expect(debouncer.read("3017620422003", now: 12_999) == nil)
        #expect(debouncer.read("3017620422003", now: 13_000) == nil)
        #expect(debouncer.read("3017620422003", now: 13_100) == "3017620422003")
    }
}
