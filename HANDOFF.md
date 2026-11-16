# Pulso: build handoff

Pulso is a menu bar system monitor for macOS. It shows CPU, memory, disk, network, battery and sensor readings in a translucent panel that drops from the menu bar, with desktop widgets, alerts and a settings window. The app ships in English and Portuguese (Brazil).

This document is the original specification the app was built from. The design files and this spec remain the reference; the app itself lives alongside them (see the table below and `README.md`).

## 1. What is in this repository

| Path | Contents |
| --- | --- |
| `design/index.html` | Gallery of every screen. Open it in a browser. |
| `design/en/`, `design/pt-BR/` | One standalone HTML file per screen, per language. All styling is inline. |
| `design/screenshots/` | PNG render of every screen in both languages, at 2x. |
| `design/tokens.json` | Shared colors, type, radii, spacing and sizes. |
| `localization/Localizable.xcstrings` | String Catalog in English and Portuguese (Brazil), extended as the app grew. |
| `brand/` | Brand kit: app icon, logo, menu bar glyph, palette and icon set. The app uses its asset catalog; `brand/ROLLOUT.md` is the brief that applied it. |
| `Pulso/`, `PulsoWidgets/`, `PulsoTests/` | App, widget extension and unit tests, in Swift and SwiftUI. `Pulso/Assets.xcassets` is a copy of `brand/xcode/Assets.xcassets`. |
| `project.yml` | XcodeGen spec for the Xcode project. |
| `scripts/`, `.github/workflows/` | DMG build and notarization script, CI and the release workflow. |
| `docs/` | Release guide and README screenshots. |
| `CLAUDE.md` | Working instructions for Claude Code. |

The HTML files are a visual reference, not something to embed. Read exact values (padding, radius, font size, color) from the inline styles. All numbers shown in the mockups are sample data for an imaginary MacBook Pro with an M3 Pro chip.

## 2. Screens

| Screen | File | What it is |
| --- | --- | --- |
| Overview | `overview.html` | The desktop with the menu bar item, the open overview panel and three desktop widgets. |
| CPU | `cpu.html` | Total usage with user and system split, 60 second chart, per-core bars (performance and efficiency), temperature, load average, GPU usage, top processes. |
| Memory | `memory.html` | Used memory, pressure state, breakdown bar (apps, wired, compressed, available), pressure chart, swap, cached, free, top processes. |
| Disk | `disk.html` | One card per mounted volume with free space and usage bar, eject for external volumes, read and write chart, SMART state, temperature, wear, top processes. |
| Network | `network.html` | Download and upload rates, mirrored chart, local and public IP with copy buttons, interface, latency, daily totals, top processes. |
| Battery | `battery.html` | Charge, time remaining, 12 hour level chart, health, cycles, temperature, power draw, Low Power Mode switch, Bluetooth device batteries. |
| Settings | `settings.html` | Settings window with a translucent sidebar. The CPU module pane is drawn; the other panes follow the same pattern. |
| Menu bar styles | `menubar-styles.html` | The seven widget styles a module can use in the menu bar: mini, line, bars, ring, speed, battery, dot. |

### Behavior that the static screens imply

- Clicking the menu bar item opens the overview panel directly under it. Clicking outside closes it.
- Each tile or row in the overview opens that module's panel in place. "Overview" at the top left goes back.
- The sliders button at the top right of a module panel opens the settings window on that module's pane.
- The pill at the top right of the overview reads "All normal" in green when no alert is active. When an alert is active it should name the problem (for example high CPU or critical memory pressure) in amber or coral.
- Charts hold 60 samples, one per second by default, and scroll left as new samples arrive.
- The menu bar item shows one widget per enabled module, in the order set in Settings. Menu bar widgets are monochrome by default so they match the system; the per-module color applies inside the panel and optionally in the menu bar.
- Desktop widgets come in small (CPU, memory) and medium (network) sizes.

### Not drawn yet

These are needed and should follow the patterns of the existing screens:

- Settings panes for General, Menu Bar, Alerts, Widgets and the remaining modules.
- A Sensors panel (all temperature sensors and fans) and a Bluetooth section in Settings.
- Light appearance. The design is dark glass only. Decide whether to follow the system appearance or stay dark (see Open decisions).
- Empty and error states: no battery (desktop Macs), no fan (MacBook Air), sensor access unavailable, network offline.

