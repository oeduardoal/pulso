import SwiftUI

struct OverviewView: View {
    @Environment(Monitor.self) private var monitor
    @Environment(\.panelActions) private var actions

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            let tiles = [Module.cpu, .memory].filter(Pref.isEnabled)
            if !tiles.isEmpty {
                HStack(spacing: 10) {
                    ForEach(tiles) { module in
                        switch module {
                        case .cpu: CPUTile()
                        default: MemoryTile()
                        }
                    }
                }
            }
            if Pref.isEnabled(.disk), let startup = monitor.volumes.first(where: \.isStartup) ?? monitor.volumes.first {
                DiskRow(volume: startup)
            }
            if Pref.isEnabled(.network) {
                NetworkRow()
            }
            if Pref.isEnabled(.battery), monitor.battery.isPresent {
                BatteryRow()
            }
            if Pref.isEnabled(.sensors), monitor.sensors.isAvailable {
                SensorCells()
            }

            HStack(spacing: 8) {
                PanelButton(title: L("action.activityMonitor")) { actions.openApp(SystemLink.activityMonitor) }
                PanelButton(title: L("action.settings")) { actions.openSettings(nil) }
            }
            .padding(.top, 2)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text(L("overview.title")).font(.system(size: 15, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                if !monitor.deviceName.isEmpty {
                    Text(L("overview.uptime", monitor.deviceName, Format.duration(monitor.uptime)))
                        .font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
            }
            Spacer()
            if let alert = monitor.alerts.active.first {
                Pill(text: alert.title, accent: alert.isCritical ? .coral : .amber)
            } else {
                Pill(text: L("overview.status.normal"), accent: .green)
            }
        }
        .padding(EdgeInsets(top: 2, leading: 4, bottom: 4, trailing: 4))
    }
}

/// Makes a whole tile or row open its module panel.
private struct OpensModule: ViewModifier {
    let module: Module
    @Environment(Monitor.self) private var monitor

    func body(content: Content) -> some View {
        Button { monitor.route = module } label: { content.contentShape(.rect(cornerRadius: Theme.cardRadius)) }
            .buttonStyle(.plain)
    }
}

extension View {
    func opens(_ module: Module) -> some View { modifier(OpensModule(module: module)) }
}

private struct TileHeader: View {
    let module: Module
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: module.symbol).font(.system(size: 12, weight: .medium))
            Text(module.title)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(module.accent.text)
    }
}

private struct CPUTile: View {
    @Environment(Monitor.self) private var monitor

    var body: some View {
        let total = zip(monitor.cpuUser.values, monitor.cpuSystem.values).map(+)
        VStack(alignment: .leading, spacing: 6) {
            TileHeader(module: .cpu)
            Text(Format.percent(monitor.cpu.total)).font(Theme.hero(32))
            Text(subtitle).font(.system(size: 11.5)).foregroundStyle(Theme.textSecondary).lineLimit(1)
            SeriesChart(lines: [.init(values: total, color: Accent.blue.base)], maximum: 1, gridlines: 0,
                        accessibilityLabel: L("cpu.chart.accessibility"))
                .frame(height: 36)
                .padding(.top, 4)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: Theme.cardRadius))
        .opens(.cpu)
    }

    private var subtitle: String {
        let cores = L("cpu.cores", CPUInfo.current.coreCount)
        guard UserDefaults.standard.bool(forKey: Pref.cpuTemperature), let celsius = monitor.sensors.cpu else { return cores }
        return L("format.pair", cores, Format.temperature(celsius))
    }
}

private struct MemoryTile: View {
    @Environment(Monitor.self) private var monitor

    var body: some View {
        let memory = monitor.memory
        VStack(alignment: .leading, spacing: 6) {
            TileHeader(module: .memory)
            Text(Format.percent(memory.usedFraction)).font(Theme.hero(32))
            Text(L("memory.usedOfShort", Format.memory(memory.used), Format.memory(memory.total)))
                .font(.system(size: 11.5)).foregroundStyle(Theme.textSecondary).lineLimit(1)
            VStack(alignment: .leading, spacing: 8) {
                MemoryBar(memory: memory, height: 8)
                HStack(spacing: 5) {
                    LegendDot(color: memory.pressure.accent.base, size: 6)
                    Text(memory.pressure.title).lineLimit(1)
                }
                .font(.system(size: 11.5)).foregroundStyle(Theme.textSecondary)
            }
            .frame(height: 36, alignment: .bottom)
            .padding(.top, 4)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: Theme.cardRadius))
        .opens(.memory)
    }
}

/// Apps, wired and compressed memory as one segmented bar over the total.
struct MemoryBar: View {
    let memory: MemoryReading
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let total = Double(max(memory.total, 1))
            let segments: [(UInt64, Color)] = [(memory.app, Accent.teal.base), (memory.wired, Accent.amber.base), (memory.compressed, Accent.blue.base)]
            HStack(spacing: 2) {
                ForEach(segments.indices, id: \.self) { index in
                    let (bytes, color) = segments[index]
                    Rectangle().fill(color).frame(width: max(0, proxy.size.width * Double(bytes) / total - 2))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: height)
        .background(Theme.track)
        .clipShape(.capsule)
        .accessibilityHidden(true)
    }
}

