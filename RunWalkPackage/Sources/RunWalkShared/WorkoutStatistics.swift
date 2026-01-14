import Foundation
import SwiftData

// MARK: - Workout Statistics Models

/// Statistics summary for a time period
public struct PeriodStatistics: Sendable {
    public let workoutCount: Int
    public let totalDuration: TimeInterval
    public let totalDistance: Double
    public let totalCalories: Double
    public let totalIntervals: Int

    public init(
        workoutCount: Int = 0,
        totalDuration: TimeInterval = 0,
        totalDistance: Double = 0,
        totalCalories: Double = 0,
        totalIntervals: Int = 0
    ) {
        self.workoutCount = workoutCount
        self.totalDuration = totalDuration
        self.totalDistance = totalDistance
        self.totalCalories = totalCalories
        self.totalIntervals = totalIntervals
    }

    /// Formatted total duration string
    public var formattedDuration: String {
        let totalSeconds = Int(totalDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Formatted distance using locale preference
    public var formattedDistance: String {
        let usesMetric = Locale.current.measurementSystem == .metric

        if usesMetric {
            let km = totalDistance / 1000.0
            if km < 1 {
                return String(format: "%.0f m", totalDistance)
            } else {
                return String(format: "%.1f km", km)
            }
        } else {
            let miles = totalDistance / 1609.344
            return String(format: "%.1f mi", miles)
        }
    }

    /// Formatted calories
    public var formattedCalories: String {
        return "\(Int(totalCalories)) cal"
    }
}

/// Data point for daily workout chart
public struct DailyWorkoutData: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let workoutCount: Int
    public let totalDuration: TimeInterval

    public init(date: Date, workoutCount: Int, totalDuration: TimeInterval) {
        self.date = date
        self.workoutCount = workoutCount
        self.totalDuration = totalDuration
    }

    /// Day of week abbreviation (Mon, Tue, etc.)
    public var dayAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    /// Short date (e.g., "Jan 15")
    public var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

/// Workout streak information
public struct WorkoutStreak: Sendable {
    public let currentStreak: Int
    public let longestStreak: Int
    public let lastWorkoutDate: Date?

    public init(currentStreak: Int = 0, longestStreak: Int = 0, lastWorkoutDate: Date? = nil) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastWorkoutDate = lastWorkoutDate
    }

    /// Whether the user worked out today
    public var workedOutToday: Bool {
        guard let lastDate = lastWorkoutDate else { return false }
        return Calendar.current.isDateInToday(lastDate)
    }

    /// Whether the streak is still active (worked out today or yesterday)
    public var isStreakActive: Bool {
        guard let lastDate = lastWorkoutDate else { return false }
        let calendar = Calendar.current
        return calendar.isDateInToday(lastDate) || calendar.isDateInYesterday(lastDate)
    }
}

// MARK: - Statistics Calculator

/// Calculates workout statistics from an array of WorkoutRecords
public enum StatisticsCalculator {

    // MARK: - Period Statistics

    /// Calculate statistics for workouts within a date range
    public static func statistics(for workouts: [WorkoutRecord], in dateRange: ClosedRange<Date>? = nil) -> PeriodStatistics {
        let filtered: [WorkoutRecord]
        if let range = dateRange {
            filtered = workouts.filter { range.contains($0.startDate) }
        } else {
            filtered = workouts
        }

        return PeriodStatistics(
            workoutCount: filtered.count,
            totalDuration: filtered.reduce(0) { $0 + $1.duration },
            totalDistance: filtered.reduce(0) { $0 + $1.totalDistance },
            totalCalories: filtered.reduce(0) { $0 + $1.caloriesBurned },
            totalIntervals: filtered.reduce(0) { $0 + $1.totalIntervals }
        )
    }

    /// Statistics for this week (Monday to Sunday)
    public static func thisWeekStatistics(from workouts: [WorkoutRecord]) -> PeriodStatistics {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return PeriodStatistics()
        }
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
        return statistics(for: workouts, in: weekStart...weekEnd)
    }

    /// Statistics for this month
    public static func thisMonthStatistics(from workouts: [WorkoutRecord]) -> PeriodStatistics {
        let calendar = Calendar.current
        guard let monthStart = calendar.dateInterval(of: .month, for: Date())?.start else {
            return PeriodStatistics()
        }
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? Date()
        return statistics(for: workouts, in: monthStart...monthEnd)
    }

