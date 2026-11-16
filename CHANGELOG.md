# Changelog

All notable changes to Pulso are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- App icon, shown in Finder, Login Items, notification settings and notification banners.
- The Pulso glyph in the menu bar when every module's widget is hidden.

## [0.1.0] - 2026-11-15

### Added

- Menu bar app with no Dock icon and a Liquid Glass panel that opens under the status item and closes on an outside click or Escape.
- Overview with CPU, memory, startup disk, network, battery and sensor readings, and a status pill that names any active alert.
- CPU panel: user, system and idle split, 60 second chart, per-core usage for performance and efficiency cores, temperature, load average, GPU usage and top processes.
- Memory panel: used memory, pressure state and chart, apps, wired, compressed and available breakdown, swap, cached, free and top processes.
- Disk panel: one card per volume with eject for external drives, read and write chart, SMART state, SSD temperature and wear, and top processes by disk activity.
- Network panel: download and upload rates with a mirrored chart, local and opt-in public IP with copy buttons, interface and Wi-Fi standard, latency, daily totals and top processes by traffic.
- Battery panel: charge, time remaining or until full, 12 hour level history, health, cycles, temperature, power draw, Low Power Mode state and Bluetooth device batteries.
- Sensors panel: CPU, SSD and battery temperatures, fans, and every sensor the Mac exposes.
- Menu bar widgets in seven styles (mini, line, bars, ring, speed, battery, dot), monochrome by default with an optional color per module.
- Settings window: language override with relaunch, launch at login, menu bar order, alert thresholds, widget updates and a pane per module.
- Notifications for sustained high CPU, critical memory pressure, low disk space, low battery and high temperature.
- Desktop widgets for CPU and memory (small) and network (medium), showing when their data was taken.
- Compact menu bar layout, values at a fixed width so the menu bar never shifts, and a menu bar refresh interval per module (5 seconds by default).
- Release workflow that builds a Developer ID signed, notarized DMG and publishes it on GitHub.
- English and Portuguese (Brazil) throughout, with locale-aware numbers, sizes, rates, temperatures, durations and times.

[Unreleased]: https://github.com/oeduardoal/pulso/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/oeduardoal/pulso/releases/tag/v0.1.0
