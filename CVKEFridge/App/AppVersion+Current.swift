import CVKEFridgeCore
import Foundation

extension AppVersion {
    /// The version of the app, from the Info.plist of the app bundle.
    static var current: AppVersion {
        let info = Bundle.main.infoDictionary
        let name = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Int(info?["CFBundleVersion"] as? String ?? "") ?? 0
        return AppVersion(name: name, build: build)
    }
}
