import Foundation
import Observation
import WidgetKit

/// Owns every sampler and publishes the latest readings. One shared timer drives all modules;
/// each module samples on its own interval, and the costly ones only run while their panel is open.
@MainActor
@Observable
final class Monitor {
    static let shared = Monitor()

    private(set) var cpu = CPUReading()
    private(set) var cpuUser = Series()
    private(set) var cpuSystem = Series()
    private(set) var memory = MemoryReading()
    private(set) var memoryUsed = Series()
    private(set) var memoryPressure = Series()
    private(set) var volumes: [Volume] = []
    private(set) var diskRead = Series()
    private(set) var diskWrite = Series()
    private(set) var smart: SMARTStatus?
    private(set) var network = NetworkReading()
    private(set) var download = Series()
    private(set) var upload = Series()
    private(set) var latency: Double?
    private(set) var publicIP: String?
    private(set) var battery = BatteryReading()
    private(set) var batteryHistory = BatterySampler.loadHistory()
    private(set) var lastFullCharge = BatterySampler.lastFullCharge
    private(set) var sensors = SensorReading()
    private(set) var bluetooth: [BluetoothDevice] = []
    private(set) var topProcesses: [ProcessUsage] = []
    /// What the status item shows, refreshed on each module's own interval.
    private(set) var menuBar: [Module: MenuBarReading] = [:]
    private(set) var deviceName = ""
    private(set) var uptime: TimeInterval = 0
    let alerts = AlertEngine()

    /// Which screen the panel shows; nil is the overview.
    var route: Module?
    var isPanelOpen = false {
        didSet {
            guard isPanelOpen != oldValue else { return }
            if isPanelOpen { tickNow() } else { route = nil; topProcesses = [] }
        }
    }

    private var cpuSampler = CPUSampler()
    private var processSampler = ProcessSampler()
    private var diskSampler = DiskSampler()
    private var networkSampler = NetworkSampler()
    private let sensorSampler = SensorSampler()
    private var processTraffic: [pid_t: Double] = [:]
    private var publicIPDate: Date?
    private var tasksInFlight: Set<String> = []
    private var timer: Timer?
    private var tick = 0

