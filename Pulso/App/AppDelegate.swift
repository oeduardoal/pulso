import AppKit
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var retained: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        retained = delegate // NSApplication.delegate is weak.
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    private var statusItem: NSStatusItem!
    private var panel: StatusPanel!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Pref.register()
        Monitor.shared.start()
        Monitor.shared.alerts.requestAuthorization()

        panel = StatusPanel(actions: PanelActions(
            openSettings: { [weak self] module in self?.openSettings(module) },
            close: { [weak self] in self?.panel.close() }
        ))
        setUpStatusItem()
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel(L("app.name"))

        let content = MenuBarView { [weak self] width in
            // Changing the length relayouts the whole status bar, so only do it when it really changes.
            guard let self, self.statusItem.length != ceil(width) else { return }
            self.statusItem.length = ceil(width)
        }
            .environment(Monitor.shared)
        let hostingView = PassthroughHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])

        #if DEBUG
        // Debug aid: `-PulsoSnapshotMenuBar /path.png` saves the status item, which may sit behind the notch.
        if let path = UserDefaults.standard.string(forKey: "PulsoSnapshotMenuBar") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                guard let rep = button.bitmapImageRepForCachingDisplay(in: button.bounds) else { return }
                button.cacheDisplay(in: button.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            }
        }
        #endif
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            panel.close()
            showContextMenu(from: sender)
        } else {
            panel.toggle(below: sender)
        }
    }

    // An agent app has no Dock icon or main menu, so About, Settings and Quit live on the right-click menu.
    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        let about = NSMenuItem(title: L("action.about"), action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        let settings = NSMenuItem(title: L("action.settings"), action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(withTitle: L("action.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 6), in: button)
    }

    @objc private func openSettingsFromMenu() { openSettings(nil) }

    /// The standard About panel: icon, name, version and copyright from the bundle, plus a link to the repository.
    @objc private func showAbout() {
        let credits = NSAttributedString(
            string: L("about.repository"),
            attributes: [
                .link: URL(string: "https://github.com/oeduardoal/pulso")!,
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            ]
        )
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    private func openSettings(_ module: Module?) {
        panel.close()
        if let module { SettingsRouter.shared.selection = .module(module) }
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView().environment(SettingsRouter.shared))
            let window = NSWindow(contentViewController: controller)
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.title = L("settings.title")
            window.appearance = NSAppearance(named: .darkAqua)
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 820, height: 560))
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
