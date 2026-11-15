import AppKit
import SwiftUI

struct Card<Content: View>: View {
    var padding = EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
    var spacing: CGFloat = 10
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: Theme.cardRadius))
    }
}

struct StatCell: View {
    let label: String
    let value: String
    var valueSize: CGFloat = 15
    var padding = EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 11.5)).foregroundStyle(Theme.textSecondary).lineLimit(1)
            Text(value).font(.system(size: valueSize, weight: .semibold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: Theme.statRadius))
        .accessibilityElement(children: .combine)
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textSecondary)
    }
}

struct ProgressTrack: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule().fill(color).frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

struct IconTile: View {
    let symbol: String
    let accent: Accent
    var size: CGFloat = 36
    var radius: CGFloat = 10
    var fillOpacity = 0.2

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .medium))
            .foregroundStyle(accent.text)
            .frame(width: size, height: size)
            .background(accent.base.opacity(fillOpacity), in: .rect(cornerRadius: radius))
            .accessibilityHidden(true)
    }
}

struct Pill: View {
    let text: String
    let accent: Accent

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(accent.base).frame(width: 6, height: 6)
            Text(text).lineLimit(1)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(accent.text)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(accent.base.opacity(0.16), in: .capsule)
    }
}

struct LegendDot: View {
    let color: Color
    var size: CGFloat = 8
    var body: some View { Circle().fill(color).frame(width: size, height: size) }
}

struct PanelButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(Theme.control, in: .rect(cornerRadius: Theme.buttonRadius))
                .contentShape(.rect(cornerRadius: Theme.buttonRadius))
        }
        .buttonStyle(.plain)
    }
}

/// Header of a module panel: back to the overview, module settings, icon and title.
struct ModuleHeader: View {
    let module: Module
    let subtitle: String
    @Environment(Monitor.self) private var monitor
    @Environment(\.panelActions) private var actions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { monitor.route = nil } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                        Text(L("overview.title"))
                    }
                    .font(.system(size: 12.5, weight: .medium))
                    .padding(.leading, 6).padding(.trailing, 12)
                    .frame(height: 28)
                    .background(Theme.chip, in: .capsule)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.leftArrow, modifiers: .command)
                Spacer()
                Button { actions.openSettings(module) } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 28, height: 28)
                        .background(Theme.chip, in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("action.moduleSettings"))
            }
            HStack(spacing: 12) {
                IconTile(symbol: module.symbol, accent: module.accent)
                VStack(alignment: .leading, spacing: 0) {
                    Text(module.title).font(.system(size: 17, weight: .semibold))
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
    }
}

struct ProcessRow: Identifiable {
    let id: pid_t
    let name: String
    let fraction: Double
    let value: String
}

/// Top processes with a usage bar, as in the module panels.
struct ProcessList: View {
    var title = L("processes.title")
    let column: String
    let rows: [ProcessRow]
    let color: Color
    var valueWidth: CGFloat = 40
    var barWidth: CGFloat = 72

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                    Spacer()
                    Text(column)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                ForEach(rows) { row in
                    HStack(spacing: 10) {
                        Text(row.name).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 0)
                        ProgressTrack(fraction: row.fraction, color: color).frame(width: barWidth)
                        Text(row.value).fontWeight(.medium).monospacedDigit()
                            .frame(minWidth: valueWidth, alignment: .trailing)
                    }
                    .font(.system(size: 12.5))
                    .frame(height: 26)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(row.name), \(row.value)")
                }
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 8, trailing: 14))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: Theme.cardRadius))
        }
    }

    static func rows(_ processes: [ProcessUsage], value: (ProcessUsage) -> Double, format: (ProcessUsage) -> String) -> [ProcessRow] {
        let top = processes.map(value).max() ?? 0
        return processes.map { ProcessRow(id: $0.pid, name: $0.name, fraction: top > 0 ? value($0) / top : 0, value: format($0)) }
    }
}

// MARK: - Environment

/// What views inside the panel can ask the window to do.
struct PanelActions {
    var openSettings: @MainActor (Module?) -> Void = { _ in }
    var close: @MainActor () -> Void = {}

    @MainActor
    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
        close()
    }

    @MainActor
    func openApp(_ bundleIdentifier: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
        close()
    }
}

enum SystemLink {
    static let activityMonitor = "com.apple.ActivityMonitor"
    static let diskUtility = "com.apple.DiskUtility"
    static let networkSettings = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension")!
    static let batterySettings = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension")!
}

extension EnvironmentValues {
    @Entry var panelActions = PanelActions()
}
