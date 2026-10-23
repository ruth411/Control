import AppKit
import ServiceManagement
@preconcurrency import ApplicationServices

@MainActor
final class ControlDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var appTracker: AppTracker?
    private var wheelController: WheelWindowController?
    private var keyMonitor: KeyMonitor?
    private var launchAtLoginMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configureLaunchAtLogin()
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
        let launchAtLoginItem = menu.addItem(
            withTitle: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginMenuItem = launchAtLoginItem
        updateLaunchAtLoginMenuItem()
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu
        self.statusItem = statusItem
    }

    private func configureLaunchAtLogin() {
        let service = SMAppService.mainApp
        if service.status == .notRegistered {
            try? service.register()
        }
        updateLaunchAtLoginMenuItem()
    }

    private func updateLaunchAtLoginMenuItem() {
        launchAtLoginMenuItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp

        do {
            if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            } else {
                try service.register()
            }
            updateLaunchAtLoginMenuItem()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Unable to Update Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
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
