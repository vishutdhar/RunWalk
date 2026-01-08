import WatchKit
import RunWalkShared

/// Manages haptic feedback for the watchOS app
/// Provides distinct patterns for RUN and WALK phases that users can feel through clothing
@MainActor
public final class WatchHapticManager {

    // MARK: - Settings

    /// Whether bell sounds are enabled
    public var bellsEnabled: Bool = true

    /// Whether haptic feedback is enabled
    public var hapticsEnabled: Bool = true

    /// Whether any feedback should play (bells OR haptics enabled)
    private var shouldPlayFeedback: Bool {
        bellsEnabled || hapticsEnabled
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Phase Transition Haptics

    /// Plays the haptic pattern for transitioning to a new phase
    /// - RUN: Triple start haptic (urgent, energizing - "time to move!")
    /// - WALK: Single stop haptic (calming - "take it easy")
    public func playPhaseTransition(to phase: TimerPhase) {
        guard shouldPlayFeedback else { return }

        switch phase {
        case .run:
            playRunHaptic()
        case .walk:
            playWalkHaptic()
        }
    }

    /// RUN phase: Triple beep to match iPhone's 3 bells
    private func playRunHaptic() {
        let device = WKInterfaceDevice.current()

        // Triple beep for RUN (ding-ding-ding)
        device.play(.notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            device.play(.notification)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            device.play(.notification)
        }
    }

    /// WALK phase: Single beep to match iPhone's 1 bell
    private func playWalkHaptic() {
        // Single beep for WALK (ding)
        WKInterfaceDevice.current().play(.notification)
    }

    // MARK: - Countdown Haptics

    /// Plays countdown haptic for 3-2-1 pre-workout countdown
    /// Uses .click for a subtle but noticeable tick
    public func playCountdownTick() {
        guard shouldPlayFeedback else { return }
        WKInterfaceDevice.current().play(.click)
    }

    /// Plays a success haptic when workout completes
    public func playWorkoutComplete() {
        guard shouldPlayFeedback else { return }
        WKInterfaceDevice.current().play(.success)
    }

    /// Plays a notification haptic for important alerts
    public func playNotification() {
        guard shouldPlayFeedback else { return }
        WKInterfaceDevice.current().play(.notification)
    }

    // MARK: - Interval Warning Haptics

    /// Plays single tick warning at 3, 2, 1 seconds before phase ends
    /// Simple consistent tick so it doesn't conflict with phase transition pattern
    /// - Parameter secondsRemaining: Seconds until phase transition
    public func playIntervalWarning(secondsRemaining: Int) {
        guard shouldPlayFeedback else { return }
        guard secondsRemaining > 0, secondsRemaining <= 3 else { return }

        // Single consistent tick for countdown - doesn't conflict with phase transition pattern
        // Phase transitions use: 3 haptics = RUN, 1 haptic = WALK
        WKInterfaceDevice.current().play(.click)
    }
}
