import CVKEFridgeFeatures
import SwiftUI

/// The barcode scanner, as a screen that covers the window. The camera reads the barcode, and the app looks up the
/// product. The add form then opens above the scanner with the values of the lookup. The person can also type the
/// barcode, or add the food by hand. These two buttons are always in the panel, so the scanner works with no camera
/// and with no permission. It takes the place of `ui/ScanScreen.kt` of the Android app.
///
/// - The picture of the camera fills the screen. The close button, the light button, and the panel are Liquid Glass
///   above it. On a wide screen, the panel is at the side of the camera. While the picture shows, the screen is dark
///   in each appearance, so the words on the glass are clear above each picture.
/// - Before iOS asks for the camera, the screen explains why the app needs it. When the camera is off, the screen
///   says so, with "Open settings". It reads the permission again when the person comes back.
/// - The panel says what leaves the phone: the barcode number goes to Open Food Facts, and nothing else.
/// - A read gives a haptic signal, and VoiceOver says "Looking up barcode …". One package gives one scan
///   (`ScanReads`). During a lookup, after a failed lookup, and while the person types a barcode, the camera does not
///   read. The camera closes while a form is above the scanner and while the app is in the background.
/// - The app never looks up a barcode again by itself. Only "Try again" does.
/// - The messages of the app show at the bottom of the camera area, above the panel. So after "Save and scan next",
///   the message "… added" with "Undo" does not cover the buttons of the panel.
///
/// The screen is the root view of `SheetRoute.scan`. The shell stops the lookup when the scanner closes.
struct ScanSheet: View {
    let openAreaId: String?

    @Environment(FridgeModel.self) private var model
    @Environment(Navigator.self) private var navigator
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scanner = BarcodeScanner()
    /// The camera access, or nil before the first read.
    @State private var access: CameraAccess?
    /// The number of taps on "Allow the camera". Each starts one question of iOS.
    @State private var accessRequests = 0
    @State private var isAsking = false
    /// True while the sheet for a typed barcode is open.
    @State private var typing = false
    /// The barcodes that the person typed. The lookup starts when the sheet is closed.
    @State private var typed: [String]?
    /// The last barcode that the scanner looked up. When the camera reads again, it ignores this barcode for a short
    /// time.
    @State private var lastBarcode: String?
    /// The other barcodes that the typed text of `lastBarcode` can be, for "Try again".
    @State private var otherForms: [String] = []
    /// True after some seconds with no barcode. The hint then says what helps.
    @State private var slow = false
    /// The part of the camera area below the buttons, in the coordinates of the screen. The scan window is in its
    /// middle.
    @State private var windowArea = CGRect.zero
    @State private var focusMark: FocusMark?
    @State private var focusCount = 0
    #if DEBUG
    @State private var standInLight = false
    #endif

    /// The time with no barcode after which the hint says what helps.
    private static let slowHintDelay: Duration = .seconds(10)
    /// The time that the focus indicator shows.
    private static let focusMarkTime: Duration = .milliseconds(1200)

    private var route: SheetRoute { .scan(openAreaId: openAreaId) }

    /// What the screen knows about the camera.
    private struct Camera: Equatable {
        /// True when the screen shows the picture of the camera, or its place while the camera opens.
        var shows = false
        var status = CameraStatus.stopped
        var hasLight = false
        var lightOn = false
    }

    private var camera: Camera {
        #if DEBUG
        if ScanStandIn.isOn {
            return Camera(shows: true, status: .running, hasLight: true, lightOn: standInLight)
        }
        #endif
        return Camera(
            shows: isAllowed,
            status: scanner.status,
            hasLight: scanner.hasTorch,
            lightOn: scanner.isTorchOn
        )
    }

    /// True when no form is above the scanner.
    private var isTop: Bool {
        navigator.sheets.last == route
    }

    /// True when the person allowed the camera.
    private var isAllowed: Bool {
        access == .allowed || standsIn
    }

    /// True when the camera must be open.
    private var cameraWanted: Bool {
        isAllowed && isTop && scenePhase != .background
    }

    /// True when a barcode in front of the camera must start a lookup.
    private var readingWanted: Bool {
        cameraWanted && scenePhase == .active && !typing && typed == nil && model.lookup == .idle
    }

