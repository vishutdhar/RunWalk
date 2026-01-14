import Foundation
import SwiftData

/// Manages workout presets - seeding built-in presets and CRUD operations
@MainActor
public final class PresetManager {
    // MARK: - Singleton

    public static let shared = PresetManager()

    private init() {}

    // MARK: - Constants

    /// Key for storing the presets version in UserDefaults
    private static let presetsVersionKey = "workoutPresetsVersion"

    /// Current version of built-in presets (increment when adding new presets)
    private static let currentPresetsVersion = 1

    // MARK: - Seeding

    /// Seeds built-in presets if they haven't been added yet
    /// - Parameter context: The SwiftData model context
    public func seedBuiltInPresetsIfNeeded(context: ModelContext) {
        let storedVersion = UserDefaults.standard.integer(forKey: Self.presetsVersionKey)

        // Only seed if we haven't seeded this version yet
        guard storedVersion < Self.currentPresetsVersion else { return }

        // Check if any presets exist
        let descriptor = FetchDescriptor<WorkoutPreset>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )

        do {
            let existingPresets = try context.fetch(descriptor)

            // If no built-in presets exist, add them all
            if existingPresets.isEmpty {
                for preset in WorkoutPreset.builtInPresets {
                    context.insert(preset)
                }
            }

            // Update version
            UserDefaults.standard.set(Self.currentPresetsVersion, forKey: Self.presetsVersionKey)
        } catch {
            print("Error seeding presets: \(error)")
        }
    }

    // MARK: - CRUD Operations

    /// Creates a new user preset
    /// - Parameters:
    ///   - name: Name for the preset
    ///   - description: Optional description
    ///   - runSeconds: Run interval in seconds
    ///   - walkSeconds: Walk interval in seconds
    ///   - context: The SwiftData model context
    /// - Returns: The created preset
    @discardableResult
    public func createUserPreset(
        name: String,
        description: String? = nil,
        runSeconds: Int,
        walkSeconds: Int,
        context: ModelContext
    ) -> WorkoutPreset {
        // Find the highest sort order in custom category
        let descriptor = FetchDescriptor<WorkoutPreset>(
            predicate: #Predicate { $0.categoryRaw == "My Presets" }
        )

        var nextSortOrder = 0
        if let existingPresets = try? context.fetch(descriptor) {
            nextSortOrder = (existingPresets.map(\.sortOrder).max() ?? -1) + 1
        }

        let preset = WorkoutPreset(
            name: name,
            description: description,
            runIntervalSeconds: runSeconds,
            walkIntervalSeconds: walkSeconds,
            category: .custom,
            isBuiltIn: false,
            sortOrder: nextSortOrder
        )

        context.insert(preset)
        return preset
    }

    /// Deletes a preset (only user presets can be deleted)
    /// - Parameters:
    ///   - preset: The preset to delete
    ///   - context: The SwiftData model context
    /// - Returns: True if deleted, false if preset is built-in
    @discardableResult
    public func deletePreset(_ preset: WorkoutPreset, context: ModelContext) -> Bool {
        guard !preset.isBuiltIn else { return false }
        context.delete(preset)
        return true
    }

    /// Updates an existing user preset
    /// - Parameters:
    ///   - preset: The preset to update
    ///   - name: New name
    ///   - description: New description
    ///   - runSeconds: New run interval
    ///   - walkSeconds: New walk interval
    /// - Returns: True if updated, false if preset is built-in
    @discardableResult
    public func updatePreset(
        _ preset: WorkoutPreset,
        name: String,
        description: String?,
        runSeconds: Int,
        walkSeconds: Int
    ) -> Bool {
        guard !preset.isBuiltIn else { return false }

        preset.name = name
        preset.presetDescription = description
        preset.runIntervalSeconds = runSeconds
        preset.walkIntervalSeconds = walkSeconds

        return true
    }
}
