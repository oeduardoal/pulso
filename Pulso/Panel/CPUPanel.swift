import SwiftUI

struct CPUPanel: View {
    @Environment(Monitor.self) private var monitor
    @Environment(\.panelActions) private var actions
    @AppStorage(Pref.cpuPerCore) private var showPerCore = true
    @AppStorage(Pref.cpuTemperature) private var showTemperature = true

    var body: some View {
        let cpu = monitor.cpu
        let info = CPUInfo.current
        let total = zip(monitor.cpuUser.values, monitor.cpuSystem.values).map(+)
        let peak = total.max() ?? 0

        VStack(alignment: .leading, spacing: 12) {
            ModuleHeader(module: .cpu, subtitle: L("cpu.subtitle", info.chip, info.coreCount))

            Card {
                HStack(alignment: .center) {
                    Text(Format.percent(cpu.total)).font(Theme.hero()).frame(height: 52)
                    Spacer()
                    VStack(alignment: .leading, spacing: 3) {
                        LegendRow(color: Accent.blue.base, label: L("cpu.user"), value: Format.percent(cpu.user))
                        LegendRow(color: Accent.orange.base, label: L("cpu.system"), value: Format.percent(cpu.system))
                        LegendRow(color: .white.opacity(0.3), label: L("cpu.idle"), value: Format.percent(cpu.idle))
                    }
                }
                SeriesChart(
                    lines: [
                        .init(values: total, color: Accent.blue.base),
                        .init(values: monitor.cpuSystem.values, color: Accent.orange.base, lineWidth: 1.8, fill: false),
                    ],
                    maximum: 1,
                    accessibilityLabel: "\(L("cpu.chart.accessibility")). \(L("chart.peak", Format.percent(peak)))"
                )
                .frame(height: 84)
                ChartFooter(trailing: L("chart.peak", Format.percent(peak)))
            }

            if showPerCore, !cpu.cores.isEmpty {
                Card(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14), spacing: 8) {
                    SectionLabel(text: L("cpu.perCore"))
                    HStack(alignment: .top, spacing: 16) {
                        let efficiency = min(info.efficiencyCount, cpu.cores.count)
                        CoreGroup(values: Array(cpu.cores[efficiency...]), color: Accent.blue.base,
                                  label: L("cpu.performanceCores", cpu.cores.count - efficiency))
                        if efficiency > 0 {
                            CoreGroup(values: Array(cpu.cores[..<efficiency]), color: Accent.teal.base,
                                      label: L("cpu.efficiencyCores", efficiency))
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                if showTemperature, let celsius = monitor.sensors.cpu {
                    StatCell(label: L("cpu.temperature"), value: Format.temperature(celsius))
                }
                StatCell(label: L("cpu.loadAverage"), value: Format.number(cpu.loadAverage, digits: 2))
                if let gpu = cpu.gpu {
                    StatCell(label: Module.gpu, value: Format.percent(gpu))
                }
            }

            ProcessList(column: L("cpu.column.percent"),
                        rows: ProcessList.rows(monitor.topProcesses, value: \.cpu) { Format.points($0.cpu) },
                        color: Accent.blue.base)

            PanelButton(title: L("action.openActivityMonitor")) { actions.openApp(SystemLink.activityMonitor) }
        }
    }
}

struct LegendRow: View {
    let color: Color
    let label: String
    let value: String
    var labelWidth: CGFloat = 56

    var body: some View {
        HStack(spacing: 6) {
            LegendDot(color: color)
            Text(label).foregroundStyle(Theme.textSecondary).frame(minWidth: labelWidth, alignment: .leading)
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
        .font(.system(size: 12))
        .accessibilityElement(children: .combine)
    }
}

struct ChartFooter: View {
    var leading = L("chart.last60s")
    let trailing: String

    var body: some View {
        HStack {
            Text(leading)
            Spacer()
            Text(trailing).monospacedDigit()
        }
        .font(.system(size: 11.5))
        .foregroundStyle(Theme.textSecondary)
    }
}

private struct CoreGroup: View {
    let values: [Double]
    let color: Color
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(values.indices, id: \.self) { index in
                    GeometryReader { proxy in
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.1))
                            RoundedRectangle(cornerRadius: 4).fill(color)
                                .frame(height: max(4, proxy.size.height * min(values[index], 1)))
                        }
                    }
                }
            }
            .frame(height: 56)
            Text(label).font(.system(size: 11.5)).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(values.map { Format.percent($0) }.joined(separator: ", "))
    }
}
