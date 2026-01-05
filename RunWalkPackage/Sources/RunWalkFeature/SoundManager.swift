import AVFoundation
import UIKit

/// Manages audio playback for run/walk phase transitions
/// Uses speech synthesis for clear voice announcements
@MainActor
final class SoundManager {
    // MARK: - Properties

    /// Retain the synthesizer so it doesn't get deallocated mid-speech
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Initialization

    init() {
        configureAudioSession()
    }

    // MARK: - Audio Session Configuration

    /// Configures the audio session to play sounds even when phone is on silent
    /// and to continue playing in the background
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Use playback category to ensure sound plays even on silent mode
            // and continues in background
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Sound Playback

    /// Plays the appropriate sound for the given phase
    /// - Parameter phase: The timer phase (run or walk)
    func playSound(for phase: TimerPhase) {
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance: AVSpeechUtterance

        switch phase {
        case .run:
            // Energetic "Run!" announcement
            utterance = AVSpeechUtterance(string: "Run!")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.1
            utterance.pitchMultiplier = 1.15
            utterance.volume = 1.0
        case .walk:
            // Calmer "Walk" announcement
            utterance = AVSpeechUtterance(string: "Walk")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
            utterance.pitchMultiplier = 0.95
            utterance.volume = 1.0
        }

        // Use a clear voice
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

        // Small delay to ensure audio session is ready
        utterance.preUtteranceDelay = 0.1

        synthesizer.speak(utterance)

        // Also trigger haptic feedback for additional notification
        triggerHaptic(for: phase)
    }

    // MARK: - Haptic Feedback

    /// Triggers haptic feedback for phase transitions
    /// - Parameter phase: The timer phase
    private func triggerHaptic(for phase: TimerPhase) {
        switch phase {
        case .run:
            // Strong double haptic for "run"
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                generator.impactOccurred()
            }
        case .walk:
            // Softer single haptic for "walk"
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }
}