## 3. Design system

Full values are in `design/tokens.json`. The essentials:

- **Material.** Panels are dark translucent glass: a 66% dark tint over a strong background blur with boosted saturation, a 1 px light border, a soft top highlight and a deep shadow. Use the system materials (`NSVisualEffectView` or SwiftUI materials) rather than a custom blur. If the deployment target includes macOS 26, evaluate the Liquid Glass APIs for the panel and widgets.
- **Cards.** Content sits on cards filled with white at 8% opacity, radius 16. Stat cells use radius 14.
- **Type.** System font. Hero metrics use the rounded system design at semibold weight. Secondary text is white at 70% opacity. Use tabular (monospaced) digits for every value that updates in place so the layout does not jitter.
- **Color.** One accent per meaning: blue for CPU, download and read; teal for memory and efficiency cores; amber for disk; orange for upload, write and system CPU; green for battery and normal status; coral for sensors and critical status. Series that must be told apart also differ by position or label, never by hue alone.
- **Layout.** Panel width is 372 pt with 16 pt padding and 12 pt between sections.
- **Accessibility.** Every icon-only button has a label, every chart has a text description, and all text meets 4.5:1 contrast on the glass. Keep that when the wallpaper behind the panel is bright: the tint must stay dark enough.

## 4. Localization

The app must ship in English and Portuguese (Brazil).

- `localization/Localizable.xcstrings` is a String Catalog. English is the source language. Add it to the app target and extend it as new screens are built. Keys are semantic (`cpu.loadAverage`), not English text.
- Follow the system language by default. Add a Language setting in Settings, General with three options: System default, English, Português (Brasil). The keys already exist (`settings.language.*`). Language names are always shown in their own language.
- Entries marked "Needs plural variants" in their comment (`disk.volumesConnected`, `settings.updateInterval.seconds`) need proper plural rules in the catalog.
- Never assemble numbers by hand. Use locale-aware formatting for percentages, byte counts, transfer rates, temperatures, durations, dates and times. The two languages differ in more than words: Portuguese uses a decimal comma (11,2 GB), a period as the thousands separator (1.250 rpm) and 24 hour time (18:42); English uses a decimal point (11.2 GB), a comma (1,250 rpm) and 12 hour time (6:42 PM).
- Process names, volume names, network names and IP addresses are data and are never translated.
- The widget extension and notification text need the same catalog coverage as the app.

## 5. Suggested architecture

These are recommendations. Verify API names and availability against current Apple documentation before relying on them.

- **App type.** A menu bar only app (agent app, no Dock icon) written in Swift with SwiftUI views. Use AppKit for the status item and the panel window, since the menu bar item needs custom drawing of several small widgets and the panel needs precise positioning and dismissal behavior.
- **Targets.** The app, a widget extension (WidgetKit) for the desktop widgets, and optionally a privileged or unsandboxed helper if sensor access requires it.
- **Sampling.** One sampler per module, each publishing an observable snapshot plus a ring buffer of 60 samples. Samplers run only while their module is enabled, and the heavier ones (process lists, per-process network) run only while the panel is open. A single shared timer drives them at the configured interval.
- **State.** Settings in `UserDefaults` (shared with the widget extension through an app group).
- **Launch at login.** `SMAppService`.
- **Alerts.** `UserNotifications`, with thresholds and durations from Settings.

### Where each reading can come from

