import Foundation

/// The version of the app: a name and a build number.
/// The Android file `core/src/main/kotlin/com/cvke/fridge/core/AppVersion.kt` in cvkefridge-android must give the same
/// `label` for the same name and build.
public struct AppVersion: Equatable, Sendable {
    public let name: String
    public let build: Int

    public init(name: String, build: Int) {
        self.name = name
        self.build = build
    }

    /// The name and the build in brackets, for example `0.1.0 (1)`.
    public var label: String {
        "\(name) (\(build))"
    }
}
