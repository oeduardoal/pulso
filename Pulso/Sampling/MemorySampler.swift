import Darwin
import Foundation

enum MemoryPressure: Int, Equatable {
    case normal = 1, warning = 2, critical = 4

    var title: String {
        switch self {
        case .normal: L("memory.pressure.normal")
        case .warning: L("memory.pressure.warning")
        case .critical: L("memory.pressure.critical")
        }
    }

    var accent: Accent {
        switch self {
        case .normal: .green
        case .warning: .amber
        case .critical: .coral
        }
    }
}

struct MemoryReading: Equatable {
    var total: UInt64 = 0
    var app: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var cached: UInt64 = 0
    var free: UInt64 = 0
    var swapUsed: UInt64 = 0
    var pressure = MemoryPressure.normal
    /// 0...1, how hard the system is working to keep memory available.
    var pressureLevel = 0.0

    var used: UInt64 { app + wired + compressed }
    var available: UInt64 { total > used ? total - used : 0 }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

enum MemorySampler {
    static let total = UInt64(SysctlValue.int("hw.memsize") ?? 0)

    static func sample() -> MemoryReading {
        var reading = MemoryReading(total: total)
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let page = UInt64(getpagesize())
            // Same breakdown as Activity Monitor.
            reading.app = UInt64(stats.internal_page_count - stats.purgeable_count) * page
            reading.wired = UInt64(stats.wire_count) * page
            reading.compressed = UInt64(stats.compressor_page_count) * page
            reading.cached = UInt64(stats.external_page_count + stats.purgeable_count) * page
            reading.free = UInt64(stats.free_count) * page
        }

        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 { reading.swapUsed = swap.xsu_used }

        reading.pressure = SysctlValue.int("kern.memorystatus_vm_pressure_level").flatMap(MemoryPressure.init(rawValue:)) ?? .normal
        if let level = SysctlValue.int("kern.memorystatus_level") {
            reading.pressureLevel = Double(100 - level) / 100
        }
        return reading
    }
}
