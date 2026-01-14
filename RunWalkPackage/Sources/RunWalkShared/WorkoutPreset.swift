import Foundation
import SwiftData

// MARK: - PresetCategory

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

    /// SF Symbol icon for the category
    public var icon: String {
        switch self {
        case .beginner: return "figure.walk"
        case .intermediate: return "figure.run"
        case .advanced: return "flame.fill"
        case .custom: return "star.fill"
        }
    }

    /// Color name for the category (for SwiftUI Color)
    public var colorName: String {
        switch self {
        case .beginner: return "green"
        case .intermediate: return "orange"
        case .advanced: return "red"
        case .custom: return "purple"
        }
    }
}

// MARK: - WorkoutPreset

/// A saved workout preset with run/walk intervals
@Model
public final class WorkoutPreset {
    // MARK: - Properties

    /// Unique identifier
    public var id: UUID

    /// Display name for the preset
    public var name: String

    /// Optional description
    public var presetDescription: String?

    /// Run interval duration in seconds
    public var runIntervalSeconds: Int

    /// Walk interval duration in seconds
    public var walkIntervalSeconds: Int

    /// Category raw value (stored as String for SwiftData)
    public var categoryRaw: String

    /// Whether this is a built-in preset (cannot be deleted)
    public var isBuiltIn: Bool

    /// Sort order within category
    public var sortOrder: Int

    /// Date the preset was created
    public var createdDate: Date

    // MARK: - Computed Properties

    /// Category enum value
    public var category: PresetCategory {
        get { PresetCategory(rawValue: categoryRaw) ?? .custom }
        set { categoryRaw = newValue.rawValue }
    }

    /// Formatted run interval (e.g., "1m 30s")
    public var formattedRunInterval: String {
        formatSeconds(runIntervalSeconds)
    }

    /// Formatted walk interval (e.g., "1m")
    public var formattedWalkInterval: String {
        formatSeconds(walkIntervalSeconds)
    }

    /// Summary of intervals (e.g., "1m 30s / 1m")
    public var intervalSummary: String {
        "\(formattedRunInterval) / \(formattedWalkInterval)"
    }

    /// Full description including intervals
    public var fullDescription: String {
        var parts: [String] = []
        if let desc = presetDescription {
            parts.append(desc)
        }
        parts.append("Run: \(formattedRunInterval)")
        parts.append("Walk: \(formattedWalkInterval)")
        return parts.joined(separator: " • ")
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

    // MARK: - Helper Methods

    private func formatSeconds(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes == 0 {
            return "\(seconds)s"
        } else if seconds == 0 {
            return "\(minutes)m"
        } else {
            return "\(minutes)m \(seconds)s"
        }
    }

    // MARK: - Sorting

    /// Comparator for sorting presets by category, then sortOrder, then name
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

// MARK: - Built-in Presets

extension WorkoutPreset {
    /// Built-in workout presets
    public static var builtInPresets: [WorkoutPreset] {
        [
            // Beginner
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
                description: "Build your base",
                runIntervalSeconds: 60,
                walkIntervalSeconds: 60,
                category: .beginner,
                isBuiltIn: true,
                sortOrder: 1
            ),

            // Intermediate
            WorkoutPreset(
                name: "Building Up",
                description: "Increase your running time",
                runIntervalSeconds: 90,
                walkIntervalSeconds: 60,
                category: .intermediate,
                isBuiltIn: true,
                sortOrder: 0
            ),
            WorkoutPreset(
                name: "Steady State",
                description: "Balanced intervals",
                runIntervalSeconds: 120,
                walkIntervalSeconds: 60,
                category: .intermediate,
                isBuiltIn: true,
                sortOrder: 1
            ),

            // Advanced
            WorkoutPreset(
                name: "Endurance",
                description: "Longer running intervals",
                runIntervalSeconds: 180,
                walkIntervalSeconds: 60,
                category: .advanced,
                isBuiltIn: true,
                sortOrder: 0
            ),
            WorkoutPreset(
                name: "Race Prep",
                description: "Extended running periods",
                runIntervalSeconds: 300,
                walkIntervalSeconds: 60,
                category: .advanced,
                isBuiltIn: true,
                sortOrder: 1
            ),
        ]
    }

    /// Find a built-in preset by name
    public static func builtInPreset(named name: String) -> WorkoutPreset? {
        builtInPresets.first { $0.name == name }
    }
}
