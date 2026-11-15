import AppKit
import ServiceManagement
import SwiftUI

// MARK: - General

struct GeneralPane: View {
    @State private var language = AppLanguage.current
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsHeader(symbol: SettingsPane.general.symbol, accent: nil, title: L("settings.general"), subtitle: L("settings.general.description"))

            SettingsSection(title: L("settings.language"), footer: L("settings.language.footer")) {
                SettingsRow(title: L("settings.language")) {
                    Picker(L("settings.language"), selection: $language) {
                        ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .onChange(of: language) { _, newValue in
                        newValue.apply()
                        Relauncher.relaunch()
                    }
                }
            }

            SettingsSection(title: L("settings.startup"), footer: launchError) {
                ToggleRow(title: L("settings.launchAtLogin"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                            launchError = nil
                        } catch {
                            launchError = error.localizedDescription
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            SettingsSection(title: L("settings.about")) {
                SettingsRow(title: L("app.name")) {
                    Text(L("settings.version", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}

enum Relauncher {
    @MainActor
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}

// MARK: - Menu Bar

struct MenuBarPane: View {
    @AppStorage(Pref.menuBarOrder) private var order = ""
    @AppStorage(Pref.menuBarHidden) private var hidden = ""

    private var modules: [Module] {
        var list = order.split(separator: ",").compactMap { Module(rawValue: String($0)) }
        list += Module.allCases.filter { !list.contains($0) }
        return list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsHeader(symbol: SettingsPane.menuBar.symbol, accent: nil, title: L("settings.menuBar"), subtitle: L("settings.menuBar.description"))

            SettingsSection(title: L("settings.menuBar.order"), footer: L("settings.menuBar.footer")) {
                ForEach(Array(modules.enumerated()), id: \.element) { index, module in
                    SettingsRow(title: module.title, detail: style(of: module)) {
                        HStack(spacing: 4) {
                            moveButton("chevron.up", L("settings.moveUp", module.title), disabled: index == 0) { move(module, by: -1) }
                            moveButton("chevron.down", L("settings.moveDown", module.title), disabled: index == modules.count - 1) { move(module, by: 1) }
                            Toggle(module.title, isOn: shownBinding(module)).labelsHidden().toggleStyle(.switch).tint(Theme.switchOn)
                                .padding(.leading, 8)
                        }
                    }
                }
            }
        }
    }

    private func style(of module: Module) -> String {
        let stored = UserDefaults.standard.string(forKey: Pref.style(module)).flatMap(MenuBarStyle.init(rawValue:)) ?? module.styles[0]
        return Pref.isEnabled(module) ? stored.title : L("settings.moduleDisabled")
    }

    private func moveButton(_ symbol: String, _ label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 10, weight: .semibold)).frame(width: 24, height: 22)
                .background(Theme.control, in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .accessibilityLabel(label)
    }

    private func move(_ module: Module, by offset: Int) {
        var list = modules
        guard let index = list.firstIndex(of: module), list.indices.contains(index + offset) else { return }
        list.swapAt(index, index + offset)
        order = list.map(\.rawValue).joined(separator: ",")
    }

    private func shownBinding(_ module: Module) -> Binding<Bool> {
        Binding {
            !hidden.split(separator: ",").contains(Substring(module.rawValue))
        } set: { shown in
            var set = Set(hidden.split(separator: ",").map(String.init))
            if shown { set.remove(module.rawValue) } else { set.insert(module.rawValue) }
            hidden = set.sorted().joined(separator: ",")
        }
    }
}

// MARK: - Alerts

struct AlertsPane: View {
    @AppStorage(Pref.alertCPU) private var cpu = true
    @AppStorage(Pref.alertCPUThreshold) private var cpuThreshold = 90
    @AppStorage(Pref.alertCPUDuration) private var cpuDuration = 30
    @AppStorage(Pref.alertMemory) private var memory = true
    @AppStorage(Pref.alertDisk) private var disk = true
    @AppStorage(Pref.alertDiskThreshold) private var diskThreshold = 10
    @AppStorage(Pref.alertBattery) private var battery = true
    @AppStorage(Pref.alertBatteryThreshold) private var batteryThreshold = 15
    @AppStorage(Pref.alertTemperature) private var temperature = true
    @AppStorage(Pref.alertTemperatureThreshold) private var temperatureThreshold = 95

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsHeader(symbol: SettingsPane.alerts.symbol, accent: nil, title: L("settings.alerts"), subtitle: L("settings.alerts.description"))

            SettingsSection(title: Module.cpu.title) {
                ToggleRow(title: L("settings.cpu.alert", Format.percent(Double(cpuThreshold) / 100), cpuDuration), isOn: $cpu)
                SettingsRow(title: L("settings.alerts.threshold")) {
                    CountStepper(value: $cpuThreshold, range: 50...100, step: 5, format: { Format.percent(Double($0) / 100) }, label: L("settings.alerts.threshold"))
                }
                SettingsRow(title: L("settings.alerts.duration")) {
                    CountStepper(value: $cpuDuration, range: 5...300, step: 5, format: { L("settings.updateInterval.seconds", $0) }, label: L("settings.alerts.duration"))
                }
            }
            SettingsSection(title: Module.memory.title) {
                ToggleRow(title: L("settings.memory.alert"), isOn: $memory)
            }
            SettingsSection(title: Module.disk.title) {
                ToggleRow(title: L("settings.disk.alert", Format.percent(Double(diskThreshold) / 100)), isOn: $disk)
                SettingsRow(title: L("settings.alerts.threshold")) {
                    CountStepper(value: $diskThreshold, range: 5...50, step: 5, format: { Format.percent(Double($0) / 100) }, label: L("settings.alerts.threshold"))
                }
            }
            SettingsSection(title: Module.battery.title) {
                ToggleRow(title: L("settings.battery.alert", Format.percent(Double(batteryThreshold) / 100)), isOn: $battery)
                SettingsRow(title: L("settings.alerts.threshold")) {
                    CountStepper(value: $batteryThreshold, range: 5...50, step: 5, format: { Format.percent(Double($0) / 100) }, label: L("settings.alerts.threshold"))
                }
            }
            SettingsSection(title: Module.sensors.title) {
                ToggleRow(title: L("settings.sensors.alert", Format.temperature(Double(temperatureThreshold))), isOn: $temperature)
                SettingsRow(title: L("settings.alerts.threshold")) {
                    CountStepper(value: $temperatureThreshold, range: 60...110, step: 5, format: { Format.temperature(Double($0)) }, label: L("settings.alerts.threshold"))
                }
            }
        }
    }
}

// MARK: - Widgets

struct WidgetsPane: View {
    @AppStorage(Pref.widgetsEnabled) private var enabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsHeader(symbol: SettingsPane.widgets.symbol, accent: nil, title: L("settings.widgets"), subtitle: L("settings.widgets.description"))
            SettingsSection(title: L("settings.widgets"), footer: L("settings.widgets.footer")) {
                ToggleRow(title: L("settings.widgets.update"), isOn: $enabled)
            }
        }
    }
}

// MARK: - Bluetooth

struct BluetoothPane: View {
    @AppStorage(Pref.bluetooth) private var enabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsHeader(symbol: SettingsPane.bluetooth.symbol, accent: nil, title: L("module.bluetooth"), subtitle: L("settings.bluetooth.description"))
            SettingsSection(title: L("settings.section.panel")) {
                ToggleRow(title: L("settings.bluetooth.show"), isOn: $enabled)
            }
        }
    }
}

