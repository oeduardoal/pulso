import AppKit
import SwiftUI

struct OverviewView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.panelSpacing) {
            Text("overview.title")
                .font(.system(size: 15, weight: .semibold))
                .padding(EdgeInsets(top: 2, leading: 4, bottom: 4, trailing: 4))

            HStack(spacing: 8) {
                PanelButton("action.activityMonitor", action: openActivityMonitor)
                PanelButton("action.settings") {
                    NSApp.activate()
                    openSettings()
                }
            }
            .padding(.top, 2)
        }
        .padding(Theme.panelPadding)
        .frame(width: Theme.panelWidth, alignment: .leading)
        .foregroundStyle(Theme.textPrimary)
        .overlay {
            RoundedRectangle(cornerRadius: Theme.panelRadius)
                .strokeBorder(Theme.panelBorder)
        }
    }

    private func openActivityMonitor() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
}

private struct PanelButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(Theme.control, in: .rect(cornerRadius: Theme.buttonRadius))
                .contentShape(.rect(cornerRadius: Theme.buttonRadius))
        }
        .buttonStyle(.plain)
    }
}
