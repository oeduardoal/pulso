import Foundation
import Observation
import UserNotifications

struct ActiveAlert: Identifiable, Equatable {
    enum Kind: String { case cpu, memory, disk, battery, temperature }
    let kind: Kind
    let title: String
    let isCritical: Bool
    var id: Kind { kind }
}

/// Turns readings into alerts: the status pill in the overview and a notification when an alert starts.
@MainActor
@Observable
final class AlertEngine {
    private(set) var active: [ActiveAlert] = []
    @ObservationIgnored private var cpuAboveSince: Date?
    @ObservationIgnored private var notified: Set<ActiveAlert.Kind> = []
    @ObservationIgnored private var authorized = false

    func requestAuthorization() {
        Task {
            authorized = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    func evaluate(_ monitor: Monitor) {
        let defaults = UserDefaults.standard
        var alerts: [ActiveAlert] = []

        if defaults.bool(forKey: Pref.alertCPU), Pref.isEnabled(.cpu) {
            let threshold = Double(defaults.integer(forKey: Pref.alertCPUThreshold)) / 100
            let duration = TimeInterval(defaults.integer(forKey: Pref.alertCPUDuration))
            if monitor.cpu.total >= threshold {
                cpuAboveSince = cpuAboveSince ?? Date()
                if let since = cpuAboveSince, Date().timeIntervalSince(since) >= duration {
                    alerts.append(ActiveAlert(kind: .cpu, title: L("overview.status.cpu"), isCritical: false))
                    notify(.cpu, title: L("alert.cpu.title"), body: L("alert.cpu.body", Format.percent(threshold), Int(duration)))
                }
            } else {
                cpuAboveSince = nil
            }
        }

        if Pref.isEnabled(.memory), monitor.memory.pressure != .normal {
            let critical = monitor.memory.pressure == .critical
            alerts.append(ActiveAlert(kind: .memory, title: monitor.memory.pressure.title, isCritical: critical))
            if critical, defaults.bool(forKey: Pref.alertMemory) {
                notify(.memory, title: L("alert.memory.title"), body: L("alert.memory.body"))
            }
        }

        if defaults.bool(forKey: Pref.alertDisk), Pref.isEnabled(.disk),
           let startup = monitor.volumes.first(where: \.isStartup), startup.total > 0 {
            let threshold = Double(defaults.integer(forKey: Pref.alertDiskThreshold)) / 100
            if Double(startup.free) / Double(startup.total) < threshold {
                alerts.append(ActiveAlert(kind: .disk, title: L("overview.status.disk"), isCritical: false))
                notify(.disk, title: L("alert.disk.title"), body: L("alert.disk.body", startup.name, Format.storage(startup.free)))
            }
        }

        let battery = monitor.battery
        if defaults.bool(forKey: Pref.alertBattery), Pref.isEnabled(.battery), battery.isPresent, !battery.isPluggedIn {
            let threshold = Double(defaults.integer(forKey: Pref.alertBatteryThreshold)) / 100
            if battery.level <= threshold {
                alerts.append(ActiveAlert(kind: .battery, title: L("overview.status.battery"), isCritical: battery.level <= 0.05))
                notify(.battery, title: L("alert.battery.title"), body: L("alert.battery.body", Format.percent(battery.level)))
            }
        }

        if defaults.bool(forKey: Pref.alertTemperature), let cpuTemperature = monitor.sensors.cpu {
            let threshold = Double(defaults.integer(forKey: Pref.alertTemperatureThreshold))
            if cpuTemperature >= threshold {
                alerts.append(ActiveAlert(kind: .temperature, title: L("overview.status.temperature"), isCritical: true))
                notify(.temperature, title: L("alert.temperature.title"), body: L("alert.temperature.body", Format.temperature(cpuTemperature)))
            }
        }

        // Let an alert notify again once it has cleared.
        notified.formIntersection(alerts.map(\.kind))
        let sorted = alerts.sorted { $0.isCritical && !$1.isCritical }
        if sorted != active { active = sorted }
    }

    private func notify(_ kind: ActiveAlert.Kind, title: String, body: String) {
        guard !notified.contains(kind) else { return }
        notified.insert(kind)
        guard authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: "pulso.\(kind.rawValue)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
