import SwiftUI
import WidgetKit

/// Rectangular complication view (accessoryRectangular)
/// - Idle: App name with "Tap to start" subtitle
/// - Active: Phase indicator, countdown, and progress bar
struct RectangularComplicationView: View {
    let entry: ComplicationEntry

    var body: some View {
        if entry.state.isActive {
            activeView
        } else {
            idleView
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        HStack(spacing: 8) {
            Image(systemName: "figure.run")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text("Run")
                        .foregroundStyle(.orange)
                    Text("Walk")
                        .foregroundStyle(.green)
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))

                Text("Tap to start")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .widgetURL(URL(string: "runwalk://start"))
    }

    // MARK: - Active View

    private var activeView: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Phase and time row
            HStack {
                // Phase indicator dot
                Circle()
                    .fill(phaseColor)
                    .frame(width: 8, height: 8)

                Text(entry.state.currentPhase)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(phaseColor)

                Spacer()

                Text(entry.state.formattedTimeRemaining)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            // Progress bar
            ProgressView(value: entry.state.progress)
                .tint(phaseColor)
        }
        .widgetURL(URL(string: "runwalk://open"))
    }

    // MARK: - Helpers

    private var phaseColor: Color {
        entry.state.isRunPhase ? .orange : .green
    }
}
