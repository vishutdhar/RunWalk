import Foundation
import SwiftData
import SwiftUI

// MARK: - Preset Category

/// Categories for organizing workout presets
public enum PresetCategory: String, Codable, CaseIterable, Sendable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case custom = "My Presets"

    /// Sort order for displaying categories
    public var sortOrder: Int {
        switch self {
        case .beginner: return 0
        case .intermediate: return 1
        case .advanced: return 2
        case .custom: return 3
        }
    }

    /// Icon for the category
    public var icon: String {
        switch self {
        case .beginner: return "figure.walk"
        case .intermediate: return "figure.run"
        case .advanced: return "flame.fill"
        case .custom: return "star.fill"
        }
    }

    /// Color for the category
    public var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        case .custom: return .purple
        }
    }
}

// MARK: - Workout Preset Model

/// A saved workout interval configuration
/// Can be a built-in preset or user-created
@Model
public final class WorkoutPreset {
    // MARK: - Stored Properties

    /// Unique identifier
    public var id: UUID

    /// Display name for the preset
    public var name: String

    /// Optional description explaining the preset
    public var presetDescription: String?

    /// Run interval duration in seconds
    public var runIntervalSeconds: Int

    /// Walk interval duration in seconds
    public var walkIntervalSeconds: Int

    /// Category for grouping (stored as raw value for SwiftData)
    public var categoryRaw: String

    /// Whether this is a built-in preset (cannot be deleted)
    public var isBuiltIn: Bool

    /// Sort order within the category
    public var sortOrder: Int

    /// When the preset was created
    public var createdDate: Date

    // MARK: - Computed Properties

    /// Category enum accessor
    public var category: PresetCategory {
        get { PresetCategory(rawValue: categoryRaw) ?? .custom }
        set { categoryRaw = newValue.rawValue }
    }

    /// Formatted run interval for display (e.g., "30s", "1m 30s")
    public var formattedRunInterval: String {
        formatSeconds(runIntervalSeconds)
    }

    /// Formatted walk interval for display (e.g., "1m", "2m")
    public var formattedWalkInterval: String {
        formatSeconds(walkIntervalSeconds)
    }

    /// Compact summary for list display (e.g., "30s / 1m")
    public var intervalSummary: String {
        "\(formattedRunInterval) / \(formattedWalkInterval)"
    }

    /// Full description including intervals
    public var fullDescription: String {
        if let desc = presetDescription {
            return "\(desc) • Run \(formattedRunInterval), Walk \(formattedWalkInterval)"
        }
        return "Run \(formattedRunInterval), Walk \(formattedWalkInterval)"
    }

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        runIntervalSeconds: Int,
        walkIntervalSeconds: Int,
        category: PresetCategory,
        isBuiltIn: Bool = false,
        sortOrder: Int = 0,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.presetDescription = description
        self.runIntervalSeconds = runIntervalSeconds
        self.walkIntervalSeconds = walkIntervalSeconds
        self.categoryRaw = category.rawValue
        self.isBuiltIn = isBuiltIn
        self.sortOrder = sortOrder
        self.createdDate = createdDate
    }

    // MARK: - Private Helpers

    /// Formats seconds into a readable string
    private func formatSeconds(_ seconds: Int) -> String {
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

// MARK: - Built-in Presets

extension WorkoutPreset {
    /// Default built-in presets that ship with the app
    public static var builtInPresets: [WorkoutPreset] {
        [
            // Beginner presets
            WorkoutPreset(
                name: "Easy Start",
                description: "Perfect for beginners",
                runIntervalSeconds: 30,
                walkIntervalSeconds: 60,
                category: .beginner,
                isBuiltIn: true,
                sortOrder: 0
            ),
            WorkoutPreset(
                name: "Beginner",
                description: "Equal run and walk times",
                runIntervalSeconds: 60,
                walkIntervalSeconds: 60,
                category: .beginner,
                isBuiltIn: true,
                sortOrder: 1
            ),

            // Intermediate presets
            WorkoutPreset(
                name: "Building Up",
                description: "Longer runs, shorter walks",
                runIntervalSeconds: 90,
                walkIntervalSeconds: 60,
                category: .intermediate,
                isBuiltIn: true,
                sortOrder: 0
            ),
            WorkoutPreset(
                name: "Steady State",
                description: "2 minute runs",
                runIntervalSeconds: 120,
                walkIntervalSeconds: 60,
                category: .intermediate,
                isBuiltIn: true,
                sortOrder: 1
            ),

            // Advanced presets
            WorkoutPreset(
                name: "Endurance",
                description: "Extended running intervals",
                runIntervalSeconds: 180,
                walkIntervalSeconds: 60,
                category: .advanced,
                isBuiltIn: true,
                sortOrder: 0
            ),
            WorkoutPreset(
                name: "Race Prep",
                description: "Long runs with recovery",
                runIntervalSeconds: 300,
                walkIntervalSeconds: 60,
                category: .advanced,
                isBuiltIn: true,
                sortOrder: 1
            )
        ]
    }

    /// Finds a built-in preset by name
    public static func builtInPreset(named name: String) -> WorkoutPreset? {
        builtInPresets.first { $0.name == name }
    }
}

// MARK: - Sorting

extension WorkoutPreset {
    /// Compares presets for sorting (by category, then sort order, then name)
    public static func sortedComparator(_ lhs: WorkoutPreset, _ rhs: WorkoutPreset) -> Bool {
        if lhs.category.sortOrder != rhs.category.sortOrder {
            return lhs.category.sortOrder < rhs.category.sortOrder
        }
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        return lhs.name < rhs.name
    }
}
