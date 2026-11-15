import AppKit
import SwiftUI

/// Values from `design/tokens.json` and the inline styles in `design/en/*.html`.
enum Theme {
    static let panelWidth: CGFloat = 372
    static let panelPadding: CGFloat = 16
    static let panelRadius: CGFloat = 24
    static let panelGapBelowMenuBar: CGFloat = 10
    static let panelScreenMargin: CGFloat = 8
    static let cardRadius: CGFloat = 16
    static let statRadius: CGFloat = 14
    static let buttonRadius: CGFloat = 11

    static let panelTint = NSColor(srgbRed: 20 / 255, green: 24 / 255, blue: 34 / 255, alpha: 0.66)

    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.70)
    static let panelBorder = Color.white.opacity(0.16)
    static let separator = Color.white.opacity(0.08)
    static let card = Color.white.opacity(0.08)
    static let control = Color.white.opacity(0.12)
    static let chip = Color.white.opacity(0.10)
    static let track = Color.white.opacity(0.14)
    static let gridline = Color.white.opacity(0.08)
    static let switchOn = Color(hex: 0x30B95A)

    static let settingsContent = Color(.sRGB, red: 24 / 255, green: 27 / 255, blue: 36 / 255, opacity: 0.93)
    static let settingsGroup = Color.white.opacity(0.06)

    static func hero(_ size: CGFloat = 44) -> Font {
        .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
    }
}
