import SwiftUI
import SwiftData
import RunWalkFeature

@main
struct RunWalkApp: App {
    /// Strava manager for sharing workouts
    @State private var stravaManager = StravaManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .environment(stravaManager)
        }
        .modelContainer(for: WorkoutRecord.self)
    }
}
