import Darwin
import Foundation

struct CPUReading: Equatable {
    var user = 0.0
    var system = 0.0
    var idle = 1.0
    var cores: [Double] = []
    var loadAverage = 0.0
    var gpu: Double?

    var total: Double { user + system }
}

struct CPUInfo {
    let chip: String
    let coreCount: Int
    /// Logical CPUs 0..<efficiencyCount are efficiency cores; the rest are performance cores.
    /// This holds on every Apple Silicon chip so far (checked against the IODeviceTree cluster types).
    let efficiencyCount: Int

    static let current: CPUInfo = {
        let cores = SysctlValue.int("hw.logicalcpu") ?? ProcessInfo.processInfo.activeProcessorCount
        let levels = SysctlValue.int("hw.nperflevels") ?? 1
        let efficiency = levels > 1 ? (SysctlValue.int("hw.perflevel1.logicalcpu") ?? 0) : 0
        let chip = SysctlValue.string("machdep.cpu.brand_string") ?? "Mac"
        return CPUInfo(chip: chip, coreCount: cores, efficiencyCount: efficiency)
    }()

    var performanceCount: Int { coreCount - efficiencyCount }
}

struct CPUSampler {
    private var previous: [UInt32] = []

    /// GPU utilization walks the IOKit registry, so callers ask for it only when it is shown.
    mutating func sample(includeGPU: Bool) -> CPUReading {
        var reading = CPUReading()
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount) == KERN_SUCCESS,
              let info else { return reading }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }

        let ticks = (0..<Int(infoCount)).map { UInt32(bitPattern: info[$0]) }
        let stride = Int(CPU_STATE_MAX)
        if previous.count == ticks.count {
            var user = 0.0, system = 0.0, idle = 0.0
            for core in 0..<Int(cpuCount) {
                // Counters are 32-bit and wrap; subtraction with overflow handles the wrap.
                func delta(_ state: Int32) -> Double {
                    Double(ticks[core * stride + Int(state)] &- previous[core * stride + Int(state)])
                }
                let coreUser = delta(CPU_STATE_USER) + delta(CPU_STATE_NICE)
                let coreSystem = delta(CPU_STATE_SYSTEM)
                let coreIdle = delta(CPU_STATE_IDLE)
                let total = coreUser + coreSystem + coreIdle
                reading.cores.append(total > 0 ? (coreUser + coreSystem) / total : 0)
                user += coreUser
                system += coreSystem
                idle += coreIdle
            }
            let total = user + system + idle
            if total > 0 {
                reading.user = user / total
                reading.system = system / total
                reading.idle = idle / total
            }
        } else {
            reading.cores = Array(repeating: 0, count: Int(cpuCount))
        }
        previous = ticks

        var load = [0.0, 0.0, 0.0]
        if getloadavg(&load, 3) > 0 { reading.loadAverage = load[0] }
        if includeGPU {
            let gpu = PulsoGPUUtilization()
            reading.gpu = gpu >= 0 ? Double(gpu) / 100 : nil
        }
        return reading
    }
}

enum SystemInfo {
    static var uptime: TimeInterval {
        var boot = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &boot, &size, nil, 0) == 0 else { return ProcessInfo.processInfo.systemUptime }
        return Date().timeIntervalSince1970 - TimeInterval(boot.tv_sec)
    }

    /// Product line such as "MacBook Air". The registry only has the model identifier ("Mac17,3"),
    /// so ask System Information once, off the main thread.
    static func loadDeviceName() async -> String {
        await Task.detached {
            let output = Shell.run("/usr/sbin/system_profiler", ["SPHardwareDataType", "-json"])
            let json = output.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let hardware = (json?["SPHardwareDataType"] as? [[String: Any]])?.first
            return hardware?["machine_name"] as? String ?? SysctlValue.string("hw.model") ?? "Mac"
        }.value
    }
}

enum Shell {
    /// Runs a tool synchronously and returns its standard output, or nil on failure.
    static func run(_ path: String, _ arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }
}
