import AVFoundation
import RunWalkShared

/// Manages voice announcements for phase transitions
/// Uses the best available system voice for the user's language
/// Keeps announcements minimal - just "Run" or "Walk"
@MainActor
public final class VoiceAnnouncementManager: NSObject {

    // MARK: - Properties

    /// Speech synthesizer for voice output
    private let synthesizer = AVSpeechSynthesizer()

    /// Cached best voice for announcements
    private var selectedVoice: AVSpeechSynthesisVoice?

    /// Whether voice announcements are enabled
    public var isEnabled: Bool = false

    // MARK: - Initialization

    public override init() {
        super.init()
        synthesizer.delegate = self
        selectBestVoice()
    }

    // MARK: - Voice Selection

    /// Selects the best available voice for the user's language
    /// Prioritizes: premium (neural) > enhanced > default quality
    private func selectBestVoice() {
        // Get user's preferred language (e.g., "en-US", "es-MX")
        let preferredLanguage = Locale.current.language.languageCode?.identifier ?? "en"

        // Get all available voices
        let allVoices = AVSpeechSynthesisVoice.speechVoices()

        // Filter voices that match user's language
        let matchingVoices = allVoices.filter { voice in
            voice.language.hasPrefix(preferredLanguage)
        }

        // Sort by quality: premium (neural) first, then enhanced, then default
        // AVSpeechSynthesisVoiceQuality: .default = 1, .enhanced = 2, .premium = 3
        let sortedVoices = matchingVoices.sorted { $0.quality.rawValue > $1.quality.rawValue }

        // Use best matching voice, or fall back to any English voice
        if let bestVoice = sortedVoices.first {
            selectedVoice = bestVoice
        } else {
            // Fallback: find any English voice with best quality
            let englishVoices = allVoices
                .filter { $0.language.hasPrefix("en") }
                .sorted { $0.quality.rawValue > $1.quality.rawValue }
            selectedVoice = englishVoices.first ?? AVSpeechSynthesisVoice(language: "en-US")
        }
    }

    // MARK: - Announcements

    /// Announces the phase transition
    /// - Parameter phase: The new phase (run or walk)
    public func announce(phase: TimerPhase) {
        guard isEnabled else { return }

        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Create utterance with simple word
        let text: String
        switch phase {
        case .run:
            text = "Run"
        case .walk:
            text = "Walk"
        }

        let utterance = AVSpeechUtterance(string: text)

        // Configure for quick, clear delivery
        utterance.voice = selectedVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.1  // Slightly faster
        utterance.pitchMultiplier = 1.0  // Natural pitch
        utterance.volume = 1.0  // Full volume
        utterance.preUtteranceDelay = 0  // No delay before speaking
        utterance.postUtteranceDelay = 0  // No delay after speaking

        synthesizer.speak(utterance)
    }

    /// Stops any current announcement
    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceAnnouncementManager: AVSpeechSynthesizerDelegate {
    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        // Speech completed - can add logging or analytics here if needed
    }

    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        // Speech was cancelled - can add logging here if needed
    }
}
