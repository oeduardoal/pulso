import AppKit
import SwiftUI

struct NetworkPanel: View {
    @Environment(Monitor.self) private var monitor
    @Environment(\.panelActions) private var actions
    @AppStorage(Pref.publicIP) private var showPublicIP = false

    var body: some View {
        let network = monitor.network
        let peak = monitor.download.peak

        VStack(alignment: .leading, spacing: 12) {
            ModuleHeader(module: .network, subtitle: network.interfaceName ?? L("network.offline"))

            Card {
                HStack(alignment: .top, spacing: 0) {
                    Direction(symbol: "arrow.down", label: L("network.download"), color: Accent.blue.text, rate: network.download)
                    Direction(symbol: "arrow.up", label: L("network.upload"), color: Accent.orange.text, rate: network.upload)
                }
                MirroredChart(up: monitor.download.values, down: monitor.upload.values,
                              upColor: Accent.blue.base, downColor: Accent.orange.base,
                              accessibilityLabel: L("network.chart.accessibility"))
                    .frame(height: 96)
                    .padding(.vertical, 8)
                ChartFooter(trailing: L("chart.peak", Format.rate(peak)))
            }

            VStack(spacing: 0) {
                InfoRow(label: L("network.localIP"), value: network.localIP, copyLabel: L("action.copyLocalIP"))
                if showPublicIP {
                    Divider().overlay(Theme.separator)
                    InfoRow(label: L("network.publicIP"), value: monitor.publicIP, copyLabel: L("action.copyPublicIP"))
                }
                Divider().overlay(Theme.separator)
                InfoRow(label: L("network.interface"),
                        value: network.interface.map { bsd in network.wifiStandard.map { L("format.pair", bsd, $0) } ?? bsd })
                Divider().overlay(Theme.separator)
                InfoRow(label: L("network.latency"), value: monitor.latency.map(Format.milliseconds))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(Theme.card, in: .rect(cornerRadius: Theme.cardRadius))

            HStack(spacing: 8) {
                StatCell(label: L("network.downloadedToday"), value: Format.storage(network.downloadedToday))
                StatCell(label: L("network.uploadedToday"), value: Format.storage(network.uploadedToday))
            }

            ProcessList(column: L("network.traffic"),
                        rows: ProcessList.rows(monitor.topProcesses, value: \.networkBytesPerSecond) { Format.rate($0.networkBytesPerSecond) },
                        color: Accent.blue.base, valueWidth: 80)

            PanelButton(title: L("action.openNetworkSettings")) { actions.open(SystemLink.networkSettings) }
        }
    }
}

private struct Direction: View {
    let symbol: String
    let label: String
    let color: Color
    let rate: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                Text(label)
            }
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(color)
            Text(Format.rate(rate)).font(Theme.hero(32)).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String?
    var copyLabel: String?

    var body: some View {
        HStack(spacing: 10) {
            Text(label).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value ?? "–").fontWeight(.medium).monospacedDigit().textSelection(.enabled)
            if let copyLabel, let value {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .frame(width: 24, height: 24)
                        .background(Theme.control, in: .rect(cornerRadius: 7))
                        .contentShape(.rect(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copyLabel)
            }
        }
        .font(.system(size: 12.5))
        .frame(height: 34)
    }
}
