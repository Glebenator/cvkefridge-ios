import CVKEFridgeFeatures
import Foundation

/// The fixtures in `Resources/openfoodfacts`: `nutella.json` and `coca-cola.json` as the server gave them on
/// 12 November 2026, and the others made in the same format. They are copies of the fixtures of the Android tests.
enum LookupFixtures {
    static func text(_ name: String) throws -> String {
        let parts = name.split(separator: ".")
        guard let url = Bundle.module.url(
            forResource: String(parts[0]),
            withExtension: String(parts[1]),
            subdirectory: "Resources/openfoodfacts"
        ) else {
            throw FixtureMissing(name: name)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    struct FixtureMissing: Error {
        let name: String
    }
}

/// A value that tests change from more than one task.
final class LockedBox<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) {
        stored = value
    }

    var value: Value {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }

    func update<Result>(_ change: (inout Value) -> Result) -> Result {
        lock.withLock { change(&stored) }
    }
}

/// A transport that records the requests and gives the answers in turn. The last answer stays for each later request.
final class FakeTransport: HttpTransport, @unchecked Sendable {
    typealias Answer = @Sendable () throws -> HttpResponse

    private let answers: LockedBox<[Answer]>
    let requests = LockedBox<[(url: URL, headers: [String: String])]>([])

    init(_ answers: Answer...) {
        self.answers = LockedBox(answers)
    }

    var requestCount: Int {
        requests.value.count
    }

    func get(url: URL, headers: [String: String]) async throws -> HttpResponse {
        requests.update { $0.append((url, headers)) }
        let answer = answers.update { list -> Answer in
            list.count > 1 ? list.removeFirst() : list[0]
        }
        return try answer()
    }
}

/// A folder in the temporary folder for one test. `remove()` deletes it.
struct ScratchFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appending(path: "cvke-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func file(_ name: String) -> URL {
        url.appending(path: name, directoryHint: .notDirectory)
    }

    func names(in folder: URL? = nil) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: (folder ?? url).path)) ?? []).sorted()
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
