import AudioToolbox
import AVFoundation
import UIKit

/// Manages audio and haptic feedback for run/walk phase transitions
/// Uses system sounds to match watchOS behavior
@MainActor
final class SoundManager {

    // MARK: - System Sound IDs

    /// System sound for notification ding (matches watch .notification)
    private let notificationSoundID: SystemSoundID = 1057

    /// System sound for click/tick (matches watch .click)
    private let clickSoundID: SystemSoundID = 1104

    // MARK: - Settings

    /// Whether bell sounds are enabled
    var bellsEnabled: Bool = true

    /// Whether haptic feedback is enabled
    var hapticsEnabled: Bool = true

    // MARK: - Initialization

    init() {
        configureAudioSession()
    }

    // MARK: - Audio Session Configuration

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Sound Playback

    /// Plays the appropriate sound for the given phase
    /// - Parameter phase: The timer phase (run or walk)
    func playSound(for phase: TimerPhase) {
        // Play bells if enabled
        if bellsEnabled {
            switch phase {
            case .run:
                playRunSound()
            case .walk:
                playWalkSound()
            }
        }

        // Trigger haptic feedback if enabled
        if hapticsEnabled {
            triggerHaptic(for: phase)
        }
    }

    /// RUN phase: Triple ding (ding-ding-ding) - matches watch
    private func playRunSound() {
        // Triple ding for RUN with 400ms spacing (matches watch)
        AudioServicesPlaySystemSound(notificationSoundID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            AudioServicesPlaySystemSound(self.notificationSoundID)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            AudioServicesPlaySystemSound(self.notificationSoundID)
        }
    }

    /// WALK phase: Single ding - matches watch
    private func playWalkSound() {
        // Single ding for WALK
        AudioServicesPlaySystemSound(notificationSoundID)
    }

    /// Plays countdown haptic feedback only for pre-workout 3-2-1 countdown
    func playCountdownBeep(index: Int) {
        guard index >= 0, index < 3 else { return }

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 0.7)
    }

    /// Plays countdown tick at 3, 2, 1 seconds before phase transition
    func playCountdownTick(secondsRemaining: Int) {
        guard secondsRemaining > 0, secondsRemaining <= 3 else { return }

        // Single click sound (matches watch .click) if bells enabled
        if bellsEnabled {
            AudioServicesPlaySystemSound(clickSoundID)
        }

        // Single haptic tick if haptics enabled
        if hapticsEnabled {
            triggerCountdownHaptic(secondsRemaining: secondsRemaining)
        }
    }

    // MARK: - Haptic Feedback

    /// Triggers haptic feedback for phase transitions
    /// RUN = 3 haptics, WALK = 1 haptic (matches watch)
    private func triggerHaptic(for phase: TimerPhase) {
        switch phase {
        case .run:
            // Triple haptic for RUN with 400ms spacing (matches watch)
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.prepare()
            generator.impactOccurred(intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.impactOccurred(intensity: 1.0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                generator.impactOccurred(intensity: 1.0)
            }
        case .walk:
            // Single haptic for WALK
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred(intensity: 1.0)
        }
    }

    /// Single tick haptic for countdown
    func triggerCountdownHaptic(secondsRemaining: Int) {
        guard secondsRemaining > 0, secondsRemaining <= 3 else { return }

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 0.7)
    }
}
