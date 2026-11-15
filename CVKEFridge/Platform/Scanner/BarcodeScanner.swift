import CoreGraphics
import Observation

/// The barcode scanner as the screen sees it: the state of the camera, the light, and the scans. It is on the main
/// actor. The work on the camera is in `BarcodeCamera`, off the main actor.
///
/// ```swift
/// @State private var scanner = BarcodeScanner()
///
/// CameraPreview(scanner: scanner, scanWindow: window, isRunning: scanner.status == .running) { point in … }
///     .onChange(of: wanted, initial: true) { _, wanted in scanner.setRunning(wanted) }
///     .onChange(of: scanner.scanCount) { _, _ in lookUp(scanner.lastScan) }
/// ```
///
/// The scanner makes the camera at the first `setRunning(true)`, so a screen with no camera permission makes none.
/// The commands go to the camera in their order. After a scan, the camera does not read until `setReading(true, …)`
/// starts it again.
@MainActor
@Observable
final class BarcodeScanner {
    /// What the camera does.
    private(set) var status: CameraStatus = .stopped
    /// True when the camera has a light.
    private(set) var hasTorch = false
    private(set) var isTorchOn = false
    /// The barcode of the newest scan, in the form of `Barcodes`, or nil.
    private(set) var lastScan: String?
    /// The number of scans. It changes with each scan, also when the barcode is the same.
    private(set) var scanCount = 0

    @ObservationIgnored private var link: Link?

    /// The connection to one camera: the camera, the stream of the commands, and the two tasks.
    private struct Link {
        let camera: BarcodeCamera
        let commands: AsyncStream<CameraCommand>.Continuation
        let listener: Task<Void, Never>
    }

    /// The session of the camera, for the preview layer.
    var preview: CameraPreviewSource {
        connect().camera.preview
    }

    /// Opens or closes the camera.
    func setRunning(_ running: Bool) {
        if running {
            send(.start)
        } else if link != nil {
            send(.stop)
        }
    }

    /// Starts or stops the reads of the camera. `ignoring` is the barcode of the last scan: the package can still be
    /// in front of the camera, so the camera ignores this barcode for a short time.
    func setReading(_ reading: Bool, ignoring: String? = nil) {
        if link != nil || reading {
            send(.reading(reading, ignoring: ignoring))
        }
    }

    /// Turns the light of the camera on or off.
    func setTorch(_ on: Bool) {
        if hasTorch {
            send(.torch(on))
        }
    }

    /// Focuses the camera on a point, in the coordinates of the camera: (0, 0) to (1, 1).
    func focus(at devicePoint: CGPoint) {
        send(.focus(devicePoint))
    }

    /// Sets the scan window, in the coordinates of the metadata output.
    func setRectOfInterest(_ rect: CGRect) {
        send(.rectOfInterest(rect))
    }

    /// Closes the camera and ends the tasks of the scanner. Call it when the screen of the scanner goes away.
    func close() {
        guard let link else {
            return
        }
        link.commands.yield(.stop)
        link.commands.finish()
        link.listener.cancel()
        self.link = nil
        status = .stopped
        hasTorch = false
        isTorchOn = false
    }

    private func send(_ command: CameraCommand) {
        connect().commands.yield(command)
    }

    /// The connection to the camera. The first call makes the camera and starts the two tasks. One task gives the
    /// commands to the camera in their order. It ends when the stream of the commands ends (`close()`). The other
    /// task reads the events of the camera. It ends when `close()` cancels it, or when the camera goes away.
    private func connect() -> Link {
        if let link {
            return link
        }
        let camera = BarcodeCamera()
        let (commands, continuation) = AsyncStream.makeStream(of: CameraCommand.self)
        Task {
            for await command in commands {
                await camera.perform(command)
            }
        }
        let listener = Task { [weak self] in
            for await event in camera.events {
                self?.take(event)
            }
        }
        let link = Link(camera: camera, commands: continuation, listener: listener)
        self.link = link
        return link
    }

    private func take(_ event: CameraEvent) {
        switch event {
        case .status(let status):
            self.status = status
        case .torch(let available, let on):
            hasTorch = available
            isTorchOn = on
        case .scan(let barcode):
            lastScan = barcode
            scanCount += 1
        }
    }
}
