import AppKit
@preconcurrency import ApplicationServices

@MainActor
final class ControlDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var appTracker: AppTracker?
    private var wheelController: WheelWindowController?
    private var keyMonitor: KeyMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        let appTracker = AppTracker()
        let wheelController = WheelWindowController(appTracker: appTracker)
        keyMonitor = KeyMonitor(
            onLongPress: { wheelController.showWheel() },
            onRelease: { wheelController.selectAndHide() },
            onCancel: { wheelController.cancelAndHide() }
        )
        self.appTracker = appTracker
        self.wheelController = wheelController
        requestAccessibilityPermission()
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(systemSymbolName: "circle.grid.cross", accessibilityDescription: "Control") {
            statusItem.button?.image = image
        } else {
            statusItem.button?.title = "⊕"
        }
        statusItem.button?.toolTip = "Control"

        let menu = NSMenu()
        menu.addItem(withTitle: "About Control", action: #selector(showAbout), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu
        self.statusItem = statusItem
    }

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary

        guard !AXIsProcessTrustedWithOptions(options) else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = "Enable Control in System Settings → Privacy & Security → Accessibility, then relaunch Control."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
