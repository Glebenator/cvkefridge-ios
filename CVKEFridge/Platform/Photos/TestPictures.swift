#if DEBUG
import CVKEFridgeFeatures
import Foundation
import ImageIO
import UIKit

/// The pictures of the UI tests, in the place of the photo picker and the camera of the system. The release build does
/// not have this file. `App/LaunchOptions.swift` lists the other launch arguments.
///
/// | Argument | Effect |
/// | --- | --- |
/// | `-uiTestPicture photo` | "Choose a photo" and "Take a photo" give a built-in picture at once, with no picker and no camera. Each picture has a different colour. |
/// | `-uiTestPicture unreadable` | They give bytes that are not a picture. The app then says that the photo failed. |
/// | `-uiTestCamera ask` | "Take a photo" is there also with no camera. The access is `ask`, and the request gives `allowed`. |
/// | `-uiTestCamera blocked` | The same, with the access `blocked`. |
/// | `-uiTestCamera allowed` | The same, with the access `allowed`. |
@MainActor
enum TestPictures {
    enum Kind: String {
        case photo
        case unreadable
    }

    /// The kind of the built-in pictures, or nil for the photo picker and the camera of the system.
    static let kind: Kind? = value("-uiTestPicture").flatMap(Kind.init(rawValue:))

    /// The camera access of the test, or nil for the camera of the device.
    private(set) static var cameraAccess: CameraAccess? = {
        switch value("-uiTestCamera") {
        case "ask": .ask
        case "blocked": .blocked
        case "allowed": .allowed
        default: nil
        }
    }()

    private static var count = 0

    /// The request of the camera access: `ask` becomes `allowed`.
    static func requestCameraAccess() -> CameraAccess? {
        if cameraAccess == .ask {
            cameraAccess = .allowed
        }
        return cameraAccess
    }

    /// The next built-in picture: a JPEG of 1600 x 1200 pixels with a camera orientation, a location, and a time, so
    /// that the app must turn it and remove its metadata. Each picture has a different colour.
    static func next() -> Data {
        guard kind == .photo else {
            return Data("This is not a picture".utf8)
        }
        let colours: [UIColor] = [.systemTeal, .systemOrange, .systemPurple, .systemPink]
        let colour = colours[count % colours.count]
        count += 1
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: 1600, height: 1200)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            colour.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 500, y: 300, width: 600, height: 600))
            // A dark bar at the left of the file is at the top of the picture after the turn.
            UIColor.black.withAlphaComponent(0.6).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 1200))
        }
        let data = NSMutableData()
        guard let cgImage = image.cgImage,
              let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.jpeg" as CFString, 1, nil)
        else {
            return Data()
        }
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 47.37, kCGImagePropertyGPSLongitude: 8.54],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:11:14 12:00:00"],
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    private static func value(_ name: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}
#endif