    var body: some View {
        let camera = camera
        GeometryReader { proxy in
            let wide = proxy.size.width > proxy.size.height
            let layout = wide ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
            ZStack {
                backdrop(camera)
                layout {
                    cameraArea(camera)
                    panel(camera, wide: wide, size: proxy.size)
                }
            }
        }
        .motion(Motion.enter, value: access)
        .motion(Motion.enter, value: camera.status)
        // The picture of the camera is dark or bright, and the words on the glass must be clear above the two.
        .environment(\.colorScheme, camera.shows ? .dark : colorScheme)
        .statusBarHidden(camera.shows)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scan_screen")
        .accessibilityAction(.escape, close)
        .sheet(isPresented: $typing, onDismiss: lookUpTyped) {
            BarcodeEntrySheet(
                onLookUp: { candidates in
                    typed = candidates
                    typing = false
                },
                onCancel: { typing = false }
            )
        }
        .onAppear(perform: readAccess)
        .onDisappear { scanner.close() }
        .onChange(of: scenePhase) { _, phase in
            // The person can come back from the Settings app.
            if phase == .active {
                readAccess()
            }
        }
        .task(id: accessRequests) {
            guard accessRequests > 0 else {
                return
            }
            isAsking = true
            access = await model.camera.requestAccess()
            isAsking = false
        }
        .onChange(of: cameraWanted, initial: true) { _, wanted in
            if !standsIn {
                scanner.setRunning(wanted)
            }
        }
        .onChange(of: readingWanted, initial: true) { _, wanted in
            if !standsIn {
                scanner.setReading(wanted, ignoring: lastBarcode)
            }
        }
        .onChange(of: scanner.scanCount) { _, _ in
            scanned()
        }
        .onChange(of: model.lookup, initial: true) { _, lookup in
            show(lookup)
        }
        .task(id: readingWanted && camera.status == .running) {
            await showSlowHint(reading: readingWanted && camera.status == .running, hasLight: camera.hasLight)
        }
        .task(id: focusMark?.id) {
            guard focusMark != nil, (try? await Task.sleep(for: Self.focusMarkTime)) != nil else {
                return
            }
            withMotion(Motion.exit, reduceMotion: reduceMotion) { focusMark = nil }
        }
    }

    // MARK: - The parts of the screen

    /// What is behind the buttons and the panel: the picture of the camera with the scan window, or the background
    /// of the app.
    @ViewBuilder
    private func backdrop(_ camera: Camera) -> some View {
        if camera.shows {
            GeometryReader { proxy in
                let origin = proxy.frame(in: .global).origin
                let window = ScanWindow.rect(in: windowArea).offsetBy(dx: -origin.x, dy: -origin.y)
                ZStack {
                    Color.black
                    picture(camera, window: window)
                    if camera.status == .failed {
                        Palette.surface
                    } else {
                        ScanWindowShade(window: window, isReading: readingWanted)
                        if let focusMark {
                            FocusMarkView(mark: focusMark)
                                .id(focusMark.id)
                                .transition(.opacity)
                        }
                    }
                }
            }
            .ignoresSafeArea()
        } else {
            Palette.surface.ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func picture(_ camera: Camera, window: CGRect) -> some View {
        #if DEBUG
        if ScanStandIn.isOn {
            ScanStandInPicture(scanWindow: window, onFocus: markFocus)
        } else {
            preview(camera, window: window)
        }
        #else
        preview(camera, window: window)
        #endif
    }

    private func preview(_ camera: Camera, window: CGRect) -> some View {
        CameraPreview(scanner: scanner, scanWindow: window, isRunning: camera.status == .running, onFocus: markFocus)
            .accessibilityIdentifier("camera")
    }

    /// The area of the camera: the buttons at the top, and below them the scan window or the words about the
    /// camera. The messages of the app show at its bottom edge.
    private func cameraArea(_ camera: Camera) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.s3) {
                GlassIconButton(.close, label: "Close", action: close)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("scan_close")
                Spacer(minLength: 0)
                if camera.status == .running, camera.hasLight {
                    GlassIconButton(
                        camera.lightOn ? .flashlightOn : .flashlightOff,
                        label: camera.lightOn ? "Turn off the light" : "Turn on the light",
                        prominent: camera.lightOn,
                        action: { setLight(!camera.lightOn) }
                    )
                    .haptic(.selection, trigger: camera.lightOn)
                    .accessibilityIdentifier("torch")
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, Space.screenMargin)
            .padding(.vertical, Space.s2)
            Color.clear
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { frame in
                    windowArea = frame
                }
                .overlay {
                    if let notice = notice(camera) {
                        ScanNoticeView(notice: notice, isAsking: isAsking) { accessRequests += 1 }
                    }
                }
        }
        .noticeHost()
    }

