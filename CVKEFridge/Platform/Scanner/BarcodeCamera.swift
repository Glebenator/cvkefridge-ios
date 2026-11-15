import AVFoundation
import CVKEFridgeFeatures

/// What the camera of the scanner does.
enum CameraStatus: Hashable, Sendable {
    /// The camera is closed: the scanner is not on the screen, or the app is in the background.
    case stopped
    /// The camera opens.
    case starting
    /// The preview shows the picture of the camera, and the reader looks for barcodes.
    case running
    /// The camera cannot open, or the system stopped it: for example, another app uses it.
    case failed
}

/// What the camera tells the scanner.
enum CameraEvent: Hashable, Sendable {
    case status(CameraStatus)
    /// If the camera has a light, and if the light is on.
    case torch(available: Bool, on: Bool)
    /// A barcode that counts as a scan, in the form of `Barcodes`.
    case scan(String)
}

/// What the scanner tells the camera. `BarcodeScanner` sends the commands in their order.
enum CameraCommand: Sendable {
    case start
    case stop
    /// Starts or stops the reads. `ignoring` is the barcode of the last scan (see `ScanReads`).
    case reading(Bool, ignoring: String?)
    /// The scan window, in the coordinates of the metadata output.
    case rectOfInterest(CGRect)
    /// Focuses and sets the exposure on a point, in the coordinates of the camera: (0, 0) to (1, 1).
    case focus(CGPoint)
    case torch(Bool)
}

/// The camera session, for the preview layer. `AVCaptureSession` is not `Sendable`, and the preview layer must get
/// it on the main actor. This value moves it there. It gives the session to no other code: all changes of the
/// session are in `BarcodeCamera`, on its queue. AVFoundation permits a preview layer to get the session on the main
/// thread while another queue configures it.
struct CameraPreviewSource: @unchecked Sendable {
    fileprivate let session: AVCaptureSession

    /// Shows the picture of the camera in the layer. The result is true when the layer showed no session or a
    /// different session before.
    @MainActor
    func connect(to layer: AVCaptureVideoPreviewLayer) -> Bool {
        if layer.session === session {
            return false
        }
        layer.session = session
        return true
    }

    /// The object that tells the rotation of the preview for the camera of the session, or nil while the session has
    /// no camera. Call it after the camera started.
    @MainActor
    func rotationCoordinator(for layer: AVCaptureVideoPreviewLayer) -> AVCaptureDevice.RotationCoordinator? {
        guard let input = session.inputs.first as? AVCaptureDeviceInput else {
            return nil
        }
        return AVCaptureDevice.RotationCoordinator(device: input.device, previewLayer: layer)
    }
}

