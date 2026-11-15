import SwiftUI

struct DiskPanel: View {
    @Environment(Monitor.self) private var monitor
    @Environment(\.panelActions) private var actions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ModuleHeader(module: .disk, subtitle: L("disk.volumesConnected", monitor.volumes.count))

            ForEach(monitor.volumes) { volume in
                VolumeCard(volume: volume)
            }

            Card {
                HStack(spacing: 10) {
                    SectionLabel(text: L("disk.activity"))
                    Spacer()
                    RateLegend(color: Accent.blue.base, label: L("disk.read"), rate: monitor.diskRead.last)
                    RateLegend(color: Accent.orange.base, label: L("disk.write"), rate: monitor.diskWrite.last)
                }
                SeriesChart(
                    lines: [
                        .init(values: monitor.diskRead.values, color: Accent.blue.base),
                        .init(values: monitor.diskWrite.values, color: Accent.orange.base, lineWidth: 1.8, fill: false),
                    ],
                    accessibilityLabel: "\(L("disk.readAndWrite")), \(L("chart.last60s")): \(Format.rate(monitor.diskRead.last)), \(Format.rate(monitor.diskWrite.last))"
                )
                .frame(height: 64)
            }

            if let smart = monitor.smart {
                HStack(spacing: 8) {
                    StatCell(label: L("disk.smart"), value: smart.healthy ? L("disk.smart.verified") : L("disk.smart.failing"))
                    StatCell(label: L("cpu.temperature"), value: Format.temperature(smart.temperature))
                    StatCell(label: L("disk.wear"), value: Format.percent(smart.wear))
                }
            }

            ProcessList(column: L("disk.readAndWrite"),
                        rows: ProcessList.rows(monitor.topProcesses, value: \.diskBytesPerSecond) { Format.rate($0.diskBytesPerSecond) },
                        color: Accent.amber.base, valueWidth: 80)

            PanelButton(title: L("action.openDiskUtility")) { actions.openApp(SystemLink.diskUtility) }
        }
    }
}

private struct VolumeCard: View {
    let volume: Volume

    var body: some View {
        Card(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(volume.name).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                    Text(volume.detail).font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
                Spacer()
                if volume.isStartup {
                    Text(L("disk.startup"))
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10).frame(height: 24)
                        .background(Theme.control, in: .capsule)
                } else if volume.isEjectable {
                    Button { DiskSampler.eject(volume) } label: {
                        Image(systemName: "eject.fill")
                            .font(.system(size: 11))
                            .frame(width: 30, height: 30)
                            .background(Theme.control, in: .circle)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("action.eject", volume.name))
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Format.storage(volume.free)).font(Theme.hero(28))
                Text(L("disk.free")).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
            }
            ProgressTrack(fraction: volume.usedFraction, color: Accent.amber.base, height: 10)
            HStack {
                Text(L("disk.used", Format.storage(volume.used)))
                Spacer()
                Text(L("disk.total", Format.storage(volume.total)))
            }
            .font(.system(size: 12)).foregroundStyle(Theme.textSecondary).monospacedDigit()
        }
        .accessibilityElement(children: .contain)
    }
}

struct RateLegend: View {
    let color: Color
    let label: String
    let rate: Double

    var body: some View {
        HStack(spacing: 5) {
            LegendDot(color: color)
            Text(label).foregroundStyle(Theme.textSecondary)
            Text(Format.rate(rate)).fontWeight(.semibold).monospacedDigit()
        }
        .font(.system(size: 12))
        .accessibilityElement(children: .combine)
    }
}
