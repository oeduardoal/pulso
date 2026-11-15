import AppKit
import SwiftUI

/// The status item content: one small widget per module the user shows in the menu bar.
struct MenuBarView: View {
    @Environment(Monitor.self) private var monitor
    @AppStorage(Pref.menuBarOrder) private var order = ""
    @AppStorage(Pref.menuBarHidden) private var hidden = ""
    let onWidthChange: (CGFloat) -> Void

    var body: some View {
        let modules = Pref.menuBarModules(order: order, hidden: hidden).filter(Pref.isEnabled)
            .filter { $0 != .battery || monitor.battery.isPresent }
        HStack(spacing: 12) {
            if modules.isEmpty {
                Image(systemName: "waveform.path.ecg").font(.system(size: 14, weight: .medium))
            }
            ForEach(modules) { module in
                MenuBarWidget(module: module)
            }
        }
        .font(.system(size: 13, weight: .medium).monospacedDigit())
        .padding(.horizontal, 6)
        // One flattened layer instead of one per shape keeps each second's update cheap.
        .drawingGroup()
        .frame(maxHeight: .infinity)
        .fixedSize(horizontal: true, vertical: false)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { onWidthChange($0) }
        .accessibilityElement(children: .combine)
    }
}

private struct MenuBarWidget: View {
    let module: Module
    @Environment(Monitor.self) private var monitor

    private var style: MenuBarStyle {
        let stored = UserDefaults.standard.string(forKey: Pref.style(module)).flatMap(MenuBarStyle.init(rawValue:))
        return stored.flatMap { module.styles.contains($0) ? $0 : nil } ?? module.styles[0]
    }

    private var tint: Color {
        let accent = UserDefaults.standard.string(forKey: Pref.color(module)).flatMap(Accent.init(rawValue:)) ?? .monochrome
        return accent == .monochrome ? .primary : accent.base
    }

    var body: some View {
        let reading = MenuBarReading(module: module, monitor: monitor)
        HStack(spacing: 5) {
            switch style {
            case .mini:
                Text(L("menubar.\(module.rawValue)"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint == .primary ? Color.secondary : tint)
                valueText(reading.text)
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
                MenuBarRate(symbol: "arrow.down", rate: monitor.network.download)
                MenuBarRate(symbol: "arrow.up", rate: monitor.network.upload)
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
        // A minimum width keeps the menu bar from shifting as digits come and go.
        Text(text).frame(minWidth: module == .sensors ? 26 : 34, alignment: .trailing)
    }
}

private struct MenuBarRate: View {
    let symbol: String
    let rate: Double

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 9, weight: .bold))
            Text(Format.rate(rate)).frame(minWidth: 62, alignment: .trailing)
        }
    }
}

/// What a module shows in the menu bar, independent of the style.
private struct MenuBarReading {
    var fraction = 0.0
    var text = ""
    var spokenText = ""
    var history: [Double] = []
    var status = Accent.green

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
