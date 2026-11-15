import Foundation

/// Rolling window of the most recent samples for a chart.
struct Series: Equatable {
    static let capacity = 60
    private(set) var values: [Double] = []

    mutating func append(_ value: Double) {
        values.append(value)
        if values.count > Self.capacity { values.removeFirst(values.count - Self.capacity) }
    }

    var last: Double { values.last ?? 0 }
    var peak: Double { values.max() ?? 0 }
}

enum SysctlValue {
    static func int(_ name: String) -> Int? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        // Some keys are 32-bit; sysctl fills only the low bytes.
        return size == MemoryLayout<Int32>.size ? Int(Int32(truncatingIfNeeded: value)) : Int(value)
    }

    static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cBuffer: buffer)
    }
}

extension String {
    /// Decodes a NUL-terminated C buffer.
    init(cBuffer: [CChar]) {
        self.init(decoding: cBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
