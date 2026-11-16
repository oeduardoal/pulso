import Foundation

/// UserDefaults keys. Views bind to them with `@AppStorage`; the monitor reads them on each tick.
enum Pref {
    static func enabled(_ module: Module) -> String { "\(module.rawValue).enabled" }
    static func style(_ module: Module) -> String { "\(module.rawValue).style" }
    static func color(_ module: Module) -> String { "\(module.rawValue).color" }
    static func interval(_ module: Module) -> String { "\(module.rawValue).interval" }
    static func processes(_ module: Module) -> String { "\(module.rawValue).processes" }

    static let menuBarOrder = "menuBar.order"
    static let menuBarHidden = "menuBar.hidden"
    static let menuBarCompact = "menuBar.compact"
    static let cpuPerCore = "cpu.perCore"
    static let cpuTemperature = "cpu.temperature"
    static let publicIP = "network.publicIP"
    static let latencyHost = "network.latencyHost"
    static let bluetooth = "bluetooth.enabled"
    static let widgetsEnabled = "widgets.enabled"

    static let alertCPU = "alerts.cpu"
    static let alertCPUThreshold = "alerts.cpu.threshold"
    static let alertCPUDuration = "alerts.cpu.duration"
    static let alertMemory = "alerts.memory"
    static let alertDisk = "alerts.disk"
    static let alertDiskThreshold = "alerts.disk.threshold"
    static let alertBattery = "alerts.battery"
    static let alertBatteryThreshold = "alerts.battery.threshold"
    static let alertTemperature = "alerts.temperature"
    static let alertTemperatureThreshold = "alerts.temperature.threshold"

    static let maxProcesses = 10
    static let intervals = [1, 2, 5, 10]

    static func register() {
        var defaults: [String: Any] = [
            menuBarOrder: Module.allCases.map(\.rawValue).joined(separator: ","),
            menuBarHidden: [Module.disk, .battery].map(\.rawValue).joined(separator: ","),
            menuBarCompact: true,
            cpuPerCore: true,
            cpuTemperature: true,
            publicIP: false,
            latencyHost: "1.1.1.1",
            bluetooth: true,
            widgetsEnabled: true,
            alertCPU: true,
            alertCPUThreshold: 90,
            alertCPUDuration: 30,
            alertMemory: true,
            alertDisk: true,
            alertDiskThreshold: 10,
            alertBattery: true,
            alertBatteryThreshold: 15,
            alertTemperature: true,
            alertTemperatureThreshold: 95,
        ]
        for module in Module.allCases {
            defaults[enabled(module)] = true
            defaults[style(module)] = module.styles[0].rawValue
            defaults[color(module)] = Accent.monochrome.rawValue
            defaults[interval(module)] = 1
            defaults[processes(module)] = 5
        }
        UserDefaults.standard.register(defaults: defaults)
    }

    static func isEnabled(_ module: Module) -> Bool { UserDefaults.standard.bool(forKey: enabled(module)) }

    /// Modules shown in the menu bar, in the user's order.
    static func menuBarModules(order: String, hidden: String) -> [Module] {
        let hiddenSet = Set(hidden.split(separator: ",").map(String.init))
        var modules = order.split(separator: ",").compactMap { Module(rawValue: String($0)) }
        modules += Module.allCases.filter { !modules.contains($0) }
        return modules.filter { !hiddenSet.contains($0.rawValue) }
    }
}