/// The camera of the scanner: an `AVCaptureSession` with the barcode reader of AVFoundation. The reader works on the
/// phone, with no connection. The pictures stay in memory. The app does not keep them, and does not send them.
///
/// The reader reads only the barcodes of retail packages: EAN-13, EAN-8, and UPC-E. AVFoundation gives a UPC-A as an
/// EAN-13 with a 0 at the start, which is the form of `Barcodes`. It reads only in the scan window
/// (`CameraCommand.rectOfInterest`). `ScanReads` decides which reads become a scan.
///
/// All work on the session is on one serial queue, which is also the executor of this actor. So no session call
/// blocks the main actor, and the reads of the camera arrive in the isolation of the actor.
actor BarcodeCamera {
    private let queue = DispatchSerialQueue(label: "com.cvke.fridge.scanner", qos: .userInitiated)

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    /// The session, for the preview layer.
    nonisolated let preview: CameraPreviewSource
    /// The events of the camera. Read them in one task.
    nonisolated let events: AsyncStream<CameraEvent>

    private let session: AVCaptureSession
    private let output = AVCaptureMetadataOutput()
    private let continuation: AsyncStream<CameraEvent>.Continuation
    private let clock = MonotonicMillis()

    private enum Setup {
        case none
        case ready(AVCaptureDevice, MetadataDelegate)
        case failed
    }

    private var setup = Setup.none
    private var reads = ScanReads()
    /// True while the scanner wants the camera open.
    private var wanted = false
    private var interrupted = false
    private var torchOn = false
    private var rectOfInterest: CGRect?
    private var observers: [any NSObjectProtocol] = []
    private var focusCount = 0
    private var focusReset: Task<Void, Never>?

    /// The time after which a focus on a point goes back to the continuous focus, as in the Android app.
    private static let focusHold: Duration = .seconds(3)

    init() {
        let session = AVCaptureSession()
        self.session = session
        preview = CameraPreviewSource(session: session)
        (events, continuation) = AsyncStream.makeStream(of: CameraEvent.self, bufferingPolicy: .bufferingNewest(32))
    }

    isolated deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        focusReset?.cancel()
        if session.isRunning {
            session.stopRunning()
        }
        continuation.finish()
    }

    /// Does one command of the scanner.
    func perform(_ command: CameraCommand) {
        switch command {
        case .start:
            start()
        case .stop:
            stop()
        case .reading(let reading, let ignoring):
            reads.setReading(reading, ignoring: ignoring, now: clock.now())
        case .rectOfInterest(let rect):
            rectOfInterest = rect
            if case .ready = setup {
                output.rectOfInterest = rect
            }
        case .focus(let point):
            focus(at: point)
        case .torch(let on):
            setTorch(on)
        }
    }

    // MARK: - Start and stop

    private func start() {
        wanted = true
        if case .none = setup {
            configure()
        }
        guard case .ready(let device, _) = setup else {
            continuation.yield(.status(.failed))
            return
        }
        if !session.isRunning {
            continuation.yield(.status(.starting))
            // This call waits until the camera is open. It is on the queue of the actor, not on the main actor.
            session.startRunning()
        }
        publishStatus()
        continuation.yield(.torch(available: device.hasTorch, on: torchOn))
    }

    private func stop() {
        wanted = false
        focusReset?.cancel()
        guard case .ready(let device, _) = setup else {
            continuation.yield(.status(.stopped))
            return
        }
        // The light goes off with the camera.
        torchOn = false
        if session.isRunning {
            session.stopRunning()
        }
        interrupted = false
        continuation.yield(.status(.stopped))
        continuation.yield(.torch(available: device.hasTorch, on: false))
    }

    private func publishStatus() {
        guard wanted else {
            return
        }
        continuation.yield(.status(session.isRunning && !interrupted ? .running : .failed))
    }

    // MARK: - Configuration

    /// The back camera, or the camera that the device has.
    private static func camera() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
    }

    private func configure() {
        guard let device = Self.camera(), let input = try? AVCaptureDeviceInput(device: device) else {
            setup = .failed
            return
        }
        session.beginConfiguration()
        guard session.canAddInput(input), session.canAddOutput(output) else {
            session.commitConfiguration()
            setup = .failed
            return
        }
        session.addInput(input)
        session.addOutput(output)
        // The output tells its formats only after it is in a session with a camera.
        let formats: [AVMetadataObject.ObjectType] = [.ean13, .ean8, .upce]
        output.metadataObjectTypes = formats.filter(output.availableMetadataObjectTypes.contains)
        let delegate = MetadataDelegate { [weak self] reads in
            // The output calls its delegate on the queue of this actor.
            self?.assumeIsolated { $0.take(reads) }
        }
        output.setMetadataObjectsDelegate(delegate, queue: queue)
        if let rectOfInterest {
            output.rectOfInterest = rectOfInterest
        }
        // On an iPad, the camera stays open while a second app is on the screen.
        if session.isMultitaskingCameraAccessSupported {
            session.isMultitaskingCameraAccessEnabled = true
        }
        session.commitConfiguration()
        prepare(device)
        observe()
        setup = .ready(device, delegate)
    }

    /// Sets the camera for a barcode that is near: the focus range, and the zoom of `CloseFocus`.
    private func prepare(_ device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else {
            return
        }
        if device.isAutoFocusRangeRestrictionSupported {
            device.autoFocusRangeRestriction = .near
        }
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        let zoom = CloseFocus.zoomFactor(
            minimumFocusDistance: device.minimumFocusDistance,
            fieldOfView: Double(device.activeFormat.videoFieldOfView),
            deviceMaxZoom: Double(min(device.maxAvailableVideoZoomFactor, device.activeFormat.videoMaxZoomFactor))
        )
        if zoom > 1 {
            device.videoZoomFactor = max(CGFloat(zoom), device.minAvailableVideoZoomFactor)
        }
        device.unlockForConfiguration()
    }

    // MARK: - Reads

    private func take(_ reads: [RawRead]) {
        if let barcode = self.reads.read(reads, now: clock.now()) {
            continuation.yield(.scan(barcode))
        }
    }

    // MARK: - Focus and light

    private func focus(at point: CGPoint) {
        guard case .ready(let device, _) = setup, session.isRunning else {
            return
        }
        let point = CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
        guard (try? device.lockForConfiguration()) != nil else {
            return
        }
        if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
        }
        if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
            device.exposurePointOfInterest = point
            device.exposureMode = .autoExpose
        }
        device.unlockForConfiguration()

        focusCount += 1
        let count = focusCount
        focusReset?.cancel()
        focusReset = Task { [weak self] in
            try? await Task.sleep(for: Self.focusHold)
            if !Task.isCancelled {
                await self?.endFocus(count)
            }
        }
    }

    /// Goes back to the continuous focus and exposure in the centre, when no newer focus started.
    private func endFocus(_ count: Int) {
        guard count == focusCount, case .ready(let device, _) = setup, (try? device.lockForConfiguration()) != nil else {
            return
        }
        let centre = CGPoint(x: 0.5, y: 0.5)
        if device.isFocusModeSupported(.continuousAutoFocus) {
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = centre
            }
            device.focusMode = .continuousAutoFocus
        }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = centre
            }
            device.exposureMode = .continuousAutoExposure
        }
        device.unlockForConfiguration()
    }

    private func setTorch(_ on: Bool) {
        guard case .ready(let device, _) = setup, device.hasTorch else {
            return
        }
        if session.isRunning, device.isTorchAvailable, (try? device.lockForConfiguration()) != nil {
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
            torchOn = on
        }
        continuation.yield(.torch(available: true, on: torchOn))
    }

    // MARK: - What the system does with the camera

    private func observe() {
        let center = NotificationCenter.default
        // The blocks run on the thread of the notification. They read the values that are `Sendable`, and then go to
        // the actor.
        observers = [
            center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { [weak self] note in
                let reason = (note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int)
                    .flatMap(AVCaptureSession.InterruptionReason.init(rawValue:))
                let inBackground = reason == .videoDeviceNotAvailableInBackground
                Task { await self?.interruptionChanged(began: true, inBackground: inBackground) }
            },
            center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil) { [weak self] _ in
                Task { await self?.interruptionChanged(began: false, inBackground: false) }
            },
            center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { [weak self] note in
                let reset = (note.userInfo?[AVCaptureSessionErrorKey] as? AVError)?.code == .mediaServicesWereReset
                Task { await self?.runtimeError(mediaServicesWereReset: reset) }
            },
        ]
    }

    private func interruptionChanged(began: Bool, inBackground: Bool) {
        // The system closes the camera of an app in the background. The scanner stops the camera itself then, and
        // starts it when the app comes back.
        if began && inBackground {
            return
        }
        interrupted = began
        if began, torchOn, case .ready(let device, _) = setup {
            torchOn = false
            continuation.yield(.torch(available: device.hasTorch, on: false))
        }
        publishStatus()
    }

    private func runtimeError(mediaServicesWereReset: Bool) {
        guard wanted else {
            return
        }
        // After a restart of the media services of the system, the session can start again.
        if mediaServicesWereReset, !session.isRunning {
            session.startRunning()
        }
        publishStatus()
    }
}

