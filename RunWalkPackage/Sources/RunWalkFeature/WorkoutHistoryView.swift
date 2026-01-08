import SwiftUI
import SwiftData
import RunWalkShared

/// Displays workout history with persisted records
public struct WorkoutHistoryView: View {
    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - Query

    @Query(sort: \WorkoutRecord.startDate, order: .reverse)
    private var workouts: [WorkoutRecord]

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if workouts.isEmpty {
                    emptyStateView
                } else {
                    workoutListView
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Workouts Yet")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("Complete a workout to see it here")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Workout List

    private var workoutListView: some View {
        List {
            ForEach(groupedWorkouts, id: \.0) { date, dayWorkouts in
                Section {
                    ForEach(dayWorkouts) { workout in
                        WorkoutRowView(workout: workout)
                            .listRowBackground(Color.white.opacity(0.08))
                    }
                    .onDelete { indexSet in
                        deleteWorkouts(dayWorkouts: dayWorkouts, at: indexSet)
                    }
                } header: {
                    Text(date)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Grouped Workouts

    /// Groups workouts by date for section headers
    private var groupedWorkouts: [(String, [WorkoutRecord])] {
        let grouped = Dictionary(grouping: workouts) { workout in
            workout.shortDate
        }
        return grouped.sorted { $0.value.first?.startDate ?? Date() > $1.value.first?.startDate ?? Date() }
    }

    // MARK: - Actions

    private func deleteWorkouts(dayWorkouts: [WorkoutRecord], at offsets: IndexSet) {
        for index in offsets {
            let workout = dayWorkouts[index]
            modelContext.delete(workout)
        }
    }

    // MARK: - Initialization

    public init() {}
}

// MARK: - Workout Row View

struct WorkoutRowView: View {
    let workout: WorkoutRecord

    var body: some View {
        HStack(spacing: 16) {
            // Time indicator
            VStack(alignment: .leading, spacing: 2) {
                Text(timeString)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50, alignment: .leading)

            // Main content
            VStack(alignment: .leading, spacing: 6) {
                // Duration
                Text(workout.formattedDuration)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                // Intervals summary
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("\(workout.runIntervals)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.orange)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("\(workout.walkIntervals)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.green)
                    }

                    if workout.caloriesBurned > 0 {
                        Text("\(Int(workout.caloriesBurned)) kcal")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // HealthKit indicator
            if workout.savedToHealthKit {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.pink)
            }
        }
        .padding(.vertical, 8)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: workout.startDate)
    }
}

// MARK: - Preview

#Preview {
    WorkoutHistoryView()
        .modelContainer(for: WorkoutRecord.self, inMemory: true)
}