// MARK: - Modules

struct ModulePane: View {
    let module: Module

    var body: some View {
        // A fresh view per module so the @AppStorage keys follow the selection.
        ModulePaneContent(module: module).id(module)
    }
}

private struct ModulePaneContent: View {
    let module: Module
    @AppStorage private var enabled: Bool
    @AppStorage private var style: String
    @AppStorage private var color: String
    @AppStorage private var interval: Int
    @AppStorage private var processes: Int

    init(module: Module) {
        self.module = module
        _enabled = AppStorage(wrappedValue: true, Pref.enabled(module))
        _style = AppStorage(wrappedValue: module.styles[0].rawValue, Pref.style(module))
        _color = AppStorage(wrappedValue: Accent.monochrome.rawValue, Pref.color(module))
        _interval = AppStorage(wrappedValue: 1, Pref.interval(module))
        _processes = AppStorage(wrappedValue: 5, Pref.processes(module))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsHeader(symbol: module.symbol, accent: module.accent, title: module.title, subtitle: L("settings.\(module.rawValue).description")) {
                HStack(spacing: 10) {
                    Text(L("settings.moduleEnabled")).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    Toggle(L("settings.moduleEnabled"), isOn: $enabled).labelsHidden().toggleStyle(.switch).tint(Theme.switchOn)
                }
            }

            Group {
                SettingsSection(title: L("settings.section.menuBar")) {
                    SettingsRow(title: L("settings.style")) { StylePicker(module: module, selection: $style, color: Accent(rawValue: color) ?? .monochrome) }
                    SettingsRow(title: L("settings.color")) { ColorPicker(selection: $color) }
                    if module != .battery {
                        SettingsRow(title: L("settings.updateInterval")) {
                            Picker(L("settings.updateInterval"), selection: $interval) {
                                ForEach(Pref.intervals, id: \.self) { Text(L("settings.updateInterval.seconds", $0)).tag($0) }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }
                PanelSection(module: module, processes: $processes)
                AlertSection(module: module)
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

private struct StylePicker: View {
    let module: Module
    @Binding var selection: String
    let color: Accent

    var body: some View {
        HStack(spacing: 8) {
            ForEach(module.styles) { style in
                let selected = selection == style.rawValue
                Button { selection = style.rawValue } label: {
                    VStack(spacing: 6) {
                        StylePreview(style: style, color: color == .monochrome ? .white : color.base)
                            .frame(height: 18)
                        Text(style.title).font(.system(size: 11.5)).foregroundStyle(selected ? .white : .white.opacity(0.78))
                    }
                    .frame(width: 78, height: 64)
                    .background(selected ? Accent.blue.base.opacity(0.16) : .white.opacity(0.06), in: .rect(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Accent.blue.base : .clear, lineWidth: 1.5)
                    }
                    .contentShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(style.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.vertical, 12)
    }
}

private struct StylePreview: View {
    let style: MenuBarStyle
    let color: Color

    var body: some View {
        switch style {
        case .mini:
            Text(Format.percent(0.18)).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
        case .speed:
            Image(systemName: "arrow.up.arrow.down").font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
        case .line:
            Path { path in
                let points: [CGFloat] = [10, 6, 9, 3, 7, 2, 5]
                path.addLines(points.enumerated().map { CGPoint(x: CGFloat($0.offset) * 5, y: $0.element) })
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            .frame(width: 30, height: 12)
        case .bars:
            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach([0.35, 0.55, 0.45, 0.8, 0.5, 0.65], id: \.self) { value in
                    RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 3, height: 16 * value)
                }
            }
        case .ring:
            RingGauge(fraction: 0.62, color: color, lineWidth: 3).frame(width: 15, height: 15)
        case .battery:
            BatteryGlyph(level: 0.78, color: color, width: 22, height: 11)
        case .dot:
            Circle().fill(Accent.green.base).frame(width: 10, height: 10)
        }
    }
}

private struct ColorPicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 10) {
            ForEach([Accent.blue, .teal, .amber, .coral, .monochrome]) { accent in
                let selected = selection == accent.rawValue
                Button { selection = accent.rawValue } label: {
                    Circle().fill(accent.base).frame(width: 18, height: 18)
                        .padding(3)
                        .overlay { Circle().strokeBorder(selected ? accent.base : .clear, lineWidth: 1.5) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accent.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

private struct PanelSection: View {
    let module: Module
    @Binding var processes: Int
    @AppStorage(Pref.cpuPerCore) private var perCore = true
    @AppStorage(Pref.cpuTemperature) private var temperature = true
    @AppStorage(Pref.publicIP) private var publicIP = false
    @AppStorage(Pref.latencyHost) private var latencyHost = "1.1.1.1"

    var body: some View {
        switch module {
        case .cpu:
            SettingsSection(title: L("settings.section.panel")) {
                ToggleRow(title: L("cpu.perCore"), isOn: $perCore)
                ToggleRow(title: L("cpu.temperature"), isOn: $temperature)
                processRow
            }
        case .memory, .disk:
            SettingsSection(title: L("settings.section.panel")) { processRow }
        case .network:
            SettingsSection(title: L("settings.section.panel"), footer: L("settings.network.publicIP.footer")) {
                processRow
                ToggleRow(title: L("network.publicIP"), detail: L("settings.network.publicIP.detail"), isOn: $publicIP)
                SettingsRow(title: L("settings.network.latencyHost")) {
                    TextField(L("settings.network.latencyHost"), text: $latencyHost)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                }
            }
        case .battery, .sensors:
            EmptyView()
        }
    }

    private var processRow: some View {
        SettingsRow(title: L("settings.processesShown")) {
            CountStepper(value: $processes, range: 1...Pref.maxProcesses, label: L("settings.processesShown"))
        }
    }
}

private struct AlertSection: View {
    let module: Module
    @AppStorage(Pref.alertCPU) private var cpu = true
    @AppStorage(Pref.alertCPUThreshold) private var cpuThreshold = 90
    @AppStorage(Pref.alertCPUDuration) private var cpuDuration = 30
    @AppStorage(Pref.alertMemory) private var memory = true
    @AppStorage(Pref.alertDisk) private var disk = true
    @AppStorage(Pref.alertDiskThreshold) private var diskThreshold = 10
    @AppStorage(Pref.alertBattery) private var battery = true
    @AppStorage(Pref.alertBatteryThreshold) private var batteryThreshold = 15
    @AppStorage(Pref.alertTemperature) private var temperature = true
    @AppStorage(Pref.alertTemperatureThreshold) private var temperatureThreshold = 95

    var body: some View {
        if module != .network {
            SettingsSection(title: L("settings.alerts")) {
                switch module {
                case .cpu:
                    ToggleRow(title: L("settings.cpu.alert", Format.percent(Double(cpuThreshold) / 100), cpuDuration), isOn: $cpu)
                case .memory:
                    ToggleRow(title: L("settings.memory.alert"), isOn: $memory)
                case .disk:
                    ToggleRow(title: L("settings.disk.alert", Format.percent(Double(diskThreshold) / 100)), isOn: $disk)
                case .battery:
                    ToggleRow(title: L("settings.battery.alert", Format.percent(Double(batteryThreshold) / 100)), isOn: $battery)
                case .sensors:
                    ToggleRow(title: L("settings.sensors.alert", Format.temperature(Double(temperatureThreshold))), isOn: $temperature)
                case .network:
                    EmptyView()
                }
            }
        }
    }
}
