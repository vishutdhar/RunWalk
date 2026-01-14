import SwiftUI
import SwiftData
import AppIntents
import RunWalkFeature
import RunWalkShared

@main
struct RunWalkApp: App {
    /// Strava manager for sharing workouts
    @State private var stravaManager = StravaManager()

    /// Model container for SwiftData persistence
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: WorkoutRecord.self, WorkoutPreset.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Update App Shortcuts metadata for Siri
        RunWalkShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .environment(stravaManager)
                .task {
                    // Seed built-in presets on first launch
                    let context = modelContainer.mainContext
                    PresetManager.shared.seedBuiltInPresetsIfNeeded(context: context)
                }
        }
        .modelContainer(modelContainer)
    }
}
