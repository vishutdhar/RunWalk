import Foundation

/// Workout statistics for summary screen
public struct WorkoutStats: Sendable {
    public var totalDuration: TimeInterval
    public var runIntervals: Int
    public var walkIntervals: Int
    public var startTime: Date?
    public var endTime: Date?

    public init(
        totalDuration: TimeInterval = 0,
        runIntervals: Int = 0,
        walkIntervals: Int = 0,
        startTime: Date? = nil,
        endTime: Date? = nil
    ) {
        self.totalDuration = totalDuration
        self.runIntervals = runIntervals
        self.walkIntervals = walkIntervals
        self.startTime = startTime
        self.endTime = endTime
    }

    public var formattedDuration: String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    public var totalIntervals: Int {
        runIntervals + walkIntervals
    }
}
