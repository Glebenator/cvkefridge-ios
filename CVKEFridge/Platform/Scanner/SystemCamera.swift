import AVFoundation

/// The camera of the device and its permission, from AVFoundation.
struct SystemCamera: CameraAvailability {
    func access() -> CameraAccess {
        guard AVCaptureDevice.default(for: .video) != nil else {
            return .noCamera
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            return .ask
        case .authorized:
            return .allowed
        case .denied, .restricted:
            return .blocked
        @unknown default:
            return .blocked
        }
    }

    func requestAccess() async -> CameraAccess {
        _ = await AVCaptureDevice.requestAccess(for: .video)
        return access()
    }
}
