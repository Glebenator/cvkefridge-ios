import CVKEFridgeFeatures
import Foundation

/// What the debug build reads from its launch arguments and its environment, for work on the screens and for the UI
/// tests. The release build reads nothing: each value has its default there. `Debug/DebugLaunch.swift` has the code
/// that reads and uses the values.
///
/// | Argument or variable | Effect |
/// | --- | --- |
/// | `-gallery` | Shows the design gallery in the place of the app. |
/// | `-inventory sample` | Replaces the change log with the sample (`SampleInventory`), with dates from today. |
/// | `-inventory empty` | Removes the change log. |
/// | `-uiTestStore <name>` | Uses a data folder of its own in the temporary files, and makes it empty at the start. The product lookup then uses no network, the reminders do not use the system, and the selected tab is not restored. |
/// | `-uiTestKeepStore` | With `-uiTestStore`: keeps the files of the folder, for a test that starts the app a second time. |
/// | `-today 2026-11-12` | Uses this date as today. The clock stays at 12:00 of the date. |
/// | `CVKE_CHANGE_LOG` | Replaces the change log with this text: one change on each line, as `ChangeCodec` writes it. A line that is not a change stays in the file. |
/// | `CVKE_HTTP_FIXTURES` | The answers of the product lookup, as JSON: `{"<barcode>": {"status": 200, "body": "…"}}`, or `{"<barcode>": {"error": "timeout"}}` (`timeout` or `noConnection`). A barcode that is not there gets `"*"`, or no connection. |
/// | `CVKE_NOTIFICATIONS` | With `-uiTestStore`: what the notification permission says: `ask` (default), `allowed`, `blocked`, or `alertsOff`. With `system`, the reminders use the notifications of iOS, for the test of a tap on a reminder. |
struct LaunchOptions: Sendable {
    enum InventoryRequest: String, Sendable {
        case sample
        case empty
    }

    var showsGallery = false
    var inventory: InventoryRequest?
    var storeName: String?
    var keepsStore = false
    var today: CalendarDate?
    var changeLog: String?
    var httpFixtures: String?
    var notificationAccess: NotificationAccess?
    /// True when a UI test uses the notifications of iOS, and not a fixed notification permission.
    var usesSystemNotifications = false

    /// True when a UI test started the app with a data folder of its own.
    var isUITest: Bool {
        storeName != nil
    }

    /// The options of this start of the app.
    static var current: LaunchOptions {
        #if DEBUG
        return DebugLaunch.options(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment
        )
        #else
        return LaunchOptions()
        #endif
    }
}
