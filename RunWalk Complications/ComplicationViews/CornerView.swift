import SwiftUI
import WidgetKit

/// Corner complication view (accessoryCorner)
/// - Idle: Running figure icon with "RunWalk" curved text
/// - Active: Countdown timer with phase label curved
struct CornerComplicationView: View {
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

            Image(systemName: "figure.run")
                .font(.system(size: 24, weight: .medium))
        }
        .widgetLabel {
            Text("RunWalk")
        }
        .widgetURL(URL(string: "runwalk://start"))
    }

    // MARK: - Active View

    private var activeView: some View {
        ZStack {
            // Progress gauge in corner
            Gauge(value: entry.state.progress) {
                Text(entry.state.formattedTimeRemaining)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(phaseColor)
        }
        .widgetLabel {
            Text(entry.state.currentPhase)
                .foregroundStyle(phaseColor)
        }
        .widgetURL(URL(string: "runwalk://open"))
    }

    // MARK: - Helpers

    private var phaseColor: Color {
        entry.state.isRunPhase ? .orange : .green
    }
}
