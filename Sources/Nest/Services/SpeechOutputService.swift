import AVFoundation

/// On-device text-to-speech for short spoken confirmations. Output only —
/// needs no permission and nothing leaves the Mac.
enum SpeechOutputService {
    private static let synthesizer = AVSpeechSynthesizer()

    /// Empty/unrecognized identifier falls back to the system default voice.
    static func speak(_ text: String, voiceIdentifier: String = "") {
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        if !voiceIdentifier.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        }
        synthesizer.speak(utterance)
    }

    /// Installed voices for Indian languages, so Settings can offer a
    /// non-English option without any extra download or runtime — macOS
    /// already ships these, just at "compact" quality by default. Higher
    /// quality versions of the same voices can be downloaded for free via
    /// System Settings > Accessibility > Spoken Content.
    static let indicLanguageCodes = ["hi", "ta", "te", "mr", "bn", "gu", "kn", "ml", "pa", "or", "as"]

    static func availableIndicVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { voice in indicLanguageCodes.contains { voice.language.lowercased().hasPrefix($0) } }
            .sorted { $0.language < $1.language }
    }
}
