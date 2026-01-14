import AppIntents
import SwiftUI
import RunWalkShared

// MARK: - Shared State for Intent Communication

/// Singleton to communicate intent actions to the running app
@MainActor
public final class IntentActionHandler: ObservableObject {
    public static let shared = IntentActionHandler()

    /// Action requested by an App Intent
    public enum Action: Equatable, Sendable {
        case none
        case startWorkout(runSeconds: Int, walkSeconds: Int)
        case startPreset(presetName: String)
    }

    /// The pending action to be handled by the app
    @Published public var pendingAction: Action = .none

    private init() {}

    /// Clears the pending action after it's been handled
    public func clearAction() {
        pendingAction = .none
    }
}

// MARK: - Start Workout Intent

/// Intent to start a run-walk workout with specific intervals
public struct StartWorkoutIntent: AppIntent {
    public static let title: LocalizedStringResource = "Start Run-Walk Workout"
    public static let description: IntentDescription = IntentDescription("Start a run-walk interval workout with custom durations")

    @Parameter(title: "Run Interval (seconds)", default: 60)
    var runIntervalSeconds: Int

    @Parameter(title: "Walk Interval (seconds)", default: 60)
    var walkIntervalSeconds: Int

    public static let openAppWhenRun: Bool = true

    public init() {}

    public init(runSeconds: Int, walkSeconds: Int) {
        self.runIntervalSeconds = runSeconds
        self.walkIntervalSeconds = walkSeconds
    }

    @MainActor
    public func perform() async throws -> some IntentResult & OpensIntent {
        // Validate intervals (10 seconds to 30 minutes)
        let validatedRun = max(10, min(1800, runIntervalSeconds))
        let validatedWalk = max(10, min(1800, walkIntervalSeconds))

        // Set the pending action for the app to handle
        IntentActionHandler.shared.pendingAction = .startWorkout(
            runSeconds: validatedRun,
            walkSeconds: validatedWalk
        )

        return .result(opensIntent: OpenRunWalkIntent())
    }
}

// MARK: - Start Preset Workout Intent

/// Intent to start a workout using a saved preset
public struct StartPresetWorkoutIntent: AppIntent {
    public static let title: LocalizedStringResource = "Start Preset Workout"
    public static let description: IntentDescription = IntentDescription("Start a run-walk workout using a preset configuration")

    @Parameter(title: "Preset")
    var preset: PresetEntity

    public static let openAppWhenRun: Bool = true

    public init() {}

    public init(preset: PresetEntity) {
        self.preset = preset
    }

    @MainActor
    public func perform() async throws -> some IntentResult & OpensIntent {
        // Set the pending action for the app to handle
        IntentActionHandler.shared.pendingAction = .startPreset(presetName: preset.name)

        return .result(opensIntent: OpenRunWalkIntent())
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$preset) workout")
    }
}

// MARK: - Open App Intent

/// Simple intent to open the RunWalk app
public struct OpenRunWalkIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open RunWalk"
    public static let description: IntentDescription = IntentDescription("Open the RunWalk app")

    public static let openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Preset Entity

/// App Entity representing a workout preset for Siri
public struct PresetEntity: AppEntity, Sendable {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Workout Preset"

    public static let defaultQuery = PresetEntityQuery()

    public var id: String
    public var name: String
    public var runIntervalSeconds: Int
    public var walkIntervalSeconds: Int
    public var categoryName: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(formatInterval(runIntervalSeconds)) run / \(formatInterval(walkIntervalSeconds)) walk"
        )
    }

    public init(id: String, name: String, runIntervalSeconds: Int, walkIntervalSeconds: Int, categoryName: String) {
        self.id = id
        self.name = name
        self.runIntervalSeconds = runIntervalSeconds
        self.walkIntervalSeconds = walkIntervalSeconds
        self.categoryName = categoryName
    }

    /// Creates a PresetEntity from a WorkoutPreset
    public init(from preset: WorkoutPreset) {
        self.id = preset.id.uuidString
        self.name = preset.name
        self.runIntervalSeconds = preset.runIntervalSeconds
        self.walkIntervalSeconds = preset.walkIntervalSeconds
        self.categoryName = preset.category.rawValue
    }

    private func formatInterval(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes == 0 {
            return "\(secs)s"
        } else if secs == 0 {
            return "\(minutes)m"
        } else {
            return "\(minutes)m \(secs)s"
        }
    }
}

// MARK: - Preset Entity Query

/// Query for finding preset entities
public struct PresetEntityQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [PresetEntity] {
        // Return matching built-in presets
        return WorkoutPreset.builtInPresets
            .filter { identifiers.contains($0.id.uuidString) }
            .map { PresetEntity(from: $0) }
    }

    public func suggestedEntities() async throws -> [PresetEntity] {
        // Return all built-in presets as suggestions
        return WorkoutPreset.builtInPresets.map { PresetEntity(from: $0) }
    }

    public func defaultResult() async -> PresetEntity? {
        // Default to the "Beginner" preset
        if let beginner = WorkoutPreset.builtInPreset(named: "Beginner") {
            return PresetEntity(from: beginner)
        }
        return nil
    }
}

// MARK: - App Shortcuts Provider

/// Provides shortcuts to the Shortcuts app and Siri
public struct RunWalkShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(runSeconds: 60, walkSeconds: 60),
            phrases: [
                "Start a run walk workout with \(.applicationName)",
                "Start run walk in \(.applicationName)",
                "Begin interval training with \(.applicationName)"
            ],
            shortTitle: "Start Workout",
            systemImageName: "figure.run"
        )

        AppShortcut(
            intent: StartPresetWorkoutIntent(),
            phrases: [
                "Start \(\.$preset) workout with \(.applicationName)",
                "Use \(\.$preset) preset in \(.applicationName)",
                "Run \(\.$preset) in \(.applicationName)"
            ],
            shortTitle: "Start Preset",
            systemImageName: "star.fill"
        )
    }
}
