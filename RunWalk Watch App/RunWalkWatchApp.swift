import SwiftUI
import SwiftData
import RunWalkWatchFeature
import RunWalkShared

@main
struct RunWalkWatchApp: App {
    /// Timer instance shared with the content view for deep link support
    @State private var timer = WatchIntervalTimer()

    /// Model container for SwiftData persistence
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: WorkoutRecord.self, WorkoutPreset.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView(timer: timer)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .task {
                    // Seed built-in presets on first launch
                    let context = modelContainer.mainContext
                    PresetManager.shared.seedBuiltInPresetsIfNeeded(context: context)
                }
        }
        .modelContainer(modelContainer)
    }

    /// Handles deep links from widget complications
    /// - Parameter url: The URL that opened the app
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "runwalk" else { return }

        switch url.host {
        case "start":
            // Start workout if not already active
            if !timer.isActive && !timer.isCountingDown {
                timer.start()
            }
        default:
            break
        }
    }
}
