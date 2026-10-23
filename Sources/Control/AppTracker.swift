@preconcurrency import AppKit

@MainActor
final class AppTracker {
    private let maxApps = 6
    private var recentApps: [NSRunningApplication]
    private var observers: [NSObjectProtocol] = []

    init(workspace: NSWorkspace = .shared) {
        recentApps = workspace.runningApplications.filter(Self.isEligible)
        let center = workspace.notificationCenter
        observers = [
            center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
                self?.appDidActivate(notification)
            },
            center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
                self?.appDidTerminate(notification)
            }
        ]
    }

    deinit {
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
    }

    func topApps() -> [NSRunningApplication] {
        recentApps.removeAll(where: { $0.isTerminated || !isEligible($0) })
        return Array(recentApps.prefix(maxApps))
    }

    private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, isEligible(app) else { return }
        recentApps.removeAll { $0.processIdentifier == app.processIdentifier }
        recentApps.insert(app, at: 0)
        recentApps = Array(recentApps.prefix(maxApps * 2))
    }

    private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        recentApps.removeAll { $0.processIdentifier == app.processIdentifier }
    }

    private static func isEligible(_ app: NSRunningApplication) -> Bool {
        app.activationPolicy == .regular && app.bundleIdentifier != Bundle.main.bundleIdentifier && !app.isTerminated
    }

    private func isEligible(_ app: NSRunningApplication) -> Bool {
        Self.isEligible(app)
    }
}
