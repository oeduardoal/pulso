import Foundation
import IOKit.ps

struct BatteryReading: Equatable {
    var isPresent = false
    var level = 0.0
    var isCharging = false
    var isPluggedIn = false
    var isCharged = false
    /// Seconds until empty or full; nil while macOS is still estimating.
    var timeRemaining: TimeInterval?
    var timeToFull: TimeInterval?
    var health: Double?
    var cycles: Int?
    var power: Double?
    var temperature: Double?
    var isLowPowerMode = false
}

struct BatteryHistoryPoint: Equatable {
    let date: Date
    let level: Double
}

enum BatterySampler {
    static func sample() -> BatteryReading {
        var reading = BatteryReading(isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled)
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        let battery = sources.lazy
            .compactMap { IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] }
            .first { $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType }
        guard let battery else { return reading }

        reading.isPresent = true
        let current = battery[kIOPSCurrentCapacityKey] as? Double ?? 0
        let max = battery[kIOPSMaxCapacityKey] as? Double ?? 100
        reading.level = max > 0 ? current / max : 0
        reading.isCharging = battery[kIOPSIsChargingKey] as? Bool ?? false
        reading.isPluggedIn = battery[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
        reading.isCharged = battery[kIOPSIsChargedKey] as? Bool ?? false
        if let minutes = battery[kIOPSTimeToEmptyKey] as? Int, minutes > 0, !reading.isPluggedIn {
            reading.timeRemaining = TimeInterval(minutes * 60)
        }
        if let minutes = battery[kIOPSTimeToFullChargeKey] as? Int, minutes > 0, reading.isCharging {
            reading.timeToFull = TimeInterval(minutes * 60)
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        defer { IOObjectRelease(service) }
        var properties: Unmanaged<CFMutableDictionary>?
        if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
           let registry = properties?.takeRetainedValue() as? [String: Any] {
            reading.cycles = registry["CycleCount"] as? Int
            let data = registry["BatteryData"] as? [String: Any]
            let design = (data?["DesignCapacity"] ?? registry["DesignCapacity"]) as? Double
            let nominal = (data?["NominalChargeCapacity"] ?? registry["NominalChargeCapacity"] ?? registry["AppleRawMaxCapacity"]) as? Double
            if let design, let nominal, design > 0 { reading.health = min(nominal / design, 1) }
            if let celsius = registry["Temperature"] as? Double { reading.temperature = celsius / 100 }

            if reading.isPluggedIn,
               let telemetry = registry["PowerTelemetryData"] as? [String: Any],
               let systemIn = telemetry["SystemPowerIn"] as? Double, systemIn > 0 {
                reading.power = systemIn / 1000
            } else if let voltage = registry["Voltage"] as? Double, let amperage = registry["Amperage"] as? Int {
                // Amperage is a signed value that IOKit may hand over as a large unsigned number.
                let milliamps = Double(Int64(truncatingIfNeeded: amperage))
                reading.power = abs(voltage * milliamps) / 1_000_000
            }
        }
        return reading
    }

    // MARK: - History, kept by Pulso itself since macOS has no public battery log

    private static let historyKey = "battery.history"
    private static let lastFullKey = "battery.lastFull"
    static let historyWindow: TimeInterval = 12 * 3600

    static func loadHistory() -> [BatteryHistoryPoint] {
        let raw = UserDefaults.standard.array(forKey: historyKey) as? [[Double]] ?? []
        let cutoff = Date().addingTimeInterval(-historyWindow)
        return raw.compactMap { pair in
            guard pair.count == 2 else { return nil }
            let point = BatteryHistoryPoint(date: Date(timeIntervalSince1970: pair[0]), level: pair[1])
            return point.date >= cutoff ? point : nil
        }
    }

    static func saveHistory(_ history: [BatteryHistoryPoint]) {
        UserDefaults.standard.set(history.map { [$0.date.timeIntervalSince1970, $0.level] }, forKey: historyKey)
    }

    static var lastFullCharge: Date? {
        get { UserDefaults.standard.object(forKey: lastFullKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastFullKey) }
    }
}
