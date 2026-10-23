@preconcurrency import AppKit
import CoreGraphics

@MainActor
final class WheelWindowController {
    private let appTracker: AppTracker
    private var overlayWindow: NSWindow?
    private var wheelView: WheelView?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var mouseTrackingTimer: Timer?

    init(appTracker: AppTracker) {
        self.appTracker = appTracker
    }

    func showWheel() {
        let apps = appTracker.topApps()
        guard !apps.isEmpty else { return }

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first else { return }

        let visibleFrame = screen.visibleFrame
        let rawCenter = NSPoint(
            x: mouseLocation.x - screen.frame.origin.x,
            y: mouseLocation.y - screen.frame.origin.y
        )
        let clampedCenter = clampedCenter(
            rawCenter,
            visibleFrame: visibleFrame,
            screenFrame: screen.frame,
            radius: WheelView.outerRadius
        )

        let center = clampedCenter
        let window = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let wheelView = WheelView(frame: NSRect(origin: .zero, size: screen.frame.size), apps: apps, center: center)
        window.contentView = wheelView
        overlayWindow = window
        self.wheelView = wheelView
        window.orderFrontRegardless()
        installMouseMonitors()
        updateMousePosition()
    }

    private func clampedCenter(
        _ center: NSPoint,
        visibleFrame: NSRect,
        screenFrame: NSRect,
        radius: CGFloat
    ) -> NSPoint {
        let minX = visibleFrame.minX - screenFrame.origin.x + radius
        let maxX = visibleFrame.maxX - screenFrame.origin.x - radius
        let minY = visibleFrame.minY - screenFrame.origin.y + radius
        let maxY = visibleFrame.maxY - screenFrame.origin.y - radius

        return NSPoint(
            x: min(max(center.x, minX), maxX),
            y: min(max(center.y, minY), maxY)
        )
    }

    func selectAndHide() {
        let selectedApp = wheelView?.selectedApp
        hideWheel()
        guard let selectedApp else { return }
        dismissMissionControlIfNeeded()
        waitForMissionControlToDismiss(selectedApp, attemptsRemaining: 12)
    }

    private func waitForMissionControlToDismiss(
        _ selectedApp: NSRunningApplication,
        attemptsRemaining: Int
    ) {
        let missionControlIsVisible = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.dock"
        guard missionControlIsVisible, attemptsRemaining > 0 else {
            activateSelectedApp(selectedApp)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.waitForMissionControlToDismiss(
                selectedApp,
                attemptsRemaining: attemptsRemaining - 1
            )
        }
    }

    private func activateSelectedApp(_ selectedApp: NSRunningApplication) {
        if #available(macOS 14.0, *) {
            NSApp.yieldActivation(to: selectedApp)
        }

        guard let bundleURL = selectedApp.bundleURL else {
            selectedApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.allowsRunningApplicationSubstitution = true
        configuration.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration)
    }

    func cancelAndHide() {
        hideWheel()
    }

    private func dismissMissionControlIfNeeded() {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.dock" else { return }
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else { return }

        let escapeKeyCode: CGKeyCode = 53
        let keyDown = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: escapeKeyCode,
            keyDown: true
        )
        let keyUp = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: escapeKeyCode,
            keyDown: false
        )

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func installMouseMonitors() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in self?.updateMousePosition() }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.updateMousePosition()
            return event
        }
        mouseTrackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateMousePosition()
        }
    }

    private func hideWheel() {
        [globalMouseMonitor, localMouseMonitor].compactMap { $0 }.forEach(NSEvent.removeMonitor)
        globalMouseMonitor = nil
        localMouseMonitor = nil
        mouseTrackingTimer?.invalidate()
        mouseTrackingTimer = nil
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        wheelView = nil
    }

    private func updateMousePosition() {
        guard let window = overlayWindow, let wheelView else { return }
        let mouseLocation = NSEvent.mouseLocation
        wheelView.updateSelection(at: NSPoint(x: mouseLocation.x - window.frame.origin.x, y: mouseLocation.y - window.frame.origin.y))
    }
}
