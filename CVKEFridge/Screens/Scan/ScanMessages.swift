import SwiftUI
import UIKit

/// What the scanner shows in the place of the picture of the camera: the explanation of the camera before iOS asks
/// for the permission, or the reason why there is no picture, with the action that helps.
enum ScanNotice: Hashable {
    /// The app did not ask for the camera yet. "Allow the camera" starts the question of iOS.
    case ask
    /// The person did not allow the camera. iOS does not ask again, so "Open settings" opens the settings of the app.
    case blocked
    /// The device has no camera.
    case noCamera
    /// The camera cannot open, or the system stopped it.
    case failed
}

/// A `ScanNotice` on the screen: an icon, a title, a text, and an optional action, in the middle of the camera area.
/// It scrolls when it is higher than the area, for example with a large text size.
struct ScanNoticeView: View {
    let notice: ScanNotice
    /// True while the question of iOS is on the screen.
    let isAsking: Bool
    let onAllow: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Space.s3) {
                    Image(icon: icon)
                        .font(.system(size: 44))
                        .foregroundStyle(Palette.primary)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(Typography.sectionTitle)
                        .foregroundStyle(Palette.onSurface)
                        .accessibilityAddTraits(.isHeader)
                    Text(text)
                        .font(Typography.body)
                        .foregroundStyle(Palette.onSurfaceVariant)
                        .frame(maxWidth: 480)
                    action
                        .padding(.top, Space.s2)
                }
                .multilineTextAlignment(.center)
                .padding(Space.s6)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private var icon: AppIcon {
        notice == .ask ? .camera : .cameraOff
    }

    private var title: LocalizedStringKey {
        switch notice {
        case .ask: "Scan barcodes with the camera"
        case .blocked: "Camera access is off"
        case .noCamera: "No camera on this device"
        case .failed: "The camera can't start"
        }
    }

    private var text: LocalizedStringKey {
        switch notice {
        case .ask:
            "CVKE Fridge uses the camera to read barcodes, and to take a photo of a food when you ask. The pictures stay on your phone. The app does not send them."
        case .blocked:
            "To scan a barcode, open the settings of the app and allow the camera. You can also type the barcode, or add the food by hand."
        case .noCamera:
            "Type the barcode, or add the food by hand."
        case .failed:
            "Another app can use the camera now. Close that app, or type the barcode."
        }
    }

    private var identifier: String {
        switch notice {
        case .ask: "camera_ask"
        case .blocked: "camera_blocked"
        case .noCamera: "camera_none"
        case .failed: "camera_failed"
        }
    }

    @ViewBuilder private var action: some View {
        switch notice {
        case .ask:
            Button("Allow the camera", action: onAllow)
                .buttonStyle(.primary)
                .disabled(isAsking)
                .accessibilityIdentifier("camera_allow")
        case .blocked:
            Button("Open settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier("camera_settings")
        case .noCamera, .failed:
            EmptyView()
        }
    }
}
