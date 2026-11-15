import SwiftUI

enum Module: String, CaseIterable, Identifiable, Codable {
    case cpu, memory, disk, network, battery, sensors

    var id: String { rawValue }

    var title: String { L("module.\(rawValue)") }

    var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .disk: "internaldrive"
        case .network: "arrow.up.arrow.down"
        case .battery: "battery.75percent"
        case .sensors: "thermometer.medium"
        }
    }

    var accent: Accent {
        switch self {
        case .cpu, .network: .blue
        case .memory: .teal
        case .disk: .amber
        case .battery: .green
        case .sensors: .coral
        }
    }

    /// Menu bar styles that make sense for this module, first one is the default.
    var styles: [MenuBarStyle] {
        switch self {
        case .cpu: [.bars, .mini, .line, .ring, .dot]
        case .memory: [.ring, .mini, .line, .bars, .dot]
        case .disk: [.mini, .ring, .dot]
        case .network: [.speed, .line]
        case .battery: [.battery, .mini, .ring, .dot]
        case .sensors: [.mini, .dot]
        }
    }
}

enum MenuBarStyle: String, CaseIterable, Identifiable, Codable {
    case mini, line, bars, ring, speed, battery, dot
    var id: String { rawValue }
    var title: String { L("style.\(rawValue)") }
}

/// Accent colors from `design/tokens.json`. `base` fills shapes, `text` is the lighter tone for text on glass.
enum Accent: String, CaseIterable, Identifiable, Codable {
    case blue, teal, amber, orange, green, coral, monochrome
    var id: String { rawValue }

    var base: Color {
        switch self {
        case .blue: Color(hex: 0x5AB0FF)
        case .teal: Color(hex: 0x54D6B4)
        case .amber: Color(hex: 0xFFB454)
        case .orange: Color(hex: 0xFF9F5A)
        case .green: Color(hex: 0x6BDB7A)
        case .coral: Color(hex: 0xFF7A6B)
        case .monochrome: .white
        }
    }

    var text: Color {
        switch self {
        case .blue: Color(hex: 0x8CC8FF)
        case .teal: Color(hex: 0x7FE3C8)
        case .amber: Color(hex: 0xFFC47A)
        case .orange: Color(hex: 0xFFB98A)
        case .green: Color(hex: 0x9BEBA6)
        case .coral: Color(hex: 0xFFA397)
        case .monochrome: .white
        }
    }

    /// Colors a user can pick for a menu bar widget.
    static let menuBarChoices: [Accent] = [.monochrome, .blue, .teal, .amber, .coral]

    var title: String { L("color.\(rawValue)") }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
