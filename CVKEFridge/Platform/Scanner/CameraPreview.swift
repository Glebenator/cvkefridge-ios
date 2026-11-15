import AVFoundation
import SwiftUI
import UIKit

/// The picture of the camera of the scanner, in an `AVCaptureVideoPreviewLayer`. The picture fills the view.
///
/// - The picture follows the rotation of the device (`AVCaptureDevice.RotationCoordinator`).
/// - The camera reads barcodes only in the `window`: the view gives the window to the scanner in the coordinates of
///   the metadata output, also after a rotation and a change of its size.
/// - A tap focuses the camera on that point and sets the exposure there. `onFocus` gets the point in the view, for
///   the focus indicator.
///
/// The view is an image for VoiceOver. An activation of it focuses the camera in the centre of the picture.
struct CameraPreview: UIViewRepresentable {
    let scanner: BarcodeScanner
    /// The scan window, in the coordinates of this view.
    let scanWindow: CGRect
    /// True when the camera is open. The view then sets the rotation and the scan window.
    let isRunning: Bool
    /// A tap focused the camera on this point of the view.
    let onFocus: (CGPoint) -> Void

    func makeUIView(context: Context) -> CameraPreviewView {
        CameraPreviewView()
    }

    func updateUIView(_ view: CameraPreviewView, context: Context) {
        let scanner = scanner
        // The scanner makes a new camera after it closed one. The view then shows the session of the new camera.
        if scanner.preview.connect(to: view.previewLayer) {
            view.sessionChanged()
        }
        view.onRectOfInterest = { rect in scanner.setRectOfInterest(rect) }
        view.onTap = { point, devicePoint in
            scanner.focus(at: devicePoint)
            onFocus(point)
        }
        view.scanWindow = scanWindow
        if isRunning {
            view.cameraStarted(scanner.preview)
        }
    }
}

/// The view of `CameraPreview`. Its layer is the preview layer.
final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("The layer of the camera view is a preview layer")
        }
        return layer
    }

    /// Gets the scan window in the coordinates of the metadata output, each time it changes.
    var onRectOfInterest: (CGRect) -> Void = { _ in }
    /// Gets the point of a tap: in this view, and in the coordinates of the camera.
    var onTap: (_ point: CGPoint, _ devicePoint: CGPoint) -> Void = { _, _ in }

    /// The scan window, in the coordinates of this view.
    var scanWindow = CGRect.zero {
        didSet {
            if scanWindow != oldValue {
                updateRectOfInterest()
            }
        }
    }

    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    private var sentRect: CGRect?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        isAccessibilityElement = true
        accessibilityTraits = .image
        accessibilityLabel = String(
            localized: "Camera picture. Point the camera at a barcode.",
            comment: "VoiceOver reads it for the picture of the camera of the scanner."
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("The camera view is made in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateRectOfInterest()
    }

    /// The layer shows a different session. The rotation and the scan window are set again when its camera starts.
    func sessionChanged() {
        rotationObservation = nil
        rotation = nil
        sentRect = nil
    }

    /// The camera started. The preview layer then has its connection, so the rotation and the scan window can be
    /// set. More than one call does no harm.
    func cameraStarted(_ source: CameraPreviewSource) {
        if rotation == nil, let coordinator = source.rotationCoordinator(for: previewLayer) {
            rotation = coordinator
            // The coordinator gives its changes on the main queue.
            rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] coordinator, _ in
                let angle = coordinator.videoRotationAngleForHorizonLevelPreview
                if Thread.isMainThread {
                    MainActor.assumeIsolated { self?.rotate(to: angle) }
                } else {
                    Task { @MainActor in self?.rotate(to: angle) }
                }
            }
        }
        updateRectOfInterest()
    }

    private func rotate(to angle: CGFloat) {
        if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
        updateRectOfInterest()
    }

    /// Gives the scan window to the scanner, in the coordinates of the metadata output. Before the camera starts, the
    /// layer cannot convert the rectangle, and its result is then not a part of the picture.
    private func updateRectOfInterest() {
        guard previewLayer.connection != nil, !scanWindow.isEmpty, !bounds.isEmpty else {
            return
        }
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
        let rect = previewLayer.metadataOutputRectConverted(fromLayerRect: scanWindow).intersection(unit)
        guard !rect.isNull, rect.width > 0.01, rect.height > 0.01, rect != sentRect else {
            return
        }
        sentRect = rect
        onRectOfInterest(rect)
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self)
        onTap(point, previewLayer.captureDevicePointConverted(fromLayerPoint: point))
    }

    override func accessibilityActivate() -> Bool {
        let centre = CGPoint(x: bounds.midX, y: bounds.midY)
        onTap(centre, previewLayer.captureDevicePointConverted(fromLayerPoint: centre))
        return true
    }
}
