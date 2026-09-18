import Foundation
import Speech
import AVFoundation

enum VoiceCommandError: Error, LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case audioEngineFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Microphone or speech recognition access wasn't granted."
        case .recognizerUnavailable: return "Speech recognition isn't available right now."
        case .audioEngineFailed(let reason): return "Couldn't start listening: \(reason)"
        }
    }
}

/// Wraps on-device speech recognition (Speech framework) for two modes:
/// - a one-shot capture ("Talk to Nest" via the ⌘⌥ hotkey)
/// - continuous listening for a "Hey Nest" wake phrase
///
/// Uses `requiresOnDeviceRecognition = true` wherever available, matching the
/// app's local-first principle — recognized speech never leaves the Mac.
@MainActor
final class VoiceCommandService: NSObject, ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var liveTranscript = ""

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var wakeWordHandler: ((String) -> Void)?

    static func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in continuation.resume(returning: status) }
        }
        guard speechStatus == .authorized else { return false }

        let micGranted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .audio) { granted in continuation.resume(returning: granted) }
        }
        return micGranted
    }

    // MARK: - One-shot capture (hotkey)

    /// Listens until `silenceTimeout` of no new words, or `maxDuration` total,
    /// whichever comes first. Returns the final transcript (possibly empty).
    func listenOnce(silenceTimeout: TimeInterval = 1.6, maxDuration: TimeInterval = 12) async throws -> String {
        try startEngine { [weak self] partial in
            self?.liveTranscript = partial
        }
        defer { stopEngine() }

        var lastChangeTime = Date()
        var lastText = ""
        let deadline = Date().addingTimeInterval(maxDuration)
        while Date() < deadline {
            try await Task.sleep(nanoseconds: 150_000_000)
            let current = liveTranscript
            if current != lastText {
                lastText = current
                lastChangeTime = Date()
            } else if !current.isEmpty, Date().timeIntervalSince(lastChangeTime) > silenceTimeout {
                break
            }
        }
        return lastText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Continuous wake-word listening

    /// Starts (or restarts) continuous recognition, calling `onWake` with
    /// whatever follows "hey nest" whenever the phrase is heard. Recognition
    /// tasks have a bounded lifetime, so this restarts itself periodically —
    /// expected to run only while the user has explicitly opted in.
    func startWakeWordListening(onWake: @escaping (String) -> Void) {
        wakeWordHandler = onWake
        restartWakeWordLoop()
    }

    private func restartWakeWordLoop() {
        guard wakeWordHandler != nil else { return }
        stopEngine()
        try? startEngine { [weak self] partial in
            guard let self, let handler = self.wakeWordHandler else { return }
            self.liveTranscript = partial
            let lower = partial.lowercased()
            guard let range = lower.range(of: "hey nest") else { return }
            let command = String(partial[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            if !command.isEmpty {
                handler(command)
                self.liveTranscript = ""
                self.restartWakeWordLoop() // fresh buffer for the next phrase
            }
        }
        // Recognition tasks are capped (~1 minute); restart before that to
        // keep wake-word listening continuous.
        DispatchQueue.main.asyncAfter(deadline: .now() + 50) { [weak self] in
            guard let self, self.wakeWordHandler != nil else { return }
            self.restartWakeWordLoop()
        }
    }

    func stopWakeWordListening() {
        wakeWordHandler = nil
        stopEngine()
    }

    // MARK: - Shared engine plumbing

    private func startEngine(onPartialResult: @escaping (String) -> Void) throws {
        guard let recognizer, recognizer.isAvailable else { throw VoiceCommandError.recognizerUnavailable }

        stopEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw VoiceCommandError.audioEngineFailed(error.localizedDescription)
        }

        isListening = true
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                onPartialResult(result.bestTranscription.formattedString)
            }
            if error != nil || (result?.isFinal ?? false) {
                self?.stopEngine()
            }
        }
    }

    private func stopEngine() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        isListening = false
    }
}
