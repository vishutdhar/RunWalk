import WidgetKit
import SwiftUI

/// Main widget definition for RunWalk complications
struct RunWalkComplication: Widget {
    let kind: String = "RunWalkComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationTimelineProvider()) { entry in
            ComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("RunWalk")
        .description("Quick start workouts or view live progress")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

/// Entry view that routes to the appropriate complication view based on family
struct ComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: ComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryCorner:
            CornerComplicationView(entry: entry)
        case .accessoryRectangular:
            RectangularComplicationView(entry: entry)
        case .accessoryInline:
            InlineComplicationView(entry: entry)
        default:
            // Fallback for any unsupported families
            Text("RunWalk")
        }
    }
}

/// Widget bundle that exposes our complication
@main
struct RunWalkComplicationBundle: WidgetBundle {
    var body: some Widget {
        RunWalkComplication()
    }
}

// MARK: - Previews

#Preview("Circular - Idle", as: .accessoryCircular) {
    RunWalkComplication()
} timeline: {
    ComplicationEntry(date: Date(), state: .idle)
}

#Preview("Circular - Active Run", as: .accessoryCircular) {
    RunWalkComplication()
} timeline: {
    ComplicationEntry(date: Date(), state: SharedWorkoutState(
        isActive: true,
        currentPhase: "RUN",
        timeRemaining: 25,
        intervalDuration: 30,
        lastUpdate: Date(),
        runIntervalSetting: 30,
        walkIntervalSetting: 60
    ))
}

#Preview("Corner - Idle", as: .accessoryCorner) {
    RunWalkComplication()
} timeline: {
    ComplicationEntry(date: Date(), state: .idle)
}

#Preview("Rectangular - Active Walk", as: .accessoryRectangular) {
    RunWalkComplication()
} timeline: {
    ComplicationEntry(date: Date(), state: SharedWorkoutState(
        isActive: true,
        currentPhase: "WALK",
        timeRemaining: 45,
        intervalDuration: 60,
        lastUpdate: Date(),
        runIntervalSetting: 30,
        walkIntervalSetting: 60
    ))
}

#Preview("Inline - Active", as: .accessoryInline) {
    RunWalkComplication()
} timeline: {
    ComplicationEntry(date: Date(), state: SharedWorkoutState(
        isActive: true,
        currentPhase: "RUN",
        timeRemaining: 90,
        intervalDuration: 120,
        lastUpdate: Date(),
        runIntervalSetting: 120,
        walkIntervalSetting: 60
    ))
}
