import CVKEFridgeFeatures
import Foundation
import UIKit
@testable import CVKEFridge

/// A `FridgeModel` with its files in a new temporary folder and services that use no system feature. The test then
/// controls the photo service.
@MainActor
struct ModelFixture {
    let folder: URL
    let photos = RecordingPhotoService()
    let model: FridgeModel

    /// - Parameter changeLogText: The text of the change log at the start, or nil for no file.
    init(changeLogText: String? = nil) throws {
        folder = FileManager.default.temporaryDirectory.appending(path: "model-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let log = folder.appending(path: "changes.jsonl")
        if let changeLogText {
            try Data(changeLogText.utf8).write(to: log)
        }
        model = FridgeModel(
            FridgeModel.Dependencies(
                changeLog: ChangeLogStore(file: log),
                phoneId: PhoneId(file: folder.appending(path: "phone-id")),
                readFoods: { FoodTable(foods: []) },
                readStorageHints: { StorageHints(afterOpening: [], tags: [:]) },
                clock: DayClock(fixed: CalendarDate(year: 2026, month: 5, day: 1)!),
                lookup: NoLookup(),
                reminders: SilentReminders(),
                reminderSettings: JSONFileStore(
                    file: folder.appending(path: "reminders.json"),
                    defaultValue: .defaults,
                    decode: { data in try ReminderSettings.decode(data) },
                    encode: { settings in settings.encode() }
                ),
                recentSettings: JSONFileStore(
                    file: folder.appending(path: "recent.json"),
                    defaultValue: RecentSettings(),
                    decode: { data in try RecentSettings.decode(data) },
                    encode: { settings in try settings.encoded() }
                ),
                photos: photos,
                camera: NoCamera()
            )
        )
    }

    func removeFolder() {
        try? FileManager.default.removeItem(at: folder)
    }
}

/// Waits until the condition is true, for not more than 5 seconds. The result is the last value of the condition.
@MainActor
func eventually(_ condition: @MainActor () async -> Bool) async -> Bool {
    for _ in 0..<500 {
        if await condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
}

/// A photo service that records the calls. `prepare` waits until the test calls `finishPrepare`.
actor RecordingPhotoService: PhotoService {
    private(set) var cleanCalls: [Set<String>] = []
    private(set) var discarded: [PreparedPhoto] = []
    private var waiting: [CheckedContinuation<PreparedPhoto, any Error>] = []
    private var prepared = 0

    /// The number of `prepare` calls that wait.
    var waitingPrepares: Int { waiting.count }

    /// Ends the oldest `prepare` that waits, with a new prepared photo.
    @discardableResult
    func finishPrepare() -> PreparedPhoto? {
        guard !waiting.isEmpty else {
            return nil
        }
        prepared += 1
        let photo = PreparedPhoto(fileName: "prepared-\(prepared).jpg")
        waiting.removeFirst().resume(returning: photo)
        return photo
    }

    func start() async -> [String: ProductPhoto] { [:] }

    func setPhoto(productId: String, picture: PictureSource) async throws -> PhotoChange {
        throw CocoaError(.fileWriteUnknown)
    }

    func undo(_ change: PhotoChange, productId: String) async -> ProductPhoto? { nil }

    func removePhoto(productId: String) async throws -> RemovedPhoto? { nil }

    func restore(_ removed: RemovedPhoto) async -> ProductPhoto? { nil }

    func release(_ removed: RemovedPhoto) async {}

    func release(_ change: PhotoChange) async {}

    func prepare(picture: PictureSource) async throws -> PreparedPhoto {
        try await withCheckedThrowingContinuation { continuation in
            waiting.append(continuation)
        }
    }

    func url(of prepared: PreparedPhoto) async -> URL? {
        URL(filePath: "/tmp/\(prepared.fileName)")
    }

    func adopt(productId: String, prepared: PreparedPhoto) async throws -> ProductPhoto {
        ProductPhoto(url: URL(filePath: "/tmp/\(productId).jpg"))
    }

    func discard(_ prepared: PreparedPhoto) async {
        discarded.append(prepared)
    }

    func clean(productIds: Set<String>) async {
        cleanCalls.append(productIds)
    }

    nonisolated func cachedImage(at url: URL, pixelSize: Int) -> UIImage? { nil }

    func image(at url: URL, pixelSize: Int) async -> UIImage? { nil }
}

private struct NoLookup: ProductLookupService {
    func find(_ barcodes: [String]) async throws(CancellationError) -> ProductLookupAnswer {
        throw CancellationError()
    }
}

private struct SilentReminders: ReminderService {
    func access() async -> NotificationAccess { .ask }
    func requestAccess() async -> NotificationAccess { .ask }
    func update(planned: [PlannedReminder], todayFoods: [ReminderFood], timeZone: TimeZone) async {}
    func taps() -> AsyncStream<Void> { AsyncStream { _ in } }
}

private struct NoCamera: CameraAvailability {
    func access() -> CameraAccess { .noCamera }
    func requestAccess() async -> CameraAccess { .noCamera }
}
