import SwiftUI
import RunWalkShared

/// Detail view for a workout record on watchOS
/// Shows route map (if available) and key statistics
public struct WatchWorkoutDetailView: View {
    // MARK: - Properties

    let workout: WorkoutRecord

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Route Map (if available)
                if let routeData = workout.routeData, workout.hasRoute {
                    WatchRouteMapView(routeData: routeData, isLive: false)
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Duration
                StatRow(
                    icon: "clock.fill",
                    label: "Duration",
                    value: workout.formattedDuration,
                    color: .white
                )

                // Distance (if available)
                if workout.hasDistance {
                    StatRow(
                        icon: "point.topleft.down.to.point.bottomright.curvepath",
                        label: "Distance",
                        value: workout.formattedDistance,
                        color: .blue
                    )
                }

                // Intervals
                HStack(spacing: 16) {
                    // Run
                    VStack(spacing: 4) {
                        Text("\(workout.runIntervals)")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(.orange)
                        Text("Run")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    // Walk
                    VStack(spacing: 4) {
                        Text("\(workout.walkIntervals)")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(.green)
                        Text("Walk")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)

                // Calories
                if workout.caloriesBurned > 0 {
                    StatRow(
                        icon: "flame.fill",
                        label: "Calories",
                        value: "\(Int(workout.caloriesBurned)) kcal",
                        color: .orange
                    )
                }

                // Pace (if available)
                if let pace = workout.formattedPace {
                    StatRow(
                        icon: "speedometer",
                        label: "Pace",
                        value: pace,
                        color: .green
                    )
                }

                // Date
                Text(workout.formattedDate)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Stat Row

private struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WatchWorkoutDetailView(workout: WorkoutRecord(
            startDate: Date().addingTimeInterval(-1800),
            endDate: Date(),
            duration: 1200,
            runIntervals: 4,
            walkIntervals: 3,
            runIntervalDuration: 180,
            walkIntervalDuration: 60,
            caloriesBurned: 150,
            savedToHealthKit: true,
            totalDistance: 1500,
            gpsTrackingEnabled: true
        ))
    }
}
