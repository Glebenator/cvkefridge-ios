import SwiftUI
import UIKit

/// The design-language colour tokens of the Android app, as dynamic colours for light and dark mode.
/// Teal is the one accent. Status colours never change.
enum Palette {
    static let accent = dynamic(light: 0x0E7C86, dark: 0x52AEB9)
    /// The fill of a prominent button. White text on it has enough contrast in light and dark mode.
    static let accentFill = dynamic(light: 0x0E7C86, dark: 0x0E7C86)
    static let accentSubtle = dynamic(light: 0xE0F9FC, dark: 0x0E3135)
    static let ink = dynamic(light: 0x161A1F, dark: 0xE9EDF1)
    static let inkMuted = dynamic(light: 0x5B6470, dark: 0x9FA9B4)
    static let success = dynamic(light: 0x1A7F4B, dark: 0x5FD39A)
    static let warning = dynamic(light: 0x9A5B00, dark: 0xF5B14C)
    static let warningSubtle = dynamic(light: 0xFBF0DC, dark: 0x33270F)
    static let danger = dynamic(light: 0xB42318, dark: 0xF97066)
    static let dangerSubtle = dynamic(light: 0xFDECEA, dark: 0x3A1614)
    static let surfaceSunken = dynamic(light: 0xEEF0F3, dark: 0x0D1014)
    static let background = dynamic(light: 0xF6F7F9, dark: 0x12161B)
    static let gradientEnd = dynamic(light: 0xC68E67, dark: 0xD69D76)

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    /// A colour from 0xRRGGBB.
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    /// A colour from 0xRRGGBB.
    init(rgb: UInt32) {
        self.init(uiColor: UIColor(rgb: rgb))
    }
}

/// The 4-point spacing steps of the design language.
enum Space {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32
}
