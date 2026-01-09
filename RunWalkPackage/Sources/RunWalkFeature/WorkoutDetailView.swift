import SwiftUI
import MapKit
import RunWalkShared

/// Detail view for a workout record showing full route map and statistics
public struct WorkoutDetailView: View {
    // MARK: - Properties

    let workout: WorkoutRecord

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Route Map (if available)
                if let routeData = workout.routeData, workout.hasRoute {
                    mapSection(routeData: routeData)
                }

                // Statistics
                statisticsSection

                // Interval Settings
                intervalSettingsSection

                // Metadata
                metadataSection
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Map Section

    @ViewBuilder
    private func mapSection(routeData: RouteData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            RouteMapView(
                routeData: routeData,
                isLive: false,
                showDistance: true
            )
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Duration
                StatCard(
                    title: "Duration",
                    value: workout.formattedDuration,
                    icon: "clock.fill",
                    color: .white
                )

                // Distance (if available)
                if workout.hasDistance {
                    StatCard(
                        title: "Distance",
                        value: workout.formattedDistance,
                        icon: "point.topleft.down.to.point.bottomright.curvepath",
                        color: .blue
                    )
                }

                // Calories
                StatCard(
                    title: "Calories",
                    value: "\(Int(workout.caloriesBurned)) kcal",
                    icon: "flame.fill",
                    color: .orange
                )

                // Pace (if available)
                if let pace = workout.formattedPace {
                    StatCard(
                        title: "Avg Pace",
                        value: pace,
                        icon: "speedometer",
                        color: .green
                    )
                }

                // Run Intervals
                StatCard(
                    title: "Run Intervals",
                    value: "\(workout.runIntervals)",
                    icon: "figure.run",
                    color: .orange
                )

                // Walk Intervals
                StatCard(
                    title: "Walk Intervals",
                    value: "\(workout.walkIntervals)",
                    icon: "figure.walk",
                    color: .green
                )
            }
        }
    }

    // MARK: - Interval Settings Section

    private var intervalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Interval Settings")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                // Run interval duration
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 10, height: 10)
                    Text("Run: \(formatSeconds(workout.runIntervalDuration))")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                }

                // Walk interval duration
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                    Text("Walk: \(formatSeconds(workout.walkIntervalDuration))")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                MetadataRow(label: "Date", value: workout.formattedDate)
                MetadataRow(label: "GPS Tracking", value: workout.gpsTrackingEnabled ? "Enabled" : "Disabled")
                MetadataRow(label: "HealthKit", value: workout.savedToHealthKit ? "Saved" : "Not Saved")
            }
            .padding()
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helpers

    private func formatSeconds(_ seconds: Int) -> String {
        if seconds >= 60 {
            let mins = seconds / 60
            let secs = seconds % 60
            if secs == 0 {
                return "\(mins) min"
            } else {
                return "\(mins):\(String(format: "%02d", secs))"
            }
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Metadata Row

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: WorkoutRecord(
            startDate: Date().addingTimeInterval(-3600),
            endDate: Date(),
            duration: 1800,
            runIntervals: 6,
            walkIntervals: 5,
            runIntervalDuration: 180,
            walkIntervalDuration: 60,
            caloriesBurned: 250,
            savedToHealthKit: true,
            routeData: RouteData(coordinates: [
                RouteCoordinate(latitude: 37.7749, longitude: -122.4194),
                RouteCoordinate(latitude: 37.7751, longitude: -122.4180),
                RouteCoordinate(latitude: 37.7755, longitude: -122.4165)
            ]),
            totalDistance: 2500,
            gpsTrackingEnabled: true
        ))
    }
}
