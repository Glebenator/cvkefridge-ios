import Foundation

/// The identifier of this phone: the origin of the changes that it makes. It is a random identifier that the app makes
/// one time and keeps in a file. It does not come from the hardware or from an account.
///
/// The Android file `data/PhoneId.kt` has the same behaviour.
actor PhoneId {
    private let file: URL
    private var known: String?

    init(file: URL) {
        self.file = file
    }

    /// The identifier. The first call makes it.
    ///
    /// - Throws: An error when the file cannot be read or written.
    func get() throws -> String {
        if let known {
            return known
        }
        let id = try read() ?? make()
        known = id
        return id
    }

    private func read() throws -> String? {
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return nil
        }
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.isIdentifier(text) ? text : nil
    }

    private func make() throws -> String {
        let id = UUID().uuidString.lowercased()
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(id.utf8).write(to: file, options: .atomic)
        return id
    }

    /// An identifier has 1 to 64 characters from `a` to `z`, `0` to `9`, and `-` (rule 1 of `spec/rules.md`).
    private static func isIdentifier(_ text: String) -> Bool {
        let scalars = text.unicodeScalars
        return (1...64).contains(scalars.count) && scalars.allSatisfy { scalar in
            ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) || scalar == "-"
        }
    }
}

/// Makes a random identifier for a product, a batch, a storage area, or a change: a UUID in lowercase.
enum NewIdentifier {
    static func make() -> String {
        UUID().uuidString.lowercased()
    }
}
