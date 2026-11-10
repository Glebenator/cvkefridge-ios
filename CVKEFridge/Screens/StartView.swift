import CVKEFridgeCore
import SwiftUI

/// The start screen. It has no features yet. It shows the name, one line about the app, and the version.
struct StartView: View {
    private let version = StartView.currentVersion()

    var body: some View {
        ScrollView {
            VStack(spacing: Space.s4) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.accentSubtle)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "refrigerator")
                            .font(.title2)
                            .foregroundStyle(Palette.accent)
                    }
                    .accessibilityHidden(true)
                Text("CVKE Fridge")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("start_title")
                Text("Food inventory for the fridge. This first build has the start screen only.")
                    .font(.body)
                    .foregroundStyle(Palette.inkMuted)
                    .multilineTextAlignment(.center)
                Text("Version \(version.label)")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("start_version")
            }
            .padding(Space.s6)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center)
        .background(Palette.background.ignoresSafeArea())
    }

    /// The version from the Info.plist of the app bundle.
    private static func currentVersion() -> AppVersion {
        let info = Bundle.main.infoDictionary
        let name = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Int(info?["CFBundleVersion"] as? String ?? "") ?? 0
        return AppVersion(name: name, build: build)
    }
}

#Preview {
    StartView()
}
