import AVFoundation

/// On-device text-to-speech for short spoken confirmations. Output only —
/// needs no permission and nothing leaves the Mac.
enum SpeechOutputService {
    private static let synthesizer = AVSpeechSynthesizer()

    static func speak(_ text: String) {
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }
}
