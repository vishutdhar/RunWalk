import SwiftUI
import SwiftData
import RunWalkWatchFeature
import RunWalkShared

@main
struct RunWalkWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
        .modelContainer(for: WorkoutRecord.self)
    }
}