| Reading | Starting point |
| --- | --- |
| CPU total, user, system, idle, per core | Mach host statistics (`host_processor_info`, `host_statistics`) |
| Performance and efficiency core counts | `sysctl` (`hw.perflevel0.*`, `hw.perflevel1.*`) |
| Load average | `getloadavg` |
| Memory breakdown, swap | `host_statistics64` with VM info, `sysctl` (`hw.memsize`, `vm.swapusage`) |
| Memory pressure | Dispatch memory pressure source, or the kernel pressure level `sysctl` |
| Process lists (CPU, memory, disk) | `libproc` (`proc_listpids`, `proc_pidinfo`, `proc_pid_rusage`) |
| Volumes and free space | `FileManager` mounted volume URLs with resource values |
| Disk read and write rates | IOKit block storage driver statistics |
| SMART state, wear, SSD temperature | IOKit NVMe SMART interface |
| Eject | `NSWorkspace` unmount and eject, or DiskArbitration |
| Network rates and totals | `getifaddrs` interface byte counters |
| Local IP, interface | `getifaddrs`, SystemConfiguration |
| Wi-Fi network name | CoreWLAN (needs location permission on recent macOS) |
| Public IP | An HTTPS request to an external service; opt in only |
| Latency | Network framework or ICMP ping to a configurable host |
| Per-process network traffic | No clean public API; parsing `nettop` output is the usual route |
| Battery charge, state, time remaining | IOKit power sources (`IOPSCopyPowerSourcesInfo`) |
| Battery health, cycles, temperature, power draw | IOKit registry, `AppleSmartBattery` |
| Low Power Mode state | `ProcessInfo.isLowPowerModeEnabled` |
| Bluetooth device batteries | IOKit registry and IOBluetooth |
| Temperatures and fans | SMC keys through IOKit on Intel; HID thermal sensors on Apple Silicon. Neither is public API. |
| GPU usage | IOKit accelerator performance statistics |

## 6. Open decisions

Ask the owner before settling any of these.

Settled on 2026-11-15:

- **Distribution:** outside the Mac App Store, Developer ID and notarized, unsandboxed, with full sensors.
- **Minimum macOS:** 26. The panel uses Liquid Glass (`NSGlassEffectView`).
- **Appearance:** dark glass only.
- **Name and bundle identifier:** Pulso is the final name, with the bundle identifier `com.edew.pulso`.
- **License:** MIT, open source.
- **Low Power Mode:** shown read-only; the switch opens Battery settings.
- **Public IP:** opt-in, off by default, looked up at api.ipify.org while the network panel is open.
- **Per-process network and disk:** both in v1. Disk from `proc_pid_rusage`, network from `nettop`, each only while its panel is open.
- **Widget refresh:** the app asks WidgetKit for a reload about once a minute; each widget shows the time its data was taken.

1. **Distribution.** Temperature and fan readings rely on private interfaces that do not work inside the App Sandbox. Either distribute outside the Mac App Store (Developer ID, notarized) with full sensors, or ship a sandboxed App Store build without them.
2. **Low Power Mode switch.** Reading the state is public API. Changing it is not: it needs `pmset` with administrator rights or a Shortcuts action. Options are a privileged helper, opening Battery settings instead, or showing the state read-only.
3. **Public IP.** It requires contacting an external server. Keep it off by default and say so in Settings.
4. **Per-process network and disk.** Both are costly to sample and network has no public API. They could be dropped from v1.
5. **Minimum macOS version.** This decides which materials, charting and widget APIs are available.
6. **Appearance.** Dark glass only, or follow the system light and dark setting.
7. **Widget refresh.** WidgetKit budgets timeline refreshes, so desktop widgets cannot update every second. Decide what cadence is acceptable and whether to label the last update time.
8. **Name and bundle identifier.**

## 7. Suggested build order

1. Project skeleton: agent app, status item, empty panel with the glass material, positioned and dismissed correctly.
2. CPU and memory samplers with the overview tiles and the menu bar widgets (mini, bars, ring).
3. CPU and memory panels, including charts and process lists.
4. Disk, network and battery samplers and panels.
5. Settings window: General (language, launch at login), Menu Bar (order and style), module panes.
6. Localization pass in both languages, including formatters.
7. Alerts and notifications.
8. Sensors, behind the distribution decision.
9. Widget extension.

## 8. Acceptance checklist

- Each built screen matches its screenshot in layout, spacing, type and color, in both languages.
- Switching the Language setting changes every string, number, date and unit format.
- No hardcoded user-facing strings remain outside the String Catalog.
- With the panel closed, the app's own CPU usage stays well under 1% on average.
- VoiceOver reads every control and gives each chart a meaningful description.
- The app behaves sensibly on a Mac with no battery, no fan and no network connection.
