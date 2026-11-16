import AppKit
import SwiftUI

/// The status item content: one small widget per module the user shows in the menu bar.
struct MenuBarView: View {
    @Environment(Monitor.self) private var monitor
    @AppStorage(Pref.menuBarOrder) private var order = ""
    @AppStorage(Pref.menuBarHidden) private var hidden = ""
    @AppStorage(Pref.menuBarCompact) private var compact = true
    let onWidthChange: (CGFloat) -> Void

    var body: some View {
        // Reads only the menu bar snapshot, which the monitor refreshes on each module's interval,
        // so the status item redraws every few seconds instead of on every sample.
        let readings = monitor.menuBar
        let modules = Pref.menuBarModules(order: order, hidden: hidden).filter { readings[$0] != nil }
        HStack(spacing: compact ? 7 : 12) {
            if modules.isEmpty {
                // The brand glyph is drawn on an 18 pt canvas as a template, so it follows the menu bar tint.
                Image("MenuBarGlyph")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.primary)
            }
            ForEach(modules) { module in
                MenuBarWidget(module: module, reading: readings[module] ?? MenuBarReading())
            }
        }
        .font(.system(size: 13, weight: .medium).monospacedDigit())
        .padding(.horizontal, compact ? 3 : 6)
        // One flattened layer instead of one per shape keeps each update cheap.
        .drawingGroup()
        .frame(maxHeight: .infinity)
        .fixedSize(horizontal: true, vertical: false)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { onWidthChange($0) }
        .accessibilityElement(children: .combine)
    }
}

private struct MenuBarWidget: View {
    let module: Module
    let reading: MenuBarReading
    @AppStorage private var storedStyle: String
    @AppStorage private var storedColor: String

    init(module: Module, reading: MenuBarReading) {
        self.module = module
        self.reading = reading
        _storedStyle = AppStorage(wrappedValue: module.styles[0].rawValue, Pref.style(module))
        _storedColor = AppStorage(wrappedValue: Accent.monochrome.rawValue, Pref.color(module))
    }

    private var style: MenuBarStyle {
        MenuBarStyle(rawValue: storedStyle).flatMap { module.styles.contains($0) ? $0 : nil } ?? module.styles[0]
    }

    private var tint: Color {
        let accent = Accent(rawValue: storedColor) ?? .monochrome
        return accent == .monochrome ? .primary : accent.base
    }

    var body: some View {
        HStack(spacing: 4) {
            switch style {
            case .mini:
                // Label stacked over the value, two short lines that fit the menu bar height.
                VStack(alignment: .leading, spacing: -2) {
                    Text(L("menubar.\(module.rawValue)"))
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(tint == .primary ? Color.secondary : tint)
                    StableText(text: reading.text, widest: reading.widest, alignment: .leading)
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                }
            case .line:
                Sparkline(values: Array(reading.history.suffix(20)), color: tint)
                    .frame(width: 30, height: 14)
                valueText(reading.text)
            case .bars:
                MiniBars(values: Array(reading.history.suffix(6)), color: tint)
                    .frame(width: 22, height: 14)
                valueText(reading.text)
            case .ring:
                RingGauge(fraction: reading.fraction, color: tint, lineWidth: 3, track: .primary.opacity(0.3))
                    .frame(width: 13, height: 13)
                valueText(reading.text)
            case .speed:
                VStack(alignment: .leading, spacing: -2) {
                    MenuBarRate(symbol: "arrow.down", rate: reading.download)
                    MenuBarRate(symbol: "arrow.up", rate: reading.upload)
                }
                .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
            case .battery:
                BatteryGlyph(level: reading.fraction, color: tint, width: 22, height: 11)
                valueText(reading.text)
            case .dot:
                Circle().fill(reading.status.base).frame(width: 7, height: 7)
                valueText(reading.text)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(module.title) \(reading.spokenText)")
    }

    private func valueText(_ text: String) -> some View {
        StableText(text: text, widest: MenuBarReading.widest(for: module), alignment: .trailing)
    }
}

private struct MenuBarRate: View {
    let symbol: String
    let rate: Double
    @AppStorage(Pref.menuBarCompact) private var compact = true

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: symbol).font(.system(size: 7.5, weight: .bold))
            // Compact fits the text, so idle rates leave no gap; regular reserves room for the widest rate.
            StableText(text: Format.rate(rate), widest: compact ? Format.rate(rate) : Format.rate(88_800_000), alignment: .leading)
        }
    }
}

