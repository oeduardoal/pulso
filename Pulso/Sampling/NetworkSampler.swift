import CoreWLAN
import Foundation
import Network
import SystemConfiguration

struct NetworkReading: Equatable {
    var download = 0.0
    var upload = 0.0
    var interface: String?
    var interfaceName: String?
    var localIP: String?
    var wifiStandard: String?
    var downloadedToday: UInt64 = 0
    var uploadedToday: UInt64 = 0

    var isConnected: Bool { interface != nil }
}

struct NetworkSampler {
    private var previous: (received: UInt64, sent: UInt64, interface: String)?
    private var previousTime = Date()
    private var cachedInterface: (bsd: String, name: String?, ip: String?, wifi: String?)?
    private var tick = 0
    private var today = DailyTotals.load()

    mutating func sample(detailed: Bool) -> NetworkReading {
        // Interface changes are rare; refresh the descriptive fields every few samples.
        if tick % (detailed ? 5 : 15) == 0 { cachedInterface = Self.primaryInterface() }
        tick += 1

        var reading = NetworkReading()
        guard let interface = cachedInterface else {
            previous = nil
            return reading
        }
        reading.interface = interface.bsd
        reading.interfaceName = interface.name
        reading.localIP = interface.ip
        reading.wifiStandard = interface.wifi

        let now = Date()
        if let counters = Self.counters(for: interface.bsd) {
            if let previous, previous.interface == interface.bsd {
                let elapsed = max(now.timeIntervalSince(previousTime), 0.001)
                let received = counters.received &- previous.received
                let sent = counters.sent &- previous.sent
                reading.download = Double(received) / elapsed
                reading.upload = Double(sent) / elapsed
                today.add(received: received, sent: sent)
            }
            previous = (counters.received, counters.sent, interface.bsd)
        }
        previousTime = now
        reading.downloadedToday = today.received
        reading.uploadedToday = today.sent
        return reading
    }

    // MARK: - Interface

    private static func primaryInterface() -> (bsd: String, name: String?, ip: String?, wifi: String?)? {
        guard let global = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let bsd = global["PrimaryInterface"] as? String else { return nil }
        let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? []
        let name = interfaces.first { SCNetworkInterfaceGetBSDName($0) as String? == bsd }
            .flatMap { SCNetworkInterfaceGetLocalizedDisplayName($0) as String? }
        let wifi = CWWiFiClient.shared().interface(withName: bsd).flatMap { wifiStandard($0.activePHYMode()) }
        return (bsd, name, ipv4Address(of: bsd), wifi)
    }

    /// Product names for the PHY modes. They are trademarks and are not translated.
    private static func wifiStandard(_ mode: CWPHYMode) -> String? {
        switch mode {
        case .mode11n: "Wi-Fi 4"
        case .mode11ac: "Wi-Fi 5"
        case .mode11ax: "Wi-Fi 6"
        case .mode11be: "Wi-Fi 7"
        default: nil
        }
    }

    private static func ipv4Address(of interface: String) -> String? {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return nil }
        defer { freeifaddrs(addresses) }
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let address = entry.pointee
            guard let sockaddr = address.ifa_addr, sockaddr.pointee.sa_family == UInt8(AF_INET),
                  String(cString: address.ifa_name) == interface else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(sockaddr, socklen_t(sockaddr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                return String(cBuffer: host)
            }
        }
        return nil
    }

    /// 64-bit byte counters from the routing socket. `getifaddrs` only has 32-bit counters that wrap at 4 GB.
    private static func counters(for interface: String) -> (received: UInt64, sent: UInt64)? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else { return nil }
        let index = if_nametoindex(interface)
        return buffer.withUnsafeBytes { raw -> (UInt64, UInt64)? in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                if Int32(header.ifm_type) == RTM_IFINFO2 && UInt32(header.ifm_index) == index {
                    let message = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    return (message.ifm_data.ifi_ibytes, message.ifm_data.ifi_obytes)
                }
                guard header.ifm_msglen > 0 else { break }
                offset += Int(header.ifm_msglen)
            }
            return nil
        }
    }

    // MARK: - On-demand checks, only while the network panel is open

    /// Time to open a TCP connection to `host`, in milliseconds.
    static func latency(to host: String) async -> Double? {
        let connection = NWConnection(host: NWEndpoint.Host(host), port: 443, using: .tcp)
        let start = Date()
        let result: Double? = await withCheckedContinuation { continuation in
            let once = Once()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: once.run { continuation.resume(returning: Date().timeIntervalSince(start) * 1000) }
                case .failed, .cancelled, .waiting: once.run { continuation.resume(returning: nil) }
                default: break
                }
            }
            connection.start(queue: .global(qos: .utility))
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) { once.run { continuation.resume(returning: nil) } }
        }
        connection.cancel()
        return result
    }

    /// Opt-in: asks api.ipify.org for the public address.
    static func publicIP() async -> String? {
        guard let url = URL(string: "https://api.ipify.org") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.setValue("Pulso", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let address = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return address.count <= 45 ? address : nil
    }

    /// Per-process traffic over one second. There is no public API, so this reads `nettop` in delta mode.
    static func processTraffic() async -> [pid_t: Double] {
        await Task.detached {
            guard let data = Shell.run("/usr/bin/nettop", ["-P", "-d", "-L", "2", "-s", "1", "-x", "-n", "-J", "bytes_in,bytes_out"]) else { return [:] }
            return NettopParser.parse(String(decoding: data, as: UTF8.self))
        }.value
    }
}

/// Runs a closure at most once across threads.
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func run(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        body()
    }
}

/// Bytes moved on the primary interface since midnight, persisted across launches.
private struct DailyTotals {
    var day: String
    var received: UInt64
    var sent: UInt64
    private var unsaved = 0

    private static let key = "network.today"

    static func load() -> DailyTotals {
        let stored = UserDefaults.standard.dictionary(forKey: key)
        var totals = DailyTotals(day: today(), received: 0, sent: 0)
        if stored?["day"] as? String == totals.day {
            totals.received = (stored?["received"] as? NSNumber)?.uint64Value ?? 0
            totals.sent = (stored?["sent"] as? NSNumber)?.uint64Value ?? 0
        }
        return totals
    }

    private static func today() -> String {
        Date().formatted(.iso8601.year().month().day())
    }

    mutating func add(received: UInt64, sent: UInt64) {
        let now = Self.today()
        if now != day {
            day = now
            self.received = 0
            self.sent = 0
        }
        self.received += received
        self.sent += sent
        unsaved += 1
        if unsaved >= 30 {
            unsaved = 0
            UserDefaults.standard.set(["day": day, "received": NSNumber(value: self.received), "sent": NSNumber(value: self.sent)], forKey: Self.key)
        }
    }
}
