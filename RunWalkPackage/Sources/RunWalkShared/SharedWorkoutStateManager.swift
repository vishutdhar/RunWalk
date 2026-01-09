import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Manages shared workout state between Watch App and Widget Extension
/// Uses App Group UserDefaults for inter-process communication
public final class SharedWorkoutStateManager: Sendable {
    // MARK: - Singleton

    public static let shared = SharedWorkoutStateManager()

    // MARK: - Constants

    /// App Group identifier - must match entitlements
    private let suiteName = "group.com.vishutdhar.RunWalk"

    /// Key for storing workout state in UserDefaults
    private let stateKey = "currentWorkoutState"

    /// Widget kind identifier - must match Widget definition
    private let widgetKind = "RunWalkComplication"

    // MARK: - Private Properties

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Write State (Called by Watch App)

    /// Writes current workout state to shared storage
    /// - Parameter state: The current workout state to persist
    public func writeState(_ state: SharedWorkoutState) {
        guard let data = try? JSONEncoder().encode(state),
              let defaults = userDefaults else {
            return
        }

        defaults.set(data, forKey: stateKey)

        // Trigger widget timeline reload so complications update
        reloadWidgetTimelines()
    }

    /// Clears workout state when workout ends
    public func clearState() {
        userDefaults?.removeObject(forKey: stateKey)
        reloadWidgetTimelines()
    }

    // MARK: - Read State (Called by Widget Extension)

    /// Reads current workout state from shared storage
    /// - Returns: The persisted workout state, or idle state if none exists
    public func readState() -> SharedWorkoutState {
        guard let defaults = userDefaults,
              let data = defaults.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(SharedWorkoutState.self, from: data)
        else {
            return .idle
        }

        // Check if state is stale (more than 5 seconds old during active workout)
        if state.isActive {
            let staleness = Date().timeIntervalSince(state.lastUpdate)
            if staleness > 5 {
                // State is stale - workout may have ended unexpectedly
                return .idle
            }
        }

        return state
    }

    // MARK: - Widget Refresh

    /// Triggers widget timeline reload
    private func reloadWidgetTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        #endif
    }
}
