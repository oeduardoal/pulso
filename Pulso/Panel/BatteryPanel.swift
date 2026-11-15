import SwiftUI

struct BatteryPanel: View {
    @Environment(Monitor.self) private var monitor
    @Environment(\.panelActions) private var actions
    @AppStorage(Pref.bluetooth) private var showBluetooth = true

    var body: some View {
        let battery = monitor.battery

        VStack(alignment: .leading, spacing: 12) {
            ModuleHeader(module: .battery, subtitle: subtitle(battery))

            if battery.isPresent {
                Card(spacing: 12) {
                    HStack(alignment: .top) {
                        Text(Format.percent(battery.level)).font(Theme.hero()).frame(height: 52)
                        Spacer()
                        if let remaining = battery.timeRemaining {
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(Format.duration(remaining)).font(.system(size: 15, weight: .semibold).monospacedDigit())
                                Text(L("battery.remaining")).font(.system(size: 12.5)).foregroundStyle(Theme.textSecondary)
                            }
                            .padding(.top, 6)
                        } else if let full = battery.timeToFull {
                            Text(L("battery.untilFull", Format.duration(full)))
                                .font(.system(size: 12.5)).foregroundStyle(Theme.textSecondary).padding(.top, 6)
                        }
                    }
                    BigBattery(level: battery.level, color: battery.level <= 0.2 && !battery.isPluggedIn ? Accent.amber.base : Accent.green.base)
                    if let lastFull = monitor.lastFullCharge {
                        Text(L("battery.lastFullCharge", Format.relativeDateTime(lastFull)))
                            .font(.system(size: 12.5)).foregroundStyle(Theme.textSecondary)
                    }
                }

                Card {
                    SectionLabel(text: L("battery.levelHistory"))
                    HistoryChart(points: monitor.batteryHistory)
                }

                HStack(spacing: 8) {
                    if let health = battery.health { StatCell(label: L("battery.health"), value: Format.percent(health)) }
                    if let cycles = battery.cycles { StatCell(label: L("battery.cycles"), value: Format.integer(cycles)) }
                    if let celsius = battery.temperature ?? monitor.sensors.battery {
                        StatCell(label: L("battery.temperatureShort"), value: Format.temperature(celsius))
                    }
                    if let power = battery.power { StatCell(label: L("battery.power"), value: Format.watts(power)) }
                }

                LowPowerModeRow(isOn: battery.isLowPowerMode) { actions.open(SystemLink.batterySettings) }
            } else {
                Card {
                    Text(L("battery.none")).font(.system(size: 12.5)).foregroundStyle(Theme.textSecondary)
                }
            }

            if showBluetooth, !monitor.bluetooth.isEmpty {
                ProcessList(
                    title: L("battery.bluetoothDevices"),
                    column: L("battery.charge"),
                    rows: monitor.bluetooth.enumerated().map { index, device in
                        ProcessRow(id: pid_t(index), name: device.name, fraction: device.level, value: Format.percent(device.level))
                    },
                    color: Accent.green.base
                )
            }

            PanelButton(title: L("action.openBatterySettings")) { actions.open(SystemLink.batterySettings) }
        }
    }

    private func subtitle(_ battery: BatteryReading) -> String {
        guard battery.isPresent else { return L("battery.none.short") }
        if battery.isCharging { return L("battery.charging") }
        return battery.isPluggedIn ? L("battery.pluggedIn") : L("battery.onBattery")
    }
}

private struct BigBattery: View {
    let level: Double
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 9).fill(Theme.track)
                    RoundedRectangle(cornerRadius: 6).fill(color)
                        .frame(width: max(8, (proxy.size.width - 6) * min(max(level, 0), 1)))
                        .padding(3)
                }
            }
            RoundedRectangle(cornerRadius: 2).fill(Theme.track).frame(width: 4, height: 10)
        }
        .frame(height: 26)
        .accessibilityHidden(true)
    }
}

/// Battery level over the last 12 hours, plotted against time so gaps while Pulso was not running stay visible.
private struct HistoryChart: View {
    let points: [BatteryHistoryPoint]

    var body: some View {
        let now = Date()
        let start = now.addingTimeInterval(-BatterySampler.historyWindow)
        VStack(spacing: 6) {
            Canvas { context, size in
                for index in 1...3 {
                    let y = size.height * CGFloat(index) / 4
                    context.stroke(Path { $0.move(to: CGPoint(x: 0, y: y)); $0.addLine(to: CGPoint(x: size.width, y: y)) },
                                   with: .color(Theme.gridline), lineWidth: 1)
                }
                let mapped = points.map { point in
                    CGPoint(x: size.width * CGFloat(point.date.timeIntervalSince(start) / BatterySampler.historyWindow),
                            y: size.height * (1 - CGFloat(point.level)))
                }
                guard mapped.count > 1, let first = mapped.first, let last = mapped.last else { return }
                var area = Path()
                area.move(to: CGPoint(x: first.x, y: size.height))
                mapped.forEach { area.addLine(to: $0) }
                area.addLine(to: CGPoint(x: last.x, y: size.height))
                context.fill(area, with: .color(Accent.green.base.opacity(0.2)))
                context.stroke(Path { $0.addLines(mapped) }, with: .color(Accent.green.base),
                               style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 64)
            HStack {
                Text(Format.time(start))
                Spacer()
                Text(Format.time(start.addingTimeInterval(BatterySampler.historyWindow / 2)))
                Spacer()
                Text(Format.time(now))
            }
            .font(.system(size: 11.5)).foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("battery.levelHistory"))
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        guard let first = points.first, let last = points.last else { return "" }
        return L("battery.history.accessibility", Format.percent(first.level), Format.time(first.date), Format.percent(last.level))
    }
}

private struct LowPowerModeRow: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("battery.lowPowerMode")).font(.system(size: 13, weight: .semibold))
                    Text(L("battery.lowPowerMode.detail")).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                SwitchIndicator(isOn: isOn)
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            .background(Theme.card, in: .rect(cornerRadius: Theme.cardRadius))
            .contentShape(.rect(cornerRadius: Theme.cardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("battery.lowPowerMode"))
        .accessibilityValue(isOn ? L("state.on") : L("state.off"))
        .accessibilityHint(L("battery.lowPowerMode.hint"))
    }
}

/// Visual switch that reflects state it cannot change itself.
struct SwitchIndicator: View {
    let isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? Theme.switchOn : Color.white.opacity(0.22))
            .frame(width: 38, height: 22)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle().fill(.white).frame(width: 18, height: 18).padding(2)
            }
            .accessibilityHidden(true)
    }
}
