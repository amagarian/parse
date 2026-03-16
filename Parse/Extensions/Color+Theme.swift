import SwiftUI

extension Color {
    static let theme = ThemeColors()
}

struct ThemeColors {
    let accent = Color(hex: 0xC9B99A)
    let accentSecondary = Color(hex: 0xA6947A)
    let background = Color(hex: 0x0B0907)
    let backgroundElevated = Color(hex: 0x100D0A)
    let cardBackground = Color(hex: 0x161210)
    let textPrimary = Color(hex: 0xEDE3D4)
    let textSecondary = Color(hex: 0x6E5E4A)
    let divider = Color(hex: 0xC9B99A).opacity(0.08)
    let success = Color(hex: 0xC9B99A)
    let venmoBlue = Color(red: 0.24, green: 0.55, blue: 0.87)
    let rule = Color(hex: 0xC9B99A).opacity(0.13)

    var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
