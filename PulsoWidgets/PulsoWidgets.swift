import SwiftUI
import WidgetKit

@main
struct PulsoWidgetBundle: WidgetBundle {
    var body: some Widget {
        CPUWidget()
        MemoryWidget()
        NetworkWidget()
    }
}

// MARK: - Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Reads the snapshot the app writes to the app group. WidgetKit budgets refreshes, so the app
/// asks for a reload about once a minute and the widget shows when its data was taken.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let snapshot = context.isPreview ? .placeholder : (WidgetSnapshot.load() ?? .placeholder)
        completion(SnapshotEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .placeholder)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60))))
    }
}

// MARK: - Widgets

struct CPUWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.edew.pulso.cpu", provider: SnapshotProvider()) { entry in
            GaugeWidgetView(
                title: L("module.cpu"),
                fraction: entry.snapshot.cpu,
                caption: cpuCaption(entry.snapshot),
                accent: .blue,
                updated: entry.snapshot.date
            )
        }
        .configurationDisplayName(L("module.cpu"))
        .description(L("widget.cpu.description"))
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }

    private func cpuCaption(_ snapshot: WidgetSnapshot) -> String {
        let cores = L("cpu.cores", snapshot.coreCount)
        guard let celsius = snapshot.cpuTemperature else { return cores }
        return L("format.pair", Format.temperature(celsius), cores)
    }
}

struct MemoryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.edew.pulso.memory", provider: SnapshotProvider()) { entry in
            GaugeWidgetView(
                title: L("module.memory"),
                fraction: entry.snapshot.memoryFraction,
                caption: L("memory.usedOfShort", Format.memory(entry.snapshot.memoryUsed), Format.memory(entry.snapshot.memoryTotal)),
                accent: .teal,
                updated: entry.snapshot.date
            )
        }
        .configurationDisplayName(L("module.memory"))
        .description(L("widget.memory.description"))
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct NetworkWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.edew.pulso.network", provider: SnapshotProvider()) { entry in
            NetworkWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName(L("module.network"))
        .description(L("widget.network.description"))
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Views

private let secondary = Color.white.opacity(0.7)

private struct WidgetBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(.white.opacity(0.96))
            .environment(\.colorScheme, .dark)
            .containerBackground(for: .widget) {
                Color(.sRGB, red: 10 / 255, green: 18 / 255, blue: 40 / 255, opacity: 0.6)
            }
    }
}

private struct UpdatedLabel: View {
    let date: Date
    var body: some View {
        Text(L("widget.updated", Format.time(date)))
            .font(.system(size: 10))
            .foregroundStyle(secondary)
    }
}

struct GaugeWidgetView: View {
    let title: String
    let fraction: Double
    let caption: String
    let accent: Accent
    let updated: Date

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer()
                UpdatedLabel(date: updated)
            }
            Spacer(minLength: 4)
            ZStack {
                Circle().stroke(.white.opacity(0.14), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: min(max(fraction, 0), 1))
                    .stroke(accent.base, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(Format.percent(fraction))
                    .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
            }
            .frame(width: 84, height: 84)
            Spacer(minLength: 4)
            Text(caption).font(.system(size: 11.5)).foregroundStyle(secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(16)
        .modifier(WidgetBackground())
        .accessibilityElement(children: .combine)
    }
}

struct NetworkWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text(snapshot.interfaceName.map { L("format.pair", L("module.network"), $0) } ?? L("module.network"))
                    .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                UpdatedLabel(date: snapshot.date)
                Spacer(minLength: 4)
                rate(symbol: "arrow.down", label: L("network.download"), color: Accent.blue.text, value: snapshot.download)
                rate(symbol: "arrow.up", label: L("network.upload"), color: Accent.orange.text, value: snapshot.upload)
                    .padding(.top, 6)
            }
            .frame(width: 118, alignment: .leading)
            Canvas { context, size in
                let top = max((snapshot.downloadHistory + snapshot.uploadHistory).max() ?? 1, 1) * 1.1
                func points(_ values: [Double]) -> [CGPoint] {
                    let step = size.width / CGFloat(max(values.count - 1, 1))
                    return values.enumerated().map { CGPoint(x: CGFloat($0.offset) * step, y: size.height * (1 - CGFloat($0.element / top))) }
                }
                let down = points(snapshot.downloadHistory)
                if let first = down.first, let last = down.last {
                    var area = Path()
                    area.move(to: CGPoint(x: first.x, y: size.height))
                    down.forEach { area.addLine(to: $0) }
                    area.addLine(to: CGPoint(x: last.x, y: size.height))
                    context.fill(area, with: .color(Accent.blue.base.opacity(0.3)))
                    context.stroke(Path { $0.addLines(down) }, with: .color(Accent.blue.base), lineWidth: 2)
                }
                context.stroke(Path { $0.addLines(points(snapshot.uploadHistory)) }, with: .color(Accent.orange.base), lineWidth: 1.8)
            }
            .accessibilityHidden(true)
        }
        .padding(16)
        .modifier(WidgetBackground())
        .accessibilityElement(children: .combine)
    }

    private func rate(symbol: String, label: String, color: Color, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 9, weight: .bold))
                Text(label)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            Text(Format.rate(value)).font(.system(size: 22, weight: .semibold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}
