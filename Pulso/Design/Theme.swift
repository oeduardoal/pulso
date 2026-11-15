import AppKit
import SwiftUI

/// Values from `design/tokens.json` and the inline styles in `design/en/*.html`.
enum Theme {
    static let panelWidth: CGFloat = 372
    static let panelPadding: CGFloat = 16
    static let panelSpacing: CGFloat = 10
    static let panelRadius: CGFloat = 24
    static let panelGapBelowMenuBar: CGFloat = 10
    static let panelScreenMargin: CGFloat = 8
    static let buttonRadius: CGFloat = 11

    static let panelTint = NSColor(srgbRed: 20 / 255, green: 24 / 255, blue: 34 / 255, alpha: 0.66)

    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.70)
    static let panelBorder = Color.white.opacity(0.16)
    static let control = Color.white.opacity(0.12)
}
