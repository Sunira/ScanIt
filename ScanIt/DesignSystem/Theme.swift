import SwiftUI
import UIKit

extension Color {
    /// A color that switches between a light-mode and a dark-mode hex value.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    /// Creates a color from a 0xRRGGBB value.
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Shared spacing and sizes, so screens stay consistent.
enum Metrics {
    static let screenPadding: CGFloat = 20
    static let cornerRadius: CGFloat = 16
    static let scanButtonSize: CGFloat = 64
    static let minTouchTarget: CGFloat = 44
}