    /// All-time statistics
    public static func allTimeStatistics(from workouts: [WorkoutRecord]) -> PeriodStatistics {
        return statistics(for: workouts)
    }

    // MARK: - Daily Data for Charts

    /// Get daily workout data for the past N days
    public static func dailyData(from workouts: [WorkoutRecord], days: Int = 7) -> [DailyWorkoutData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var dailyData: [DailyWorkoutData] = []

        for dayOffset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let dayWorkouts = workouts.filter { workout in
                workout.startDate >= dayStart && workout.startDate < dayEnd
            }

            dailyData.append(DailyWorkoutData(
                date: date,
                workoutCount: dayWorkouts.count,
                totalDuration: dayWorkouts.reduce(0) { $0 + $1.duration }
            ))
        }

        return dailyData
    }

    /// Get weekly workout data for the past N weeks
    public static func weeklyData(from workouts: [WorkoutRecord], weeks: Int = 4) -> [DailyWorkoutData] {
        let calendar = Calendar.current
        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return []
        }

        var weeklyData: [DailyWorkoutData] = []

        for weekOffset in (0..<weeks).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: thisWeekStart),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { continue }

            let weekWorkouts = workouts.filter { workout in
                workout.startDate >= weekStart && workout.startDate < weekEnd
            }

            weeklyData.append(DailyWorkoutData(
                date: weekStart,
                workoutCount: weekWorkouts.count,
                totalDuration: weekWorkouts.reduce(0) { $0 + $1.duration }
            ))
        }

        return weeklyData
    }

    // MARK: - Streak Calculation

    /// Calculate workout streak
    public static func calculateStreak(from workouts: [WorkoutRecord]) -> WorkoutStreak {
        guard !workouts.isEmpty else {
            return WorkoutStreak()
        }

        let calendar = Calendar.current
        let sortedWorkouts = workouts.sorted { $0.startDate > $1.startDate }
        let lastWorkoutDate = sortedWorkouts.first?.startDate

        // Get unique workout dates (one entry per day)
        var uniqueDates: Set<Date> = []
        for workout in sortedWorkouts {
            let dayStart = calendar.startOfDay(for: workout.startDate)
            uniqueDates.insert(dayStart)
        }

        let sortedDates = uniqueDates.sorted(by: >)

        // Calculate current streak
        var currentStreak = 0
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Check if streak is still active (worked out today or yesterday)
        if let mostRecentDate = sortedDates.first {
            if mostRecentDate == today || mostRecentDate == yesterday {
                // Count consecutive days backwards
                var expectedDate = mostRecentDate
                for date in sortedDates {
                    if date == expectedDate {
                        currentStreak += 1
                        expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
                    } else if date < expectedDate {
                        break
                    }
                }
            }
        }

        // Calculate longest streak
        var longestStreak = 0
        var tempStreak = 0
        var previousDate: Date?

        for date in sortedDates.sorted() {
            if let prev = previousDate {
                let dayDiff = calendar.dateComponents([.day], from: prev, to: date).day ?? 0
                if dayDiff == 1 {
                    tempStreak += 1
                } else {
                    longestStreak = max(longestStreak, tempStreak)
                    tempStreak = 1
                }
            } else {
                tempStreak = 1
            }
            previousDate = date
        }
        longestStreak = max(longestStreak, tempStreak)

        return WorkoutStreak(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastWorkoutDate: lastWorkoutDate
        )
    }

    // MARK: - Average Calculations

    /// Average workout duration
    public static func averageDuration(from workouts: [WorkoutRecord]) -> TimeInterval {
        guard !workouts.isEmpty else { return 0 }
        return workouts.reduce(0) { $0 + $1.duration } / Double(workouts.count)
    }

    /// Average workouts per week
    public static func averageWorkoutsPerWeek(from workouts: [WorkoutRecord]) -> Double {
        guard let oldest = workouts.min(by: { $0.startDate < $1.startDate }),
              let newest = workouts.max(by: { $0.startDate < $1.startDate }) else {
            return 0
        }

        let calendar = Calendar.current
        let weeks = calendar.dateComponents([.weekOfYear], from: oldest.startDate, to: newest.startDate).weekOfYear ?? 1
        let totalWeeks = max(1, weeks)

        return Double(workouts.count) / Double(totalWeeks)
    }
}
