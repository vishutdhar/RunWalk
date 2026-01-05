import SwiftUI
import Observation

/// Represents the current phase of the interval timer
public enum TimerPhase: String {
    case run = "RUN"
    case walk = "WALK"

    /// Returns the opposite phase
    var next: TimerPhase {
        switch self {
        case .run: return .walk
        case .walk: return .run
        }
    }

    /// Color associated with each phase
    var color: Color {
        switch self {
        case .run: return .orange
        case .walk: return .green
        }
    }
}

/// Available interval durations based on market research
/// Common intervals from Jeff Galloway's Run-Walk-Run method and Couch to 5K
public enum IntervalDuration: Int, CaseIterable, Identifiable {
    case thirtySeconds = 30
    case oneMinute = 60
    case ninetySeconds = 90
    case twoMinutes = 120
    case threeMinutes = 180
    case fiveMinutes = 300

    public var id: Int { rawValue }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .thirtySeconds: return "30 sec"
        case .oneMinute: return "1 min"
        case .ninetySeconds: return "1.5 min"
        case .twoMinutes: return "2 min"
        case .threeMinutes: return "3 min"
        case .fiveMinutes: return "5 min"
        }
    }
}

/// Main timer model that handles the interval timing logic
@Observable
@MainActor
public final class IntervalTimer {
    // MARK: - Published State

    /// Current phase (run or walk)
    public private(set) var currentPhase: TimerPhase = .run

    /// Time remaining in current interval (in seconds)
    public private(set) var timeRemaining: Int = 30

    /// Whether the timer is currently running (ticking)
    public private(set) var isRunning: Bool = false

    /// Whether a session is active (started but not cancelled)
    /// This stays true even when paused
    public private(set) var isActive: Bool = false

    /// Selected interval duration for RUN phase
    public var runInterval: IntervalDuration = .thirtySeconds {
        didSet {
            // Reset timer when interval changes (only if not active and on run phase)
            if !isActive && currentPhase == .run {
                timeRemaining = runInterval.rawValue
            }
        }
    }

    /// Selected interval duration for WALK phase
    public var walkInterval: IntervalDuration = .oneMinute {
        didSet {
            // Reset timer when interval changes (only if not active and on walk phase)
            if !isActive && currentPhase == .walk {
                timeRemaining = walkInterval.rawValue
            }
        }
    }

    /// Returns the interval duration for the current phase
    public var currentInterval: IntervalDuration {
        currentPhase == .run ? runInterval : walkInterval
    }

    // MARK: - Private Properties

    private var timer: Timer?
    private let soundManager = SoundManager()

    // MARK: - Initialization

    public init() {
        timeRemaining = runInterval.rawValue
    }

    // MARK: - Timer Controls

    /// Starts or resumes the timer
    public func start() {
        guard !isRunning else { return }

        let isFirstStart = !isActive
        isRunning = true
        isActive = true

        // Play sound only on first start, not on resume from pause
        if isFirstStart {
            soundManager.playSound(for: currentPhase)
        }

        // Create timer that fires every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        // Ensure timer runs even when scrolling
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    /// Pauses the timer
    public func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    /// Stops and resets the timer (cancels the session)
    public func stop() {
        pause()
        isActive = false
        currentPhase = .run
        timeRemaining = runInterval.rawValue
    }

    // MARK: - Private Methods

    /// Called every second to update the timer
    private func tick() {
        guard isRunning else { return }

        if timeRemaining > 0 {
            timeRemaining -= 1
        }

        // When timer reaches zero, switch phases
        if timeRemaining == 0 {
            switchPhase()
        }
    }

    /// Switches between run and walk phases
    private func switchPhase() {
        currentPhase = currentPhase.next
        // Use the appropriate interval for the new phase
        timeRemaining = currentInterval.rawValue

        // Play sound for new phase
        soundManager.playSound(for: currentPhase)
    }

    // MARK: - Computed Properties

    /// Formatted time string (MM:SS)
    public var formattedTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
