import Observation
import SwiftUI

enum SettingsPane: Hashable {
    case general, menuBar, alerts, widgets
    case module(Module)
    case bluetooth

    static let top: [SettingsPane] = [.general, .menuBar, .alerts, .widgets]
    static let modules: [SettingsPane] = Module.allCases.map(SettingsPane.module) + [.bluetooth]

    var title: String {
        switch self {
        case .general: L("settings.general")
        case .menuBar: L("settings.menuBar")
        case .alerts: L("settings.alerts")
        case .widgets: L("settings.widgets")
        case .module(let module): module.title
        case .bluetooth: L("module.bluetooth")
        }
    }

    var symbol: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .menuBar: "menubar.rectangle"
        case .alerts: "bell"
        case .widgets: "square.grid.2x2"
        case .module(let module): module.symbol
        case .bluetooth: "dot.radiowaves.left.and.right"
        }
    }

    var accent: Accent? {
        if case .module(let module) = self { return module.accent }
        return nil
    }
}

@MainActor
@Observable
final class SettingsRouter {
    static let shared = SettingsRouter()
    var selection: SettingsPane = .general
}

struct SettingsView: View {
    @Environment(SettingsRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationSplitView {
            List(selection: $router.selection) {
                ForEach(SettingsPane.top, id: \.self) { SidebarRow(pane: $0) }
                Section(L("settings.modules")) {
                    ForEach(SettingsPane.modules, id: \.self) { SidebarRow(pane: $0) }
                }
            }
            .navigationSplitViewColumnWidth(216)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            ScrollView {
                pane(router.selection)
                    .padding(EdgeInsets(top: 20, leading: 24, bottom: 24, trailing: 24))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Theme.settingsContent)
        }
        .frame(width: 820, height: 560)
        .preferredColorScheme(.dark)
        .tint(Accent.blue.base)
    }

    @ViewBuilder
    private func pane(_ pane: SettingsPane) -> some View {
        switch pane {
        case .general: GeneralPane()
        case .menuBar: MenuBarPane()
        case .alerts: AlertsPane()
        case .widgets: WidgetsPane()
        case .module(let module): ModulePane(module: module)
        case .bluetooth: BluetoothPane()
        }
    }
}

private struct SidebarRow: View {
    let pane: SettingsPane

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: pane.symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(pane.accent?.text ?? .white)
                .frame(width: 20, height: 20)
                .background(pane.accent.map { $0.base.opacity(0.24) } ?? .white.opacity(0.16), in: .rect(cornerRadius: 6))
            Text(pane.title).font(.system(size: 13))
        }
        .frame(height: 26)
        .tag(pane)
    }
}

// MARK: - Building blocks

struct SettingsHeader<Trailing: View>: View {
    let symbol: String
    let accent: Accent?
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(accent?.text ?? .white)
                .frame(width: 36, height: 36)
                .background(accent.map { $0.base.opacity(0.2) } ?? .white.opacity(0.16), in: .rect(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.system(size: 17, weight: .semibold)).accessibilityAddTraits(.isHeader)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .frame(minHeight: 44)
    }
}

extension SettingsHeader where Trailing == EmptyView {
    init(symbol: String, accent: Accent?, title: String, subtitle: String) {
        self.init(symbol: symbol, accent: accent, title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textSecondary).padding(.leading, 4)
            VStack(spacing: 0) {
                Group(subviews: content) { subviews in
                    ForEach(subviews.indices, id: \.self) { index in
                        if index > 0 { Rectangle().fill(Theme.separator).frame(height: 1) }
                        subviews[index]
                    }
                }
            }
            .background(Theme.settingsGroup, in: .rect(cornerRadius: 12))
            if let footer {
                Text(footer).font(.system(size: 11.5)).foregroundStyle(Theme.textSecondary).padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SettingsRow<Trailing: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let detail {
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .font(.system(size: 13))
        .padding(.horizontal, 14)
        .padding(.vertical, detail == nil ? 0 : 8)
        .frame(minHeight: 40)
    }
}

struct ToggleRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow(title: title, detail: detail) {
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).tint(Theme.switchOn)
        }
    }
}

/// "5 [-|+]" control used for counts and thresholds.
struct CountStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    var format: (Int) -> String = { Format.integer($0) }
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Text(format(value)).font(.system(size: 13, weight: .semibold).monospacedDigit())
            HStack(spacing: 0) {
                button("minus", L("settings.decrease"), enabled: value > range.lowerBound) { value = max(range.lowerBound, value - step) }
                Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 26)
                button("plus", L("settings.increase"), enabled: value < range.upperBound) { value = min(range.upperBound, value + step) }
            }
            .background(Theme.control, in: .rect(cornerRadius: 7))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }

    private func button(_ symbol: String, _ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
                .frame(width: 28, height: 26).contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }
}
