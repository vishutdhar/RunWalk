import WidgetKit
import SwiftUI

/// Timeline entry representing the state at a point in time
struct ComplicationEntry: TimelineEntry {
    let date: Date
    let state: SharedWorkoutState
}

/// Provides timeline data for the RunWalk complications
struct ComplicationTimelineProvider: TimelineProvider {
    typealias Entry = ComplicationEntry

    // MARK: - Placeholder

    /// Returns a placeholder entry for the widget gallery
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), state: .idle)
    }

    // MARK: - Snapshot

    /// Returns a single entry for widget preview
    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        let state = SharedWorkoutStateManager.shared.readState()
        let entry = ComplicationEntry(date: Date(), state: state)
        completion(entry)
    }

    // MARK: - Timeline

    /// Returns a timeline of entries for the widget to display
    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let state = SharedWorkoutStateManager.shared.readState()
        let currentDate = Date()

        if state.isActive {
            // Active workout: create entries for countdown animation
            var entries: [ComplicationEntry] = []

            // Generate entries for the next 60 seconds (or until interval ends)
            let entriesToGenerate = min(state.timeRemaining, 60)

            for secondOffset in 0..<entriesToGenerate {
                let entryDate = currentDate.addingTimeInterval(TimeInterval(secondOffset))
                let updatedState = SharedWorkoutState(
                    isActive: true,
                    currentPhase: state.currentPhase,
                    timeRemaining: max(0, state.timeRemaining - secondOffset),
                    intervalDuration: state.intervalDuration,
                    lastUpdate: entryDate,
                    runIntervalSetting: state.runIntervalSetting,
                    walkIntervalSetting: state.walkIntervalSetting
                )
                entries.append(ComplicationEntry(date: entryDate, state: updatedState))
            }

            // Request refresh after entries run out or after 60 seconds
            let refreshDate = currentDate.addingTimeInterval(TimeInterval(max(entriesToGenerate, 30)))
            let timeline = Timeline(entries: entries, policy: .after(refreshDate))
            completion(timeline)
        } else {
            // Idle state: single entry, refresh less frequently
            let entry = ComplicationEntry(date: currentDate, state: state)
            // Refresh every hour when idle
            let refreshDate = currentDate.addingTimeInterval(3600)
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }
}

// MARK: - Shared State Import

/// Re-export SharedWorkoutState for use in this module
/// Note: This will be imported from RunWalkShared when the target is properly configured
struct SharedWorkoutState: Codable, Sendable {
    var isActive: Bool
    var currentPhase: String
    var timeRemaining: Int
    var intervalDuration: Int
    var lastUpdate: Date
    var runIntervalSetting: Int
    var walkIntervalSetting: Int

    static let idle = SharedWorkoutState(
        isActive: false,
        currentPhase: "RUN",
        timeRemaining: 0,
        intervalDuration: 0,
        lastUpdate: Date(),
        runIntervalSetting: 30,
        walkIntervalSetting: 60
    )

    var progress: Double {
        guard intervalDuration > 0 else { return 0 }
        return Double(intervalDuration - timeRemaining) / Double(intervalDuration)
    }

    var formattedTimeRemaining: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var isRunPhase: Bool {
        currentPhase == "RUN"
    }
}

/// Manager for reading shared state
/// Note: This mirrors the implementation in RunWalkShared
final class SharedWorkoutStateManager: Sendable {
    static let shared = SharedWorkoutStateManager()

    private let suiteName = "group.com.vishutdhar.RunWalk"
    private let stateKey = "currentWorkoutState"

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    private init() {}

    func readState() -> SharedWorkoutState {
        guard let defaults = userDefaults,
              let data = defaults.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(SharedWorkoutState.self, from: data)
        else {
            return .idle
        }

        // Check for stale state
        if state.isActive {
            let staleness = Date().timeIntervalSince(state.lastUpdate)
            if staleness > 5 {
                return .idle
            }
        }

        return state
    }
}
