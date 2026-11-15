import AppKit
import SwiftUI

/// Borderless glass panel that drops from the status item and closes on any outside click or Escape.
@MainActor
final class StatusPanel: NSPanel {
    private weak var anchorButton: NSStatusBarButton?
    private var outsideClickMonitor: Any?
    private var contentHeight: CGFloat = 300

    init(actions: PanelActions) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Theme.panelWidth, height: 300),
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

        let root = PanelRoot { [weak self] height in self?.contentHeightChanged(height) }
            .environment(Monitor.shared)
            .environment(\.panelActions, actions)
        let hostingView = NSHostingView(rootView: root)
        hostingView.sizingOptions = []

        // The glass and the SwiftUI content are siblings in a container that pins both to its bounds.
        let container = FillContainerView()
        let glass = NSGlassEffectView()
        glass.cornerRadius = Theme.panelRadius
        glass.tintColor = Theme.panelTint
        for view in [glass, hostingView] as [NSView] {
            container.addSubview(view)
        }
        contentView = container
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
        anchorButton = button
        Monitor.shared.isPanelOpen = true
        layout(animated: false)
        makeKeyAndOrderFront(nil)
        button.highlight(true)
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    private func contentHeightChanged(_ height: CGFloat) {
        guard abs(height - contentHeight) > 0.5 else { return }
        contentHeight = height
        // Resizing the window inside SwiftUI's layout pass applies the change twice; wait for the pass to end.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isVisible else { return }
            self.layout(animated: false)
        }
    }

    /// Places the panel under the status item, right-aligned with it, keeping the top edge fixed
    /// as the content grows or shrinks. Content taller than the screen scrolls.
    private func layout(animated: Bool) {
        guard let button = anchorButton, let buttonWindow = button.window, let screen = buttonWindow.screen else { return }
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let bounds = screen.visibleFrame.insetBy(dx: Theme.panelScreenMargin, dy: Theme.panelScreenMargin)
        let top = buttonWindow.frame.minY - Theme.panelGapBelowMenuBar
        let height = min(contentHeight, top - bounds.minY)
        let width = Theme.panelWidth
        let x = min(max(anchor.maxX - width, bounds.minX), bounds.maxX - width)
        setFrame(NSRect(x: x, y: top - height, width: width, height: height), display: true, animate: animated)
        contentView?.subviews.forEach { $0.frame = contentView?.bounds ?? .zero }
    }

    override func close() {
        guard isVisible else { return }
        super.close()
        anchorButton?.highlight(false)
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
        Monitor.shared.isPanelOpen = false
    }
}

private final class FillContainerView: NSView {
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        subviews.forEach { $0.frame = bounds }
    }

    override func didAddSubview(_ subview: NSView) {
        subview.frame = bounds
    }
}
