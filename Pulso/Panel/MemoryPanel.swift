import SwiftUI

struct MemoryPanel: View {
    @Environment(Monitor.self) private var monitor
    @Environment(\.panelActions) private var actions

    var body: some View {
        let memory = monitor.memory

        VStack(alignment: .leading, spacing: 12) {
            ModuleHeader(module: .memory, subtitle: L("memory.subtitle", Format.memory(memory.total)))

            Card(spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Format.memory(memory.used)).font(Theme.hero()).frame(height: 52)
                        Text(L("memory.usedOf", Format.memory(memory.total), Format.percent(memory.usedFraction)))
                            .font(.system(size: 12.5)).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Pill(text: memory.pressure.title, accent: memory.pressure.accent)
                }
                MemoryBar(memory: memory, height: 12)
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                    GridRow {
                        BreakdownItem(color: Accent.teal.base, label: L("memory.apps"), value: memory.app)
                        BreakdownItem(color: Accent.amber.base, label: L("memory.wired"), value: memory.wired)
                    }
                    GridRow {
                        BreakdownItem(color: Accent.blue.base, label: L("memory.compressed"), value: memory.compressed)
                        BreakdownItem(color: .white.opacity(0.3), label: L("memory.available"), value: memory.available)
                    }
                }
            }

            Card {
                HStack {
                    SectionLabel(text: L("memory.pressure.title"))
                    Spacer()
                    SectionLabel(text: L("chart.last60s"))
                }
                SeriesChart(lines: [.init(values: monitor.memoryPressure.values, color: memory.pressure.accent.base)],
                            maximum: 1,
                            accessibilityLabel: "\(L("memory.pressure.title")), \(L("chart.last60s")): \(memory.pressure.title)")
                    .frame(height: 64)
            }

            HStack(spacing: 8) {
                StatCell(label: L("memory.swapUsed"), value: Format.memory(memory.swapUsed))
                StatCell(label: L("memory.cached"), value: Format.memory(memory.cached))
                StatCell(label: L("memory.free"), value: Format.memory(memory.free))
            }

            ProcessList(column: L("memory.column"),
                        rows: ProcessList.rows(monitor.topProcesses, value: { Double($0.memory) }) { Format.memory($0.memory) },
                        color: Accent.teal.base, valueWidth: 64)

            PanelButton(title: L("action.openActivityMonitor")) { actions.openApp(SystemLink.activityMonitor) }
        }
    }
}

private struct BreakdownItem: View {
    let color: Color
    let label: String
    let value: UInt64

    var body: some View {
        HStack(spacing: 6) {
            LegendDot(color: color)
            Text(label).foregroundStyle(Theme.textSecondary).lineLimit(1).layoutPriority(1)
            Spacer(minLength: 4)
            Text(Format.memory(value)).fontWeight(.semibold).monospacedDigit().fixedSize()
        }
        .font(.system(size: 12.5))
        .accessibilityElement(children: .combine)
    }
}