private struct RowLayout<Trailing: View>: View {
    let module: Module
    let title: String
    let subtitle: String?
    var progress: Double?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: module.symbol, accent: module.accent, size: 30, radius: 9, fillOpacity: 0.18)
            VStack(alignment: .leading, spacing: progress == nil ? 0 : 6) {
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                if let progress {
                    ProgressTrack(fraction: progress, color: module.accent.base)
                }
                if let subtitle {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
        .frame(minHeight: 56)
        .background(Theme.card, in: .rect(cornerRadius: Theme.cardRadius))
        .accessibilityElement(children: .combine)
        .opens(module)
    }
}

private struct DiskRow: View {
    let volume: Volume

    var body: some View {
        RowLayout(module: .disk, title: volume.name, subtitle: nil, progress: volume.usedFraction) {
            VStack(alignment: .trailing, spacing: 0) {
                Text(Format.storage(volume.free)).font(.system(size: 13, weight: .semibold).monospacedDigit())
                Text(L("disk.freeOf", Format.storage(volume.total))).font(.system(size: 11.5)).foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

private struct NetworkRow: View {
    @Environment(Monitor.self) private var monitor

    var body: some View {
        let network = monitor.network
        RowLayout(module: .network,
                  title: network.interfaceName ?? Module.network.title,
                  subtitle: network.isConnected ? network.localIP : L("network.offline")) {
            if network.isConnected {
                VStack(alignment: .trailing, spacing: 0) {
                    RateLabel(symbol: "arrow.down", color: Accent.blue.text, rate: network.download)
                    RateLabel(symbol: "arrow.up", color: Accent.orange.text, rate: network.upload)
                }
                .font(.system(size: 12, weight: .medium).monospacedDigit())
            }
        }
    }
}

struct RateLabel: View {
    let symbol: String
    let color: Color
    let rate: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 9, weight: .bold)).foregroundStyle(color)
            Text(Format.rate(rate))
        }
    }
}

private struct BatteryRow: View {
    @Environment(Monitor.self) private var monitor

    var body: some View {
        let battery = monitor.battery
        RowLayout(module: .battery, title: Module.battery.title, subtitle: BatteryText.status(battery)) {
            HStack(spacing: 8) {
                BatteryGlyph(level: battery.level, color: Accent.green.base)
                Text(Format.percent(battery.level))
            }
            .font(.system(size: 13, weight: .semibold).monospacedDigit())
        }
    }
}

enum BatteryText {
    static func status(_ battery: BatteryReading) -> String {
        if let remaining = battery.timeRemaining { return L("battery.timeRemaining", Format.duration(remaining)) }
        if let full = battery.timeToFull { return L("battery.untilFull", Format.duration(full)) }
        if battery.isCharging { return L("battery.charging") }
        return battery.isPluggedIn ? L("battery.pluggedIn") : L("battery.onBattery")
    }
}

/// Horizontal battery outline with a fill, as in the overview row and the battery menu bar style.
struct BatteryGlyph: View {
    let level: Double
    let color: Color
    var width: CGFloat = 24
    var height: CGFloat = 12

    var body: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.5).strokeBorder(.white.opacity(0.55), lineWidth: 1)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: max(2, (width - 4) * min(max(level, 0), 1)))
                    .padding(2)
            }
            .frame(width: width, height: height)
            RoundedRectangle(cornerRadius: 1).fill(.white.opacity(0.55)).frame(width: 1.5, height: height * 0.4)
        }
        .accessibilityHidden(true)
    }
}

private struct SensorCells: View {
    @Environment(Monitor.self) private var monitor

    var body: some View {
        let sensors = monitor.sensors
        var cells: [(String, String)] = []
        if let cpu = sensors.cpu { cells.append((Module.cpu.title, Format.temperature(cpu))) }
        if let gpu = sensors.gpu { cells.append((Module.gpu, Format.temperature(gpu))) }
        if let ssd = sensors.ssd ?? monitor.smart?.temperature { cells.append((L("overview.sensor.ssd"), Format.temperature(ssd))) }
        if let fan = sensors.fans.first {
            cells.append((L("overview.sensor.fan"), Format.rpm(fan)))
        } else if let battery = sensors.battery {
            cells.append((Module.battery.title, Format.temperature(battery)))
        }
        return HStack(spacing: 8) {
            ForEach(cells, id: \.0) { cell in
                StatCell(label: cell.0, value: cell.1, valueSize: 14, padding: EdgeInsets(top: 9, leading: 10, bottom: 9, trailing: 10))
            }
        }
        .opens(.sensors)
    }
}

extension Module {
    /// GPU is not a module of its own; its label lives with the CPU readings.
    static var gpu: String { L("module.gpu") }
}