/// Text that always takes the width of `widest`, so changing values never resize the status item
/// and push the rest of the menu bar around.
private struct StableText: View {
    let text: String
    let widest: String
    let alignment: Alignment

    var body: some View {
        Text(widest).hidden().overlay(alignment: alignment) { Text(text).fixedSize() }
    }
}

/// What a module shows in the menu bar, independent of the style.
struct MenuBarReading: Equatable {
    var fraction = 0.0
    var text = ""
    var spokenText = ""
    var history: [Double] = []
    var status = Accent.green
    var download = 0.0
    var upload = 0.0
    var widest = ""

    init() {}

    @MainActor
    init(module: Module, monitor: Monitor) {
        switch module {
        case .cpu:
            fraction = monitor.cpu.total
            text = Format.percent(fraction)
            history = zip(monitor.cpuUser.values, monitor.cpuSystem.values).map(+)
            status = fraction >= 0.9 ? .coral : fraction >= 0.7 ? .amber : .green
        case .memory:
            fraction = monitor.memory.usedFraction
            text = Format.percent(fraction)
            history = monitor.memoryUsed.values
            status = monitor.memory.pressure.accent
        case .disk:
            let volume = monitor.volumes.first(where: \.isStartup)
            fraction = volume?.usedFraction ?? 0
            text = Format.percent(fraction)
            status = fraction >= 0.9 ? .coral : fraction >= 0.8 ? .amber : .green
        case .network:
            let top = max(monitor.download.peak, 1)
            history = monitor.download.values.map { $0 / top }
            fraction = monitor.download.last / top
            text = Format.rate(monitor.network.download)
            download = monitor.network.download
            upload = monitor.network.upload
            spokenText = "\(L("network.download")) \(Format.rate(monitor.network.download)), \(L("network.upload")) \(Format.rate(monitor.network.upload))"
        case .battery:
            fraction = monitor.battery.level
            text = Format.percent(fraction)
            status = fraction <= 0.1 ? .coral : fraction <= 0.2 ? .amber : .green
        case .sensors:
            let celsius = monitor.sensors.cpu ?? 0
            fraction = celsius / 100
            text = Format.degrees(celsius)
            spokenText = Format.temperature(celsius)
            status = celsius >= 90 ? .coral : celsius >= 75 ? .amber : .green
        }
        if spokenText.isEmpty { spokenText = text }
        widest = Self.widest(for: module)
    }

    /// The longest text a module can show, formatted in the current locale.
    static func widest(for module: Module) -> String {
        switch module {
        case .network: Format.rate(88_800_000)
        // Two digits; a rare 100% or 100° widens the item only while it lasts.
        case .sensors: Format.degrees(88)
        default: Format.percent(0.88)
        }
    }
}

private struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let top = max(values.max() ?? 1, 0.05)
            let step = size.width / CGFloat(values.count - 1)
            let points = values.enumerated().map {
                CGPoint(x: CGFloat($0.offset) * step, y: size.height - 1 - (size.height - 2) * CGFloat(min($0.element / top, 1)))
            }
            context.stroke(Path { $0.addLines(points) }, with: .color(color),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct MiniBars: View {
    let values: [Double]
    let color: Color

    var body: some View {
        // Scaled to the busiest recent sample (at least 25%) so light loads still read as bars.
        let top = max(values.max() ?? 0, 0.25)
        HStack(alignment: .bottom, spacing: 1.3) {
            ForEach(0..<6, id: \.self) { index in
                let offset = index - (6 - values.count)
                let value = offset >= 0 ? values[offset] : 0
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 2.6, height: max(2, 14 * min(value / top, 1)))
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

/// Lets clicks fall through to the status bar button underneath.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
