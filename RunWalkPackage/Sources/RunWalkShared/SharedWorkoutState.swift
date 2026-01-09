import Foundation

/// Shared workout state for inter-process communication between Watch App and Widget Extension
/// Uses App Group UserDefaults for storage
public struct SharedWorkoutState: Codable, Sendable {
    // MARK: - Current Workout State

    /// Whether a workout is currently active
    public var isActive: Bool

    /// Current phase: "RUN" or "WALK"
    public var currentPhase: String

    /// Time remaining in current interval (seconds)
    public var timeRemaining: Int

    /// Total interval duration (seconds) - used for progress calculation
    public var intervalDuration: Int

    /// When this state was last updated
    public var lastUpdate: Date

    // MARK: - User Settings (for idle state display)

    /// User's run interval preference (seconds)
    public var runIntervalSetting: Int

    /// User's walk interval preference (seconds)
    public var walkIntervalSetting: Int

    // MARK: - Initialization

    public init(
        isActive: Bool,
        currentPhase: String,
        timeRemaining: Int,
        intervalDuration: Int,
        lastUpdate: Date,
        runIntervalSetting: Int,
        walkIntervalSetting: Int
    ) {
        self.isActive = isActive
        self.currentPhase = currentPhase
        self.timeRemaining = timeRemaining
        self.intervalDuration = intervalDuration
        self.lastUpdate = lastUpdate
        self.runIntervalSetting = runIntervalSetting
        self.walkIntervalSetting = walkIntervalSetting
    }

    // MARK: - Idle State

    /// Default idle state when no workout is active
    public static let idle = SharedWorkoutState(
        isActive: false,
        currentPhase: "RUN",
        timeRemaining: 0,
        intervalDuration: 0,
        lastUpdate: Date(),
        runIntervalSetting: 30,
        walkIntervalSetting: 60
    )

    // MARK: - Computed Properties

    /// Progress through current interval (0.0 to 1.0)
    public var progress: Double {
        guard intervalDuration > 0 else { return 0 }
        return Double(intervalDuration - timeRemaining) / Double(intervalDuration)
    }

    /// Formatted time remaining (MM:SS)
    public var formattedTimeRemaining: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Whether this is a RUN phase
    public var isRunPhase: Bool {
        currentPhase == "RUN"
    }
}
