@preconcurrency import AppKit

@MainActor
final class KeyMonitor {
    private final class MonitorToken: @unchecked Sendable {
        let value: Any

        init(_ value: Any) {
            self.value = value
        }
    }

    private let holdDuration: TimeInterval = 0.1
    private let onLongPress: () -> Void
    private let onRelease: () -> Void
    private let onCancel: () -> Void
    private var longPressTimer: Timer?
    private var isWheelShowing = false
    private var globalFlagsMonitor: MonitorToken?
    private var localFlagsMonitor: MonitorToken?
    private var globalKeyMonitor: MonitorToken?
    private var localKeyMonitor: MonitorToken?

    init(onLongPress: @escaping () -> Void, onRelease: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onLongPress = onLongPress
        self.onRelease = onRelease
        self.onCancel = onCancel
        installMonitors()
    }

    deinit {
        [globalFlagsMonitor, localFlagsMonitor, globalKeyMonitor, localKeyMonitor].compactMap { $0 }.forEach { NSEvent.removeMonitor($0.value) }
    }

    private func installMonitors() {
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }.map(MonitorToken.init)
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }.map(MonitorToken.init)
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            self?.cancelForKeyDown()
        }.map(MonitorToken.init)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.cancelForKeyDown()
            return event
        }.map(MonitorToken.init)
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        if event.modifierFlags.contains(.control), !isWheelShowing {
            longPressTimer?.invalidate()
            longPressTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, !self.isWheelShowing else { return }
                    self.isWheelShowing = true
                    self.onLongPress()
                }
            }
        } else if !event.modifierFlags.contains(.control) {
            longPressTimer?.invalidate()
            longPressTimer = nil
            guard isWheelShowing else { return }
            isWheelShowing = false
            onRelease()
        }
    }

    private func cancelForKeyDown() {
        guard isWheelShowing else { return }
        longPressTimer?.invalidate()
        isWheelShowing = false
        onCancel()
    }
}
