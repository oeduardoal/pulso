import Foundation

/// The readings the desktop widgets show. The app writes it to the shared app group container;
/// the widget extension reads it when WidgetKit refreshes its timeline.
struct WidgetSnapshot: Codable {
    static let appGroup = "6HC4RKRHXD.com.edew.pulso"

    var date: Date
    var cpu: Double
    var cpuTemperature: Double?
    var coreCount: Int
    var memoryUsed: UInt64
    var memoryTotal: UInt64
    var download: Double
    var upload: Double
    var downloadHistory: [Double]
    var uploadHistory: [Double]
    var interfaceName: String?

    var memoryFraction: Double { memoryTotal > 0 ? Double(memoryUsed) / Double(memoryTotal) : 0 }

    private static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("snapshot.json")
    }

    func save() -> Bool {
        guard let url = Self.url, let data = try? JSONEncoder().encode(self) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    static func load() -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static let placeholder = WidgetSnapshot(
        date: Date(), cpu: 0.18, cpuTemperature: 54, coreCount: 10,
        memoryUsed: 11_200_000_000, memoryTotal: 18 * 1_073_741_824,
        download: 2_400_000, upload: 310_000,
        downloadHistory: (0..<30).map { 1_500_000 + sin(Double($0) / 3) * 800_000 },
        uploadHistory: (0..<30).map { 300_000 + cos(Double($0) / 2) * 80_000 },
        interfaceName: "Wi-Fi"
    )
}
