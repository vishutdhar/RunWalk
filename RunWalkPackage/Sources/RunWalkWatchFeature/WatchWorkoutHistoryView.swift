import SwiftUI
import SwiftData
import RunWalkShared

/// Workout history view optimized for watchOS
/// Displays past workouts in a compact list format
public struct WatchWorkoutHistoryView: View {
    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Query

    @Query(sort: \WorkoutRecord.startDate, order: .reverse)
    private var workouts: [WorkoutRecord]

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    emptyStateView
                } else {
                    workoutListView
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No Workouts")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Text("Complete a workout\nto see it here")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Workout List

    private var workoutListView: some View {
        List {
            ForEach(workouts) { workout in
                WatchWorkoutRowView(workout: workout)
            }
            .onDelete(perform: deleteWorkouts)
        }
        .listStyle(.carousel)
    }

    // MARK: - Actions

    private func deleteWorkouts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(workouts[index])
        }
    }

    // MARK: - Initialization

    public init() {}
}

// MARK: - Workout Row View

struct WatchWorkoutRowView: View {
    let workout: WorkoutRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Date and time
            Text(workout.shortDate)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            // Duration - prominent
            Text(workout.formattedDuration)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()

            // Interval counts
            HStack(spacing: 10) {
                // Run intervals
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    Text("\(workout.runIntervals)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange)
                }

                // Walk intervals
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("\(workout.walkIntervals)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.green)
                }

                // HealthKit indicator
                if workout.savedToHealthKit {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.pink)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    WatchWorkoutHistoryView()
        .modelContainer(for: WorkoutRecord.self, inMemory: true)
}
