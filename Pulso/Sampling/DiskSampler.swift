import AppKit
import DiskArbitration

struct Volume: Identifiable, Equatable {
    let url: URL
    let name: String
    let total: UInt64
    let free: UInt64
    let isInternal: Bool
    let isEjectable: Bool
    let isStartup: Bool
    let format: String
    let connection: String?

    var id: URL { url }
    var used: UInt64 { total > free ? total - free : 0 }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }

    var detail: String {
        if isInternal { return L("disk.internal", format) }
        return L("disk.external", connection ?? "", format)
    }
}

struct SMARTStatus: Equatable {
    var temperature: Double
    var wear: Double
    var healthy: Bool
}

struct DiskSampler {
    private var previous: (read: UInt64, write: UInt64)?
    private var previousTime = Date()

    /// Bytes per second read and written across all drives since the last call.
    mutating func sampleRates() -> (read: Double, write: Double) {
        var read: UInt64 = 0, write: UInt64 = 0
        guard PulsoDiskIOBytes(&read, &write) else { return (0, 0) }
        let now = Date()
        defer {
            previous = (read, write)
            previousTime = now
        }
        guard let previous else { return (0, 0) }
        let elapsed = max(now.timeIntervalSince(previousTime), 0.001)
        return (Double(read &- previous.read) / elapsed, Double(write &- previous.write) / elapsed)
    }

    private static let keys: [URLResourceKey] = [
            .volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey, .volumeIsInternalKey,
            .volumeIsRootFileSystemKey, .volumeLocalizedFormatDescriptionKey, .volumeIsBrowsableKey,
    ]

    /// Every mounted volume. Enumerating mounts costs tens of milliseconds, so this runs only
    /// while the disk panel is open.
    static func volumes() -> [Volume] {
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        let session = DASessionCreate(kCFAllocatorDefault)
        return urls.compactMap { volume(at: $0, session: session) }
            .sorted { ($0.isStartup ? 0 : 1, $0.name) < ($1.isStartup ? 0 : 1, $1.name) }
    }

    /// Just the startup volume, cheap enough for the menu bar and alerts.
    static func startupVolume() -> Volume? {
        volume(at: URL(fileURLWithPath: "/"), session: nil)
    }

    private static func volume(at url: URL, session: DASession?) -> Volume? {
        guard let values = try? url.resourceValues(forKeys: Set(keys)),
              values.volumeIsBrowsable != false,
              let total = values.volumeTotalCapacity, total > 0 else { return nil }
        let free = values.volumeAvailableCapacityForImportantUsage.map { UInt64(max(0, $0)) }
            ?? UInt64(values.volumeAvailableCapacity ?? 0)
        let isInternal = values.volumeIsInternal ?? false
        return Volume(
            url: url,
            name: values.volumeName ?? url.lastPathComponent,
            total: UInt64(total),
            free: free,
            isInternal: isInternal,
            isEjectable: !isInternal,
            isStartup: values.volumeIsRootFileSystem ?? false,
            format: (values.volumeLocalizedFormatDescription ?? "").components(separatedBy: " (").first ?? "",
            connection: isInternal ? nil : session.flatMap { connection(of: url, session: $0) }
        )
    }

    private static func connection(of url: URL, session: DASession) -> String? {
        guard let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL),
              let description = DADiskCopyDescription(disk) as? [CFString: Any] else { return nil }
        return description[kDADiskDescriptionDeviceProtocolKey] as? String
    }

    static func smart() -> SMARTStatus? {
        var raw = PulsoSMART()
        guard PulsoReadNVMeSMART(&raw) else { return nil }
        return SMARTStatus(
            temperature: Double(raw.temperatureCelsius),
            wear: Double(raw.percentageUsed) / 100,
            healthy: raw.criticalWarning == 0
        )
    }

    @MainActor
    static func eject(_ volume: Volume) {
        try? NSWorkspace.shared.unmountAndEjectDevice(at: volume.url)
    }
}
