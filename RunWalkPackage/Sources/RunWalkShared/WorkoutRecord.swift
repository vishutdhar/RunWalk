import SwiftData
import Foundation

/// Persisted workout record for history tracking
/// Uses SwiftData for local storage
@Model
public final class WorkoutRecord {
    // MARK: - Properties

    /// Unique identifier
    public var id: UUID

    /// When the workout started
    public var startDate: Date

    /// When the workout ended
    public var endDate: Date

    /// Total workout duration in seconds
    public var duration: TimeInterval

    /// Number of run intervals completed
    public var runIntervals: Int

    /// Number of walk intervals completed
    public var walkIntervals: Int

    /// Run interval duration setting (in seconds)
    public var runIntervalDuration: Int

    /// Walk interval duration setting (in seconds)
    public var walkIntervalDuration: Int

    /// Estimated calories burned
    public var caloriesBurned: Double

    /// Whether this workout was saved to HealthKit
    public var savedToHealthKit: Bool

    // MARK: - Computed Properties

    /// Total number of intervals completed
    public var totalIntervals: Int {
        runIntervals + walkIntervals
    }

    /// Formatted duration string (MM:SS or H:MM:SS)
    public var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Formatted date string for display
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }

    /// Short date string (just the date, no time)
    public var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: startDate)
    }

    // MARK: - Initialization

    public init(
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        runIntervals: Int,
        walkIntervals: Int,
        runIntervalDuration: Int,
        walkIntervalDuration: Int,
        caloriesBurned: Double = 0,
        savedToHealthKit: Bool = false
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.runIntervals = runIntervals
        self.walkIntervals = walkIntervals
        self.runIntervalDuration = runIntervalDuration
        self.walkIntervalDuration = walkIntervalDuration
        self.caloriesBurned = caloriesBurned
        self.savedToHealthKit = savedToHealthKit
    }

    /// Creates a WorkoutRecord from WorkoutStats
    public convenience init(from stats: WorkoutStats, runInterval: Int, walkInterval: Int, savedToHealthKit: Bool = false) {
        self.init(
            startDate: stats.startTime ?? Date(),
            endDate: stats.endTime ?? Date(),
            duration: stats.totalDuration,
            runIntervals: stats.runIntervals,
            walkIntervals: stats.walkIntervals,
            runIntervalDuration: runInterval,
            walkIntervalDuration: walkInterval,
            caloriesBurned: Self.estimateCalories(duration: stats.totalDuration, runIntervals: stats.runIntervals, walkIntervals: stats.walkIntervals),
            savedToHealthKit: savedToHealthKit
        )
    }

    // MARK: - Calorie Estimation

    /// Estimates calories burned based on workout data
    private static func estimateCalories(duration: TimeInterval, runIntervals: Int, walkIntervals: Int) -> Double {
        let totalIntervals = runIntervals + walkIntervals
        guard totalIntervals > 0 else {
            return (duration / 60.0) * 7.0  // Fallback: 7 cal/min
        }

        let runFraction = Double(runIntervals) / Double(totalIntervals)
        let walkFraction = Double(walkIntervals) / Double(totalIntervals)

        let runDuration = duration * runFraction
        let walkDuration = duration * walkFraction

        // 10 cal/min for running, 4 cal/min for walking
        let runCalories = (runDuration / 60.0) * 10.0
        let walkCalories = (walkDuration / 60.0) * 4.0

        return runCalories + walkCalories
    }
}
