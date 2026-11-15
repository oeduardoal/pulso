import AppKit
import Darwin

struct ProcessUsage: Identifiable, Equatable {
    let pid: pid_t
    let name: String
    /// Fraction of one core, like the "% CPU" column in Activity Monitor (1.0 = 100%).
    var cpu = 0.0
    var memory: UInt64 = 0
    var diskBytesPerSecond = 0.0
    var networkBytesPerSecond = 0.0

    var id: pid_t { pid }
}

/// Walks the process table with libproc. Only processes owned by the current user are readable
/// without a privileged helper, so system daemons are left out.
struct ProcessSampler {
    private struct Counters {
        let cpuTime: UInt64
        let diskBytes: UInt64
    }

    private var previous: [pid_t: Counters] = [:]
    private var previousTime: UInt64 = 0
    private var names: [pid_t: String] = [:]
    private let timebase: Double = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(info.numer) / Double(info.denom)
    }()

    mutating func sample() -> [ProcessUsage] {
        let now = mach_absolute_time()
        let elapsed = Double(now &- previousTime) * timebase // nanoseconds
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) + 32)
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard filled > 0 else { return [] }

        var current: [pid_t: Counters] = [:]
        var usages: [ProcessUsage] = []
        for pid in pids.prefix(Int(filled)) where pid > 0 {
            var info = rusage_info_v2()
            let ok = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V2, $0) == 0
                }
            }
            guard ok else { continue }
            let counters = Counters(
                cpuTime: info.ri_user_time + info.ri_system_time,
                diskBytes: info.ri_diskio_bytesread + info.ri_diskio_byteswritten
            )
            current[pid] = counters
            var usage = ProcessUsage(pid: pid, name: "", memory: info.ri_phys_footprint)
            if let before = previous[pid], elapsed > 0 {
                usage.cpu = Double(counters.cpuTime &- before.cpuTime) * timebase / elapsed
                usage.diskBytesPerSecond = Double(counters.diskBytes &- before.diskBytes) / (elapsed / 1e9)
            }
            usages.append(usage)
        }
        previous = current
        previousTime = now
        names = names.filter { current[$0.key] != nil }
        return usages
    }

    /// Resolves display names lazily, only for the rows that are shown.
    mutating func named(_ usages: some Sequence<ProcessUsage>) -> [ProcessUsage] {
        usages.map { usage in
            if names[usage.pid] == nil { names[usage.pid] = Self.name(of: usage.pid) }
            return ProcessUsage(pid: usage.pid, name: names[usage.pid] ?? "", cpu: usage.cpu, memory: usage.memory,
                                diskBytesPerSecond: usage.diskBytesPerSecond, networkBytesPerSecond: usage.networkBytesPerSecond)
        }
    }

    static func name(of pid: pid_t) -> String {
        if let app = NSRunningApplication(processIdentifier: pid), let name = app.localizedName { return name }
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        if proc_name(pid, &buffer, UInt32(buffer.count)) > 0 { return String(cBuffer: buffer) }
        return "\(pid)"
    }
}
