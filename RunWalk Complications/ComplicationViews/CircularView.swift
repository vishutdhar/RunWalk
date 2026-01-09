import SwiftUI
import WidgetKit

/// Circular complication view (accessoryCircular)
/// - Idle: Running figure icon with "Start" text
/// - Active: Phase indicator with countdown timer
struct CircularComplicationView: View {
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
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 2) {
                Image(systemName: "figure.run")
                    .font(.system(size: 20, weight: .medium))
                Text("Start")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
        }
        .widgetURL(URL(string: "runwalk://start"))
    }

    // MARK: - Active View

    private var activeView: some View {
        ZStack {
            // Progress ring
            Gauge(value: entry.state.progress) {
                EmptyView()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(phaseColor)

            // Center content
            VStack(spacing: 0) {
                Text(entry.state.currentPhase)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(phaseColor)

                Text(entry.state.formattedTimeRemaining)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .widgetURL(URL(string: "runwalk://open"))
    }

    // MARK: - Helpers

    private var phaseColor: Color {
        entry.state.isRunPhase ? .orange : .green
    }
}
