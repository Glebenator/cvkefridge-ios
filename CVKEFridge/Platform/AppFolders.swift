import Foundation

/// The files of the app on the phone. All of them are in one folder, `data`.
///
/// The folder is in Application Support, and it is not in the backup: the inventory stays on the phone, as on Android,
/// where the backup is off. A UI test gives another folder, so that it does not change the inventory of the person.
struct AppFolders: Sendable, Equatable {
    /// The folder with all files of the app.
    let data: URL

    /// The change log: one change on each line.
    var changeLog: URL { file("changes.jsonl") }
    /// The identifier of this phone.
    var phoneId: URL { file("phone-id") }
    /// The reminder settings.
    var reminders: URL { file("reminders.json") }
    /// The products that the person removed from the recent foods of the add form.
    var recent: URL { file("recent.json") }
    /// The cache of the product lookup.
    var productLookups: URL { file("product-lookups.json") }
    /// The photos of the products. The prepared photos of the add forms are in `photos-prepared` next to it.
    var photos: URL { data.appending(path: "photos", directoryHint: .isDirectory) }

    /// The folder `CVKEFridge` in Application Support.
    static func standard() -> AppFolders {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return AppFolders(data: support.appending(path: "CVKEFridge", directoryHint: .isDirectory))
    }

    /// Makes the folder, and keeps it out of the backup. A folder that cannot be made gives no error here: the first
    /// read or write of a file in it gives the error, and the screen then says what failed.
    func prepare() {
        try? FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        var folder = data
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? folder.setResourceValues(values)
    }

    private func file(_ name: String) -> URL {
        data.appending(path: name, directoryHint: .notDirectory)
    }
}
