import Foundation
import SwiftData

// MARK: - Preset Manager

/// Manages workout presets including seeding built-in presets and user preset operations
@MainActor
public final class PresetManager {
    // MARK: - Singleton

    /// Shared instance for convenience
    public static let shared = PresetManager()

    // MARK: - Constants

    /// UserDefaults key for tracking if built-in presets have been seeded
    private static let presetsSeededKey = "builtInPresetsSeeded"

    /// Current version of built-in presets (increment when adding new presets)
    private static let presetsVersion = 1

    /// UserDefaults key for tracking preset version
    private static let presetsVersionKey = "builtInPresetsVersion"

    // MARK: - Initialization

    public init() {}

    // MARK: - Seeding

    /// Seeds built-in presets if they haven't been added yet
    /// Call this on app launch
    public func seedBuiltInPresetsIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard
        let seededVersion = defaults.integer(forKey: Self.presetsVersionKey)

        // Already seeded with current version
        if seededVersion >= Self.presetsVersion {
            return
        }

        // Check if any built-in presets exist (handles first launch)
        let descriptor = FetchDescriptor<WorkoutPreset>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )

        do {
            let existingBuiltIn = try context.fetch(descriptor)

            if existingBuiltIn.isEmpty {
                // First time - seed all built-in presets
                seedAllBuiltInPresets(context: context)
            } else {
                // Upgrade path - add any new presets that don't exist
                seedMissingBuiltInPresets(existing: existingBuiltIn, context: context)
            }

            // Mark as seeded
            defaults.set(Self.presetsVersion, forKey: Self.presetsVersionKey)
            defaults.set(true, forKey: Self.presetsSeededKey)

        } catch {
            print("PresetManager: Failed to check existing presets: \(error)")
        }
    }

    /// Seeds all built-in presets (first launch)
    private func seedAllBuiltInPresets(context: ModelContext) {
        for preset in WorkoutPreset.builtInPresets {
            context.insert(preset)
        }

        do {
            try context.save()
            print("PresetManager: Seeded \(WorkoutPreset.builtInPresets.count) built-in presets")
        } catch {
            print("PresetManager: Failed to save seeded presets: \(error)")
        }
    }

    /// Seeds any missing built-in presets (upgrade path)
    private func seedMissingBuiltInPresets(existing: [WorkoutPreset], context: ModelContext) {
        let existingNames = Set(existing.map { $0.name })
        var addedCount = 0

        for preset in WorkoutPreset.builtInPresets {
            if !existingNames.contains(preset.name) {
                context.insert(preset)
                addedCount += 1
            }
        }

        if addedCount > 0 {
            do {
                try context.save()
                print("PresetManager: Added \(addedCount) new built-in presets")
            } catch {
                print("PresetManager: Failed to save new presets: \(error)")
            }
        }
    }

    // MARK: - User Preset Operations

    /// Creates a new user preset from the given intervals
    /// - Parameters:
    ///   - name: Display name for the preset
    ///   - runSeconds: Run interval in seconds
    ///   - walkSeconds: Walk interval in seconds
    ///   - context: SwiftData model context
    /// - Returns: The created preset
    @discardableResult
    public func createUserPreset(
        name: String,
        runSeconds: Int,
        walkSeconds: Int,
        context: ModelContext
    ) -> WorkoutPreset {
        // Find the next sort order for user presets
        let nextSortOrder = getNextUserPresetSortOrder(context: context)

        let preset = WorkoutPreset(
            name: name,
            description: nil,
            runIntervalSeconds: runSeconds,
            walkIntervalSeconds: walkSeconds,
            category: .custom,
            isBuiltIn: false,
            sortOrder: nextSortOrder,
            createdDate: Date()
        )

        context.insert(preset)

        do {
            try context.save()
            print("PresetManager: Created user preset '\(name)'")
        } catch {
            print("PresetManager: Failed to save user preset: \(error)")
        }

        return preset
    }

    /// Deletes a user preset (built-in presets cannot be deleted)
    /// - Parameters:
    ///   - preset: The preset to delete
    ///   - context: SwiftData model context
    /// - Returns: True if deleted, false if it's a built-in preset
    @discardableResult
    public func deletePreset(_ preset: WorkoutPreset, context: ModelContext) -> Bool {
        guard !preset.isBuiltIn else {
            print("PresetManager: Cannot delete built-in preset '\(preset.name)'")
            return false
        }

        context.delete(preset)

        do {
            try context.save()
            print("PresetManager: Deleted user preset '\(preset.name)'")
            return true
        } catch {
            print("PresetManager: Failed to delete preset: \(error)")
            return false
        }
    }

    /// Updates a user preset's name
    /// - Parameters:
    ///   - preset: The preset to update
    ///   - newName: The new name
    ///   - context: SwiftData model context
    /// - Returns: True if updated, false if it's a built-in preset
    @discardableResult
    public func renamePreset(_ preset: WorkoutPreset, to newName: String, context: ModelContext) -> Bool {
        guard !preset.isBuiltIn else {
            print("PresetManager: Cannot rename built-in preset '\(preset.name)'")
            return false
        }

        preset.name = newName

        do {
            try context.save()
            print("PresetManager: Renamed preset to '\(newName)'")
            return true
        } catch {
            print("PresetManager: Failed to rename preset: \(error)")
            return false
        }
    }

    // MARK: - Fetching

    /// Fetches all presets grouped by category
    /// - Parameter context: SwiftData model context
    /// - Returns: Dictionary of category to presets
    public func fetchPresetsGroupedByCategory(context: ModelContext) -> [PresetCategory: [WorkoutPreset]] {
        let descriptor = FetchDescriptor<WorkoutPreset>(
            sortBy: [
                SortDescriptor(\.categoryRaw),
                SortDescriptor(\.sortOrder),
                SortDescriptor(\.name)
            ]
        )

        do {
            let allPresets = try context.fetch(descriptor)
            return Dictionary(grouping: allPresets, by: { $0.category })
        } catch {
            print("PresetManager: Failed to fetch presets: \(error)")
            return [:]
        }
    }

    /// Fetches all user-created presets
    /// - Parameter context: SwiftData model context
    /// - Returns: Array of user presets sorted by creation date
    public func fetchUserPresets(context: ModelContext) -> [WorkoutPreset] {
        let descriptor = FetchDescriptor<WorkoutPreset>(
            predicate: #Predicate { $0.isBuiltIn == false },
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("PresetManager: Failed to fetch user presets: \(error)")
            return []
        }
    }

    /// Checks if a preset with the given name already exists
    /// - Parameters:
    ///   - name: The name to check
    ///   - context: SwiftData model context
    /// - Returns: True if a preset with this name exists
    public func presetExists(named name: String, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<WorkoutPreset>(
            predicate: #Predicate { $0.name == name }
        )

        do {
            let count = try context.fetchCount(descriptor)
            return count > 0
        } catch {
            print("PresetManager: Failed to check preset existence: \(error)")
            return false
        }
    }

    // MARK: - Private Helpers

    /// Gets the next sort order for user presets
    private func getNextUserPresetSortOrder(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<WorkoutPreset>(
            predicate: #Predicate { $0.isBuiltIn == false },
            sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
        )

        do {
            let userPresets = try context.fetch(descriptor)
            if let highest = userPresets.first {
                return highest.sortOrder + 1
            }
            return 0
        } catch {
            return 0
        }
    }
}
