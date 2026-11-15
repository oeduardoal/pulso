import Foundation

struct SensorGroup: Identifiable, Equatable {
    let name: String
    let celsius: Double
    var id: String { name }
}

struct SensorReading: Equatable {
    var cpu: Double?
    var gpu: Double?
    var ssd: Double?
    var battery: Double?
    var fans: [Double] = []
    /// Every sensor, grouped by name with trailing numbers removed and the hottest value kept.
    var groups: [SensorGroup] = []

    var isAvailable: Bool { !groups.isEmpty }
}

/// Temperature and fan sensors. Neither is public API: temperatures come from the HID event
/// system on Apple Silicon, fans from the SMC.
struct SensorSampler {
    let fanCount = Int(PulsoFanCount())

    /// Reads every sensor, for the panel.
    func sample() -> SensorReading {
        var reading = SensorReading()
        reading.fans = (0..<fanCount).map { PulsoFanSpeed(Int32($0)) }.filter { $0 >= 0 }
        guard let sensors = PulsoCopyThermalSensors(nil, 0)?.takeRetainedValue() as? [String: Double] else { return reading }
        func hottest(_ matches: (String) -> Bool) -> Double? {
            sensors.filter { matches($0.key) }.values.max()
        }
        reading.cpu = hottest { $0.hasPrefix("PMU tdie") || $0.contains("ACC MTR") || $0.hasPrefix("CPU") }
        reading.gpu = hottest { $0.localizedCaseInsensitiveContains("GPU") }
        reading.ssd = hottest { $0.hasPrefix("NAND") }
        reading.battery = hottest { $0.hasPrefix("gas gauge") }

        var groups: [String: Double] = [:]
        for (name, value) in sensors {
            let base = name.replacingOccurrences(of: #"\s*\d+$"#, with: "", options: .regularExpression)
            groups[base] = max(groups[base] ?? -.infinity, value)
        }
        reading.groups = groups.map { SensorGroup(name: $0.key, celsius: $0.value) }.sorted { $0.name < $1.name }
        return reading
    }

    /// Cheap CPU temperature for the menu bar and alerts while the panel is closed.
    /// shortcut: reads 6 die sensors instead of all of them; they track within a degree or two. Read all if a chip shows hot spots.
    func sampleCPUOnly(previous: SensorReading) -> SensorReading {
        let sensors = PulsoCopyThermalSensors("PMU tdie", 6)?.takeRetainedValue() as? [String: Double] ?? [:]
        // Chips that name their die sensors differently fall back to the full read.
        guard let hottest = sensors.values.max() else { return sample() }
        var reading = previous
        reading.cpu = hottest
        return reading
    }
}

struct BluetoothDevice: Identifiable, Equatable {
    let name: String
    let level: Double
    let kind: String?
    var id: String { name }
}

enum BluetoothSampler {
    /// Battery levels of connected Bluetooth devices. System Information is the only source that
    /// covers AirPods as well as keyboards and mice; it is slow, so call it rarely and off the main thread.
    static func devices() async -> [BluetoothDevice] {
        await Task.detached {
            guard let data = Shell.run("/usr/sbin/system_profiler", ["SPBluetoothDataType", "-json"]),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let controller = (json["SPBluetoothDataType"] as? [[String: Any]])?.first,
                  let connected = controller["device_connected"] as? [[String: Any]] else { return [] }
            return connected.flatMap { $0 }.compactMap { name, value -> BluetoothDevice? in
                guard let info = value as? [String: Any] else { return nil }
                let levels = ["device_batteryLevelMain", "device_batteryLevel", "device_batteryLevelLeft", "device_batteryLevelRight"]
                    .compactMap { (info[$0] as? String).flatMap(parsePercent) }
                guard let level = levels.min() else { return nil }
                return BluetoothDevice(name: name, level: level, kind: info["device_minorType"] as? String)
            }
            .sorted { $0.name < $1.name }
        }.value
    }

    private static func parsePercent(_ text: String) -> Double? {
        Double(text.filter(\.isNumber)).map { $0 / 100 }
    }
}
