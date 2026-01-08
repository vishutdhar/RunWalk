import SwiftUI
import RunWalkShared

/// Workout completion summary view for watchOS
/// Designed to fit on one screen without scrolling
struct WatchSummaryView: View {
    // MARK: - Properties

    let stats: WorkoutStats
    let onDismiss: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 6) {
            // Success indicator
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)

            Text("Complete!")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            // Total duration
            VStack(spacing: 2) {
                Text("Total Time")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(stats.formattedDuration)
                    .font(.system(size: 32, weight: .light, design: .rounded))
                    .monospacedDigit()
            }

            // Interval counts - inline
            HStack(spacing: 16) {
                // Run intervals
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("RUN")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    Text("\(stats.runIntervals)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }

                // Walk intervals
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("WALK")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    Text("\(stats.walkIntervals)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
            }

            Spacer(minLength: 2)

            // Done button - compact
            Button("Done", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.mini)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview {
    WatchSummaryView(
        stats: WorkoutStats(
            totalDuration: 1234,
            runIntervals: 8,
            walkIntervals: 7,
            startTime: Date(),
            endTime: Date()
        ),
        onDismiss: {}
    )
}
