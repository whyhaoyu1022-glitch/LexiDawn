import AVFoundation
import Combine
import Foundation

@MainActor final class SystemPronunciation: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    enum State: Equatable { case stopped, speaking, unavailable }
    @Published private(set) var state: State = .stopped
    private let synthesizer = AVSpeechSynthesizer()
    private var current: AVSpeechUtterance?
    override init() { super.init(); synthesizer.delegate = self }
    func toggle(headword: String, language: String = "en-US") {
        if state == .speaking { stop(); return }
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en-") }
        guard !headword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let voice = voices.first(where: { $0.language == language }) ?? voices.first else { state = .unavailable; return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: headword)
        utterance.voice = voice; current = utterance; state = .speaking
        synthesizer.speak(utterance)
    }
    func stop() {
        current = nil; synthesizer.stopSpeaking(at: .immediate)
        if state == .speaking { state = .stopped }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finished(utterance) }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finished(utterance) }
    }
    private func finished(_ utterance: AVSpeechUtterance) {
        guard current === utterance else { return }
        current = nil; state = .stopped
    }
}
