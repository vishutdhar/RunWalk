import SwiftUI
import WidgetKit

/// Inline complication view (accessoryInline)
/// - Idle: "RunWalk: Tap to start"
/// - Active: "RUN 2:30" or "WALK 1:15"
struct InlineComplicationView: View {
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
        Text("RunWalk: Tap to start")
            .widgetURL(URL(string: "runwalk://start"))
    }

    // MARK: - Active View

    private var activeView: some View {
        Text("\(entry.state.currentPhase) \(entry.state.formattedTimeRemaining)")
            .widgetURL(URL(string: "runwalk://open"))
    }
}
