import AppKit
import ApplicationServices

/// Watches for Command+Option being pressed together (and nothing else) to
/// trigger "Talk to Nest", both when the app is frontmost and when it isn't.
///
/// System-wide key monitoring outside the app's own window requires the app
/// to be trusted for Accessibility (System Settings ▸ Privacy & Security ▸
/// Accessibility) — macOS will not deliver global key/modifier events to an
/// untrusted process. `requestAccessibilityIfNeeded()` prompts for that the
/// first time it's needed; until granted, the hotkey only works while Nest
/// itself is the frontmost app (the local monitor still fires).
final class GlobalHotkeyMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var wasComboActive = false
    private let onTrigger: () -> Void

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    static func requestAccessibilityIfNeeded() {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func start() {
        stop()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    /// Fires once on the transition into "exactly Command+Option held", not
    /// on every flagsChanged event (which fires for press AND release, and
    /// for each modifier key individually).
    private func handle(_ event: NSEvent) {
        let relevant = event.modifierFlags.intersection([.command, .option, .shift, .control, .capsLock])
        let comboActive = relevant == [.command, .option]
        if comboActive && !wasComboActive {
            onTrigger()
        }
        wasComboActive = comboActive
    }

    deinit {
        stop()
    }
}
