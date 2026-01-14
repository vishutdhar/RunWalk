import SwiftUI
import SwiftData
import Charts
import RunWalkShared

/// Statistics view showing workout trends and summaries
public struct StatisticsView: View {
    // MARK: - Environment

    @Query(sort: \WorkoutRecord.startDate, order: .reverse)
    private var workouts: [WorkoutRecord]

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Streak Card
                streakCard

                // This Week Summary
                thisWeekCard

                // Weekly Chart
                weeklyChartCard

                // All-Time Stats
                allTimeCard
            }
            .padding()
        }
        .background(Color.black)
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        let streak = StatisticsCalculator.calculateStreak(from: workouts)

        return VStack(spacing: 16) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Workout Streak")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(streak.currentStreak)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(streak.isStreakActive ? .orange : .secondary)
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(streak.longestStreak)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    Text("Longest")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if streak.workedOutToday {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.green)
                        Text("Today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - This Week Card

    private var thisWeekCard: some View {
        let stats = StatisticsCalculator.thisWeekStatistics(from: workouts)

        return VStack(spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.blue)
                Text("This Week")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 0) {
                StatBox(
                    value: "\(stats.workoutCount)",
                    label: "Workouts",
                    color: .green
                )

                StatBox(
                    value: stats.formattedDuration,
                    label: "Duration",
                    color: .orange
                )

                StatBox(
                    value: stats.formattedDistance,
                    label: "Distance",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Weekly Chart Card

    private var weeklyChartCard: some View {
        let dailyData = StatisticsCalculator.dailyData(from: workouts, days: 7)

        return VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.green)
                Text("Last 7 Days")
                    .font(.headline)
                Spacer()
            }

            Chart(dailyData) { day in
                BarMark(
                    x: .value("Day", day.dayAbbreviation),
                    y: .value("Workouts", day.workoutCount)
                )
                .foregroundStyle(
                    day.workoutCount > 0 ?
                    LinearGradient(
                        colors: [.green, .green.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    ) :
                    LinearGradient(
                        colors: [.gray.opacity(0.3), .gray.opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(6)
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(.gray.opacity(0.3))
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - All-Time Card

    private var allTimeCard: some View {
        let stats = StatisticsCalculator.allTimeStatistics(from: workouts)
        let avgDuration = StatisticsCalculator.averageDuration(from: workouts)
        let avgPerWeek = StatisticsCalculator.averageWorkoutsPerWeek(from: workouts)

        return VStack(spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                Text("All Time")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                AllTimeStatCell(
                    icon: "figure.run",
                    value: "\(stats.workoutCount)",
                    label: "Total Workouts",
                    color: .green
                )

                AllTimeStatCell(
                    icon: "clock.fill",
                    value: stats.formattedDuration,
                    label: "Total Time",
                    color: .orange
                )

                AllTimeStatCell(
                    icon: "map.fill",
                    value: stats.formattedDistance,
                    label: "Total Distance",
                    color: .blue
                )

                AllTimeStatCell(
                    icon: "flame.fill",
                    value: stats.formattedCalories,
                    label: "Calories Burned",
                    color: .red
                )

                AllTimeStatCell(
                    icon: "timer",
                    value: formatDuration(avgDuration),
                    label: "Avg Duration",
                    color: .purple
                )

                AllTimeStatCell(
                    icon: "calendar.badge.clock",
                    value: String(format: "%.1f", avgPerWeek),
                    label: "Avg/Week",
                    color: .cyan
                )
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Initialization

    public init() {}
}

// MARK: - Supporting Views

private struct StatBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AllTimeStatCell: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    StatisticsView()
        .preferredColorScheme(.dark)
}