    func start() {
        Task { deviceName = await SystemInfo.loadDeviceName() }
        tickNow()
        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { Monitor.shared.tickNow() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Modules sample every second so charts cover exactly the last 60 seconds and alerts react
    /// quickly. The interval setting only paces the menu bar, which is the costly part to redraw.
    private func due(_ module: Module) -> Bool {
        Pref.isEnabled(module)
    }

    private func updateMenuBar() {
        var next = menuBar
        for module in Module.allCases {
            guard Pref.isEnabled(module), module != .battery || battery.isPresent else {
                next[module] = nil
                continue
            }
            let interval = max(1, UserDefaults.standard.integer(forKey: Pref.interval(module)))
            if next[module] == nil || tick % interval == 0 {
                next[module] = MenuBarReading(module: module, monitor: self)
            }
        }
        if next != menuBar { menuBar = next }
    }

    private func tickNow() {
        tick += 1
        let defaults = UserDefaults.standard

        if due(.cpu) {
            cpu = cpuSampler.sample(includeGPU: isPanelOpen && route == .cpu)
            cpuUser.append(cpu.user)
            cpuSystem.append(cpu.system)
        }
        if due(.memory) {
            memory = MemorySampler.sample()
            memoryUsed.append(memory.usedFraction)
            memoryPressure.append(memory.pressureLevel)
        }
        if due(.disk) {
            // Rates only appear in the disk panel; skip the IOKit walk while it is closed.
            if isPanelOpen && route == .disk {
                let rates = diskSampler.sampleRates()
                diskRead.append(rates.read)
                diskWrite.append(rates.write)
            }
            if isPanelOpen && route == .disk {
                if tick % 3 == 0 || volumes.count < 2 { volumes = DiskSampler.volumes() }
            } else if volumes.isEmpty || tick % 30 == 0 || (isPanelOpen && tick % 5 == 0) {
                volumes = DiskSampler.startupVolume().map { [$0] } ?? []
            }
            if smart == nil && tick == 1 || tick % 300 == 0 || (isPanelOpen && route == .disk && tick % 30 == 0) {
                smart = DiskSampler.smart()
            }
        }
        if due(.network) {
            network = networkSampler.sample(detailed: isPanelOpen)
            download.append(network.download)
            upload.append(network.upload)
        }
        if Pref.isEnabled(.battery) && (tick == 1 || tick % 5 == 0) {
            sampleBattery()
        }
        let wantsSensors = Pref.isEnabled(.sensors) || (Pref.isEnabled(.cpu) && defaults.bool(forKey: Pref.cpuTemperature))
        if wantsSensors {
            if tick == 1 || (isPanelOpen && tick % 2 == 0) {
                sensors = sensorSampler.sample()
            } else if !isPanelOpen && tick % 5 == 0 {
                sensors = sensorSampler.sampleCPUOnly(previous: sensors)
            }
        }

        if isPanelOpen {
            uptime = SystemInfo.uptime
            samplePanelExtras()
        }

        updateMenuBar()
        alerts.evaluate(self)
        if tick % 60 == 1, defaults.bool(forKey: Pref.widgetsEnabled) {
            writeWidgetSnapshot()
        }
    }

    private func sampleBattery() {
        battery = BatterySampler.sample()
        guard battery.isPresent else { return }
        if battery.isCharged || battery.level >= 0.995, battery.isPluggedIn {
            if lastFullCharge.map({ Date().timeIntervalSince($0) > 60 }) ?? true {
                lastFullCharge = Date()
                BatterySampler.lastFullCharge = lastFullCharge
            }
        }
        // One point every 5 minutes is enough for a 12 hour chart.
        if batteryHistory.last.map({ Date().timeIntervalSince($0.date) >= 300 }) ?? true {
            let cutoff = Date().addingTimeInterval(-BatterySampler.historyWindow)
            batteryHistory = batteryHistory.filter { $0.date >= cutoff } + [BatteryHistoryPoint(date: Date(), level: battery.level)]
            BatterySampler.saveHistory(batteryHistory)
        }
    }

    // MARK: - Panel-only work

    private func samplePanelExtras() {
        let defaults = UserDefaults.standard
        switch route {
        case .cpu, .memory, .disk:
            sampleProcesses()
        case .network:
            runOnce("nettop") { [weak self] in
                let traffic = await NetworkSampler.processTraffic()
                self?.processTraffic = traffic
            }
            sampleProcesses()
            if tick % 5 == 0 || latency == nil {
                let host = defaults.string(forKey: Pref.latencyHost) ?? "1.1.1.1"
                runOnce("latency") { [weak self] in self?.latency = await NetworkSampler.latency(to: host) }
            }
            if defaults.bool(forKey: Pref.publicIP) {
                if publicIPDate.map({ Date().timeIntervalSince($0) > 300 }) ?? true {
                    publicIPDate = Date()
                    runOnce("publicIP") { [weak self] in self?.publicIP = await NetworkSampler.publicIP() }
                }
            } else {
                publicIP = nil
                publicIPDate = nil
            }
        case .battery:
            if defaults.bool(forKey: Pref.bluetooth), tick % 30 == 0 || bluetooth.isEmpty {
                runOnce("bluetooth") { [weak self] in self?.bluetooth = await BluetoothSampler.devices() }
            }
        default:
            break
        }
    }

    private func runOnce(_ name: String, _ work: @escaping @MainActor () async -> Void) {
        guard !tasksInFlight.contains(name) else { return }
        tasksInFlight.insert(name)
        Task {
            await work()
            tasksInFlight.remove(name)
        }
    }

    private func sampleProcesses() {
        guard let route else { return }
        var all = processSampler.sample()
        let count = max(1, min(Pref.maxProcesses, UserDefaults.standard.integer(forKey: Pref.processes(route))))
        let key: (ProcessUsage) -> Double
        switch route {
        case .memory: key = { Double($0.memory) }
        case .disk: key = { $0.diskBytesPerSecond }
        case .network:
            for index in all.indices { all[index].networkBytesPerSecond = processTraffic[all[index].pid] ?? 0 }
            key = { $0.networkBytesPerSecond }
        default: key = { $0.cpu }
        }
        let top = all.filter { key($0) > 0 }.sorted { key($0) > key($1) }.prefix(count)
        topProcesses = processSampler.named(top)
    }

    // MARK: - Widgets

    private func writeWidgetSnapshot() {
        let snapshot = WidgetSnapshot(
            date: Date(),
            cpu: cpu.total,
            cpuTemperature: sensors.cpu,
            coreCount: CPUInfo.current.coreCount,
            memoryUsed: memory.used,
            memoryTotal: memory.total,
            download: network.download,
            upload: network.upload,
            downloadHistory: download.values,
            uploadHistory: upload.values,
            interfaceName: network.interfaceName
        )
        if snapshot.save() {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