/// Gets the barcodes of each picture from the metadata output, and gives the values that are `Sendable` to the
/// camera.
private final class MetadataDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    private let onReads: @Sendable ([RawRead]) -> Void

    init(onReads: @escaping @Sendable ([RawRead]) -> Void) {
        self.onReads = onReads
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        let window = output.rectOfInterest
        let reads = metadataObjects.compactMap { object -> RawRead? in
            guard let code = object as? AVMetadataMachineReadableCodeObject,
                  let text = code.stringValue,
                  let format = Barcodes.Format(code.type) else {
                return nil
            }
            let dx = code.bounds.midX - window.midX
            let dy = code.bounds.midY - window.midY
            return RawRead(format: format, text: text, offCentre: Double(dx * dx + dy * dy))
        }
        if !reads.isEmpty {
            onReads(reads)
        }
    }
}

extension Barcodes.Format {
    /// The format of a barcode that AVFoundation read, or nil for a format that is not on a retail package.
    /// AVFoundation has no format for UPC-A: it gives a UPC-A as an EAN-13 with a 0 at the start.
    init?(_ type: AVMetadataObject.ObjectType) {
        switch type {
        case .ean13: self = .ean13
        case .ean8: self = .ean8
        case .upce: self = .upcE
        default: return nil
        }
    }
}
