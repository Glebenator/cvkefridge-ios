import SwiftUI

@main
struct CVKEFridgeApp: App {
    /// The objects that live as long as the app.
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            root
                .tint(Palette.primary)
        }
    }

    @ViewBuilder private var root: some View {
        #if DEBUG
        // The debug build shows the design gallery when it starts with the argument `-gallery`.
        if environment.options.showsGallery {
            DesignGalleryView()
        } else {
            app
        }
        #else
        app
        #endif
    }

    /// The app, with the two objects that each screen reads from the environment: the model and the navigator.
    private var app: some View {
        RootView(restoresTab: !environment.options.isUITest)
            .environment(environment.model)
            .environment(environment.navigator)
            .environment(environment.noticeStage)
            .task { await environment.start() }
    }
}
