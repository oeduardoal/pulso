import SwiftUI

struct SensorsPanel: View {
    @Environment(Monitor.self) private var monitor

    var body: some View {
        let sensors = monitor.sensors

        VStack(alignment: .leading, spacing: 12) {
            ModuleHeader(module: .sensors, subtitle: sensors.fans.isEmpty ? L("sensors.noFans") : L("sensors.fans", sensors.fans.count))

            if !sensors.isAvailable {
                Card {
                    Text(L("sensors.unavailable")).font(.system(size: 12.5)).foregroundStyle(Theme.textSecondary)
                }
            } else {
                HStack(spacing: 8) {
                    if let cpu = sensors.cpu { StatCell(label: Module.cpu.title, value: Format.temperature(cpu)) }
                    if let gpu = sensors.gpu { StatCell(label: Module.gpu, value: Format.temperature(gpu)) }
                    if let ssd = sensors.ssd ?? monitor.smart?.temperature { StatCell(label: L("overview.sensor.ssd"), value: Format.temperature(ssd)) }
                    if let battery = sensors.battery { StatCell(label: Module.battery.title, value: Format.temperature(battery)) }
                }

                if !sensors.fans.isEmpty {
                    ValueList(title: L("sensors.fansTitle"), column: L("sensors.speed"),
                              rows: sensors.fans.enumerated().map { (L("sensors.fan", $0.offset + 1), Format.rpm($0.element)) })
                }

                ValueList(title: L("sensors.all"), column: L("cpu.temperature"),
                          rows: sensors.groups.map { ($0.name, Format.temperature($0.celsius)) })
            }
        }
    }
}

private struct ValueList: View {
    let title: String
    let column: String
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(column)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(row.0).lineLimit(1)
                    Spacer()
                    Text(row.1).fontWeight(.medium).monospacedDigit()
                }
                .font(.system(size: 12.5))
                .frame(height: 26)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 8, trailing: 14))
        .background(Theme.card, in: .rect(cornerRadius: Theme.cardRadius))
    }
}
