import Foundation
import SwiftUI

/// Orchestrates "Talk to Nest": the ⌘⌥ hotkey, the optional "Hey Nest" wake
/// word, and routing whatever's heard into a search. Owns the hotkey monitor
/// and the speech service; `AppState` owns whether any of this is enabled.
@MainActor
final class VoiceCoordinator: ObservableObject {
    enum OverlayState: Equatable {
        case hidden
        case listening
        case processing(String)
        case done(String)
        case failed(String)
    }

    @Published private(set) var overlay: OverlayState = .hidden

    private let appState: AppState
    private let speech = VoiceCommandService()
    private var hotkey: GlobalHotkeyMonitor?
    private var hideTask: Task<Void, Never>?

    init(appState: AppState) {
        self.appState = appState
        hotkey = GlobalHotkeyMonitor { [weak self] in
            Task { @MainActor in self?.activateFromHotkey() }
        }
    }

    /// Call once at launch: arms the hotkey if voice commands are enabled,
    /// and starts wake-word listening if that's also opted into.
    func start() {
        guard appState.voiceCommandsEnabled else { return }
        hotkey?.start()
        GlobalHotkeyMonitor.requestAccessibilityIfNeeded()
        if appState.wakeWordEnabled {
            startWakeWordIfNeeded()
        }
    }

    func stop() {
        hotkey?.stop()
        speech.stopWakeWordListening()
    }

    /// Called by Settings when the user toggles voice commands or the wake word on/off.
    func refresh() {
        if appState.voiceCommandsEnabled {
            hotkey?.start()
        } else {
            hotkey?.stop()
        }
        if appState.voiceCommandsEnabled && appState.wakeWordEnabled {
            startWakeWordIfNeeded()
        } else {
            speech.stopWakeWordListening()
        }
    }

    private func startWakeWordIfNeeded() {
        speech.startWakeWordListening { [weak self] command in
            guard let self else { return }
            if command.isEmpty {
                self.activateFromHotkey() // "Hey Nest" alone with no trailing command: open the mic like the hotkey does
            } else {
                self.finish(with: command)
            }
        }
    }

    private func activateFromHotkey() {
        hideTask?.cancel()
        guard appState.voiceCommandsEnabled else {
            // Voice commands aren't enabled yet — surface that instead of silently doing nothing.
            overlay = .failed("Turn on Voice Commands in Settings first.")
            scheduleHide(after: 2.5)
            return
        }
        Task { await captureOneShot() }
    }

    private func captureOneShot() async {
        overlay = .listening
        do {
            let transcript = try await speech.listenOnce()
            if transcript.isEmpty {
                overlay = .failed("Didn't catch that.")
                scheduleHide(after: 1.5)
            } else {
                finish(with: transcript)
            }
        } catch {
            overlay = .failed(error.localizedDescription)
            scheduleHide(after: 2.5)
        }
    }

    private func finish(with transcript: String) {
        overlay = .processing(transcript)
        appState.runVoiceCommand(transcript)
        if appState.speakResultsAloud {
            SpeechOutputService.speak("Searching for \(transcript)")
        }
        overlay = .done(transcript)
        scheduleHide(after: 2)
    }

    private func scheduleHide(after seconds: TimeInterval) {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            overlay = .hidden
        }
    }
}