    private func panel(_ camera: Camera, wide: Bool, size: CGSize) -> some View {
        ScanPanel(
            lookup: model.lookup,
            hint: hint(camera),
            fillsHeight: wide,
            onTypeBarcode: { typing = true },
            onAddByHand: { navigator.present(.addFood(openAreaId: openAreaId)) },
            onCancel: { model.cancelLookup() },
            onTryAgain: { barcode in
                // One lookup for one tap. The app does not try again by itself.
                model.lookUp(barcode, otherForms: barcode == lastBarcode ? otherForms : [])
            },
            onEnterByHand: { barcode in
                model.cancelLookup()
                navigator.present(.addFood(openAreaId: openAreaId, scan: Scanned(barcode: barcode, source: .notLookedUp)))
            }
        )
        .frame(
            maxWidth: wide ? min(size.width * 0.45, 420) : 560,
            maxHeight: wide ? .infinity : size.height * 0.6
        )
        // Below the camera, the panel is as high as its content, to its largest height. The camera area gets the
        // remaining space.
        .fixedSize(horizontal: false, vertical: !wide)
        .padding(wide ? [.vertical, .trailing] : [.horizontal, .bottom], Space.s2)
        .layoutPriority(1)
    }

    /// What the camera area says in the place of the picture, or nil when the picture shows.
    private func notice(_ camera: Camera) -> ScanNotice? {
        if camera.shows {
            return camera.status == .failed ? .failed : nil
        }
        switch access {
        case .ask: return .ask
        case .blocked: return .blocked
        case .noCamera: return .noCamera
        case .allowed, nil: return nil
        }
    }

    /// The hint of the panel while the camera shows a picture.
    private func hint(_ camera: Camera) -> String? {
        guard camera.shows, camera.status == .running else {
            return nil
        }
        return slow ? Wording.slowScanHint(hasLight: camera.hasLight) : String(localized: "Point the camera at the barcode.")
    }

    private var standsIn: Bool {
        #if DEBUG
        ScanStandIn.isOn
        #else
        false
        #endif
    }

    // MARK: - Actions

    private func close() {
        navigator.dismiss(route)
    }

    private func readAccess() {
        access = model.camera.access()
    }

    private func setLight(_ on: Bool) {
        #if DEBUG
        if ScanStandIn.isOn {
            standInLight = on
            return
        }
        #endif
        scanner.setTorch(on)
    }

    private func markFocus(_ point: CGPoint) {
        focusCount += 1
        withMotion(Motion.enter, reduceMotion: reduceMotion) {
            focusMark = FocusMark(id: focusCount, point: point)
        }
    }

    /// The camera read a barcode that counts. The camera does not read again until the lookup is done.
    private func scanned() {
        guard readingWanted, let barcode = scanner.lastScan else {
            return
        }
        Haptic.success.play()
        lastBarcode = barcode
        otherForms = []
        model.lookUp(barcode)
    }

    /// The sheet for a typed barcode is closed. The lookup starts now, so that the add form does not open while the
    /// sheet closes.
    private func lookUpTyped() {
        guard let candidates = typed, let barcode = candidates.first else {
            typed = nil
            return
        }
        typed = nil
        lastBarcode = barcode
        otherForms = Array(candidates.dropFirst())
        model.lookUp(barcode, otherForms: otherForms)
    }

    /// Shows a change of the lookup: VoiceOver hears the lookup and a failure, and the add form opens for a result.
    private func show(_ lookup: LookupState) {
        switch lookup {
        case .idle:
            break
        case .looking(let barcode):
            AccessibilityNotification.Announcement(Wording.spokenLookingUp(barcode: barcode)).post()
        case .done(let id, let scanned, let productId):
            if scanned.source == .notFound {
                Haptic.error.play()
            }
            navigator.present(.addFood(productId: productId, openAreaId: openAreaId, scan: scanned))
            model.lookupShown(id)
        case .failed(_, let failure):
            Haptic.error.play()
            AccessibilityNotification.Announcement(failure.title).post()
        }
    }

    /// After some seconds in which the camera reads and finds no barcode, the hint says what helps.
    private func showSlowHint(reading: Bool, hasLight: Bool) async {
        slow = false
        guard reading, (try? await Task.sleep(for: Self.slowHintDelay)) != nil else {
            return
        }
        withMotion(Motion.enter, reduceMotion: reduceMotion) { slow = true }
        AccessibilityNotification.Announcement(Wording.slowScanHint(hasLight: hasLight)).post()
    }
}
