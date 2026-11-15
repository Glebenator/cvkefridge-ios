import SwiftUI

@main
struct CVKEFridgeApp: App {
    var body: some Scene {
        WindowGroup {
            root
                .tint(Palette.primary)
        }
    }

    @ViewBuilder private var root: some View {
        #if DEBUG
        // The debug build shows the design gallery when it starts with the argument `-gallery`.
        if ProcessInfo.processInfo.arguments.contains("-gallery") {
            DesignGalleryView()
        } else {
            StartView()
        }
        #else
        StartView()
        #endif
    }
}
