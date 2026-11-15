import SwiftUI

@main
struct PulsoApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
