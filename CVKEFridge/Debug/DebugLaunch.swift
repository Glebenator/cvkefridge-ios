#if DEBUG
import CVKEFridgeFeatures
import Foundation

/// Reads and applies the launch options of the debug build (see `LaunchOptions`). The release build does not have
/// this file.
enum DebugLaunch {
    /// The options in the launch arguments and the environment.
    static func options(arguments: [String], environment: [String: String]) -> LaunchOptions {
        /// The value after an argument, or nil.
        func value(_ name: String) -> String? {
            guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else {
                return nil
            }
            return arguments[index + 1]
        }
        var options = LaunchOptions()
        options.showsGallery = arguments.contains("-gallery")
        options.inventory = value("-inventory").flatMap(LaunchOptions.InventoryRequest.init(rawValue:))
        options.storeName = value("-uiTestStore").map { name in
            String(name.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == "-" })
        }
        options.keepsStore = arguments.contains("-uiTestKeepStore")
        options.today = (value("-today") ?? environment["CVKE_TODAY"]).flatMap(CalendarDate.parse)
        options.changeLog = environment["CVKE_CHANGE_LOG"]
        options.httpFixtures = environment["CVKE_HTTP_FIXTURES"]
        if arguments.contains("-longNotices") {
            options.noticeTimeScale = 5
        }
        switch environment["CVKE_NOTIFICATIONS"] {
        case "allowed": options.notificationAccess = .allowed
        case "blocked": options.notificationAccess = .blocked
        case "alertsOff": options.notificationAccess = .alertsOff
        case "ask": options.notificationAccess = .ask
        case "system": options.usesSystemNotifications = true
        default: break
        }
        return options
    }

    /// The data folder of a UI test: a folder in the temporary files. It is empty at the start, when the options do
    /// not keep it.
    static func folders(for options: LaunchOptions) -> AppFolders? {
        guard let name = options.storeName, !name.isEmpty else {
            return nil
        }
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "CVKEFridge-UITest-\(name)", directoryHint: .isDirectory)
        if !options.keepsStore {
            try? FileManager.default.removeItem(at: folder)
        }
        return AppFolders(data: folder)
    }

    /// Replaces the change log as the options say, before the model reads it. A write that fails changes nothing:
    /// the app then shows the log that is there.
    static func prepare(_ options: LaunchOptions, changeLog: ChangeLogStore, today: CalendarDate) async {
        switch options.inventory {
        case .sample:
            try? await changeLog.replace(SampleInventory.changes(today: today))
        case .empty:
            try? await changeLog.replace([])
        case nil:
            break
        }
        if let text = options.changeLog {
            try? await changeLog.replace(text: text)
        }
    }

    /// The connection of the product lookup for a UI test or a fixture, or nil for the network.
    static func transport(for options: LaunchOptions) -> (any HttpTransport)? {
        guard options.isUITest || options.httpFixtures != nil else {
            return nil
        }
        return FixtureHttpTransport(json: options.httpFixtures ?? "{}")
    }
}

/// Answers the requests of the product lookup from a fixed list, with no network.
struct FixtureHttpTransport: HttpTransport {
    private struct Answer: Decodable {
        var status: Int?
        var body: String?
        var error: String?
    }

    private let answers: [String: Answer]

    /// - Parameter json: The answers, by barcode: `{"<barcode>": {"status": 200, "body": "…"}}` or
    ///   `{"<barcode>": {"error": "timeout"}}`. The key `*` is the answer for each other barcode.
    init(json: String) {
        answers = (try? JSONDecoder().decode([String: Answer].self, from: Data(json.utf8))) ?? [:]
    }

    func get(url: URL, headers: [String: String]) async throws -> HttpResponse {
        // The barcode is the last part of the path: `…/api/v2/product/<barcode>`.
        guard let answer = answers[url.lastPathComponent] ?? answers["*"] else {
            throw HttpTransportError.noConnection
        }
        switch answer.error {
        case "timeout":
            throw HttpTransportError.timeout
        case .some:
            throw HttpTransportError.noConnection
        case nil:
            return HttpResponse(status: answer.status ?? 200, text: answer.body ?? "")
        }
    }
}

/// The reminders of a UI test: no notification goes to the system, and the permission has a fixed answer.
actor FixtureReminderService: ReminderService {
    private var current: NotificationAccess
    private let stream: AsyncStream<Void>

    /// - Parameter access: What the permission says at the start. A request then gives `allowed` for `ask`.
    init(access: NotificationAccess) {
        current = access
        stream = AsyncStream { _ in }
    }

    func access() -> NotificationAccess {
        current
    }

    func requestAccess() -> NotificationAccess {
        if current == .ask {
            current = .allowed
        }
        return current
    }

    func update(planned: [PlannedReminder], todayFoods: [ReminderFood], timeZone: TimeZone) {}

    nonisolated func taps() -> AsyncStream<Void> {
        stream
    }
}
#endif
