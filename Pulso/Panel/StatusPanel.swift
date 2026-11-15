import AppKit
import SwiftUI

/// Borderless glass panel that drops from the status item and closes on any outside click or Escape.
@MainActor
final class StatusPanel: NSPanel {
    private let hostingView: NSView
    private weak var anchorButton: NSStatusBarButton?
    private var outsideClickMonitor: Any?

    init(rootView: some View) {
        hostingView = NSHostingView(rootView: rootView)
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        appearance = NSAppearance(named: .darkAqua)

        let glass = NSGlassEffectView()
        glass.cornerRadius = Theme.panelRadius
        glass.tintColor = Theme.panelTint
        glass.contentView = hostingView
        contentView = glass
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) { close() }

    override func resignKey() {
        super.resignKey()
        close()
    }

    func toggle(below button: NSStatusBarButton) {
        isVisible ? close() : show(below: button)
    }

    private func show(below button: NSStatusBarButton) {
        guard let buttonWindow = button.window, let screen = buttonWindow.screen else { return }
        let size = hostingView.fittingSize
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let bounds = screen.visibleFrame.insetBy(dx: Theme.panelScreenMargin, dy: 0)
        // Right-align with the status item, but stay fully on screen.
        let x = min(max(anchor.maxX - size.width, bounds.minX), bounds.maxX - size.width)
        let y = buttonWindow.frame.minY - Theme.panelGapBelowMenuBar - size.height
        setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)

        makeKeyAndOrderFront(nil)
        anchorButton = button
        button.highlight(true)
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    override func close() {
        super.close()
        anchorButton?.highlight(false)
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }
}
