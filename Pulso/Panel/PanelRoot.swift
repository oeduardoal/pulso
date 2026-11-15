import SwiftUI

/// Content of the status panel: the overview or one module panel, swapped in place.
struct PanelRoot: View {
    @Environment(Monitor.self) private var monitor
    let onHeightChange: (CGFloat) -> Void

    var body: some View {
        // A closed panel renders nothing, so it stops observing the monitor and costs no CPU.
        if monitor.isPanelOpen { panel }
    }

    private var panel: some View {
        ScrollView(.vertical) {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeightChange($0) }
        }
        .defaultScrollAnchor(.top)
        .scrollIndicators(.never)
        .scrollBounceBehavior(.basedOnSize)
        // A fresh scroll view per screen, so a new panel never inherits the previous offset.
        .id(monitor.route)
        .foregroundStyle(Theme.textPrimary)
        .environment(\.colorScheme, .dark)
        .overlay {
            RoundedRectangle(cornerRadius: Theme.panelRadius).strokeBorder(Theme.panelBorder)
        }
    }

    private var content: some View {
        Group {
            switch monitor.route {
            case nil: OverviewView()
            case .cpu: CPUPanel()
            case .memory: MemoryPanel()
            case .disk: DiskPanel()
            case .network: NetworkPanel()
            case .battery: BatteryPanel()
            case .sensors: SensorsPanel()
            }
        }
        .padding(Theme.panelPadding)
        .frame(width: Theme.panelWidth, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }
}
