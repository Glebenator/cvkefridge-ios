import CVKEFridgeFeatures
import Foundation

/// The objects that live as long as the app: the stores, the services, the clock, the model, and the navigator. The
/// app makes one at its start and gives the model and the navigator to the views. It takes the place of
/// `FridgeApplication.kt` of the Android app.
///
/// Each object gets its dependencies through its initializer here. No object reads a global value.
@MainActor
final class AppEnvironment {
    let options: LaunchOptions
    let model: FridgeModel
    let navigator = Navigator()
    let noticeStage = NoticeStage()

    private let changeLog: ChangeLogStore
    private let clock: DayClock
    private var started = false

    init(options: LaunchOptions = .current) {
        self.options = options
        var folders = AppFolders.standard()
        var transport: any HttpTransport = URLSessionHttpTransport()
        var reminders: (any ReminderService)?
        #if DEBUG
        folders = DebugLaunch.folders(for: options) ?? folders
        transport = DebugLaunch.transport(for: options) ?? transport
        if options.isUITest {
            reminders = FixtureReminderService(access: options.notificationAccess ?? .ask)
        }
        #endif
        folders.prepare()

        let changeLog = ChangeLogStore(file: folders.changeLog)
        let clock = options.today.map { DayClock(fixed: $0) } ?? DayClock()
        self.changeLog = changeLog
        self.clock = clock
        model = FridgeModel(
            FridgeModel.Dependencies(
                changeLog: changeLog,
                phoneId: PhoneId(file: folders.phoneId),
                readFoods: { try await BundledTables.foods() },
                readStorageHints: { try await BundledTables.storageHints() },
                clock: clock,
                lookup: OpenFoodFactsLookupService(
                    cacheFile: folders.productLookups,
                    transport: transport,
                    version: AppVersion.current.name
                ),
                // The service connects to the notification center here, before the app completes its start, so that
                // the tap on a reminder that started the app arrives.
                reminders: reminders ?? LocalReminderService(),
                reminderSettings: JSONFileStore(
                    file: folders.reminders,
                    defaultValue: .defaults,
                    decode: { data in try ReminderSettings.decode(data) },
                    encode: { settings in settings.encode() }
                ),
                recentSettings: JSONFileStore(
                    file: folders.recent,
                    defaultValue: RecentSettings(),
                    decode: { data in try RecentSettings.decode(data) },
                    encode: { settings in try settings.encoded() }
                ),
                photos: FilePhotoService(directory: folders.photos),
                camera: SystemCamera()
            )
        )
    }

    /// Starts the model, one time. The debug build first changes the change log when a launch option asks for it.
    func start() async {
        if started {
            return
        }
        started = true
        #if DEBUG
        await DebugLaunch.prepare(options, changeLog: changeLog, today: clock.today)
        #endif
        model.start()
    }
}
