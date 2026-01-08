import Foundation
import HealthKit
import Observation

/// Manages HKWorkoutSession for background execution on watchOS
/// This is CRITICAL - without HKWorkoutSession the app stops when wrist is lowered
@Observable
@MainActor
public final class WatchWorkoutManager: NSObject {
    // MARK: - Published State

    /// Current workout session state
    public private(set) var sessionState: HKWorkoutSessionState = .notStarted

    /// Whether a workout is currently active
    public var isActive: Bool {
        sessionState == .running || sessionState == .paused
    }

    /// Whether the workout is currently running (not paused)
    public var isRunning: Bool {
        sessionState == .running
    }

    /// Total calories burned (updated live during workout)
    public private(set) var activeCalories: Double = 0

    /// Total distance covered if available
    public private(set) var distance: Double = 0

    /// Heart rate if available
    public private(set) var heartRate: Double = 0

    /// Error message if something goes wrong
    public private(set) var errorMessage: String?

    // MARK: - Private Properties

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    // MARK: - Initialization

    public override init() {
        super.init()
    }

    // MARK: - HealthKit Authorization

    /// Whether HealthKit is available on this device
    public var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Request authorization for workout data types
    public func requestAuthorization() async -> Bool {
        // Types we want to read
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType()
        ]

        // Types we want to write
        let writeTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType()
        ]

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            return true
        } catch {
            errorMessage = "HealthKit authorization failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Workout Session Control

    /// Starts a new workout session
    /// - Parameter startDate: When the workout starts (defaults to now)
    public func startWorkout(startDate: Date = Date()) async {
        guard session == nil else {
            errorMessage = "Workout already in progress"
            return
        }

        // Configure for running/walking activity
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        do {
            // Create the workout session
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            guard let session = session else { return }

            // Get the live workout builder
            builder = session.associatedWorkoutBuilder()
            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // Set delegates
            session.delegate = self
            builder?.delegate = self

            // Start the session and begin data collection
            session.startActivity(with: startDate)
            try await builder?.beginCollection(at: startDate)

            sessionState = .running
            errorMessage = nil

        } catch {
            errorMessage = "Failed to start workout: \(error.localizedDescription)"
            session = nil
            builder = nil
        }
    }

    /// Pauses the current workout
    public func pauseWorkout() {
        guard let session = session, sessionState == .running else { return }
        session.pause()
    }

    /// Resumes a paused workout
    public func resumeWorkout() {
        guard let session = session, sessionState == .paused else { return }
        session.resume()
    }

    /// Ends the workout and saves it to HealthKit
    /// - Returns: Whether the workout was saved successfully
    @discardableResult
    public func endWorkout() async -> Bool {
        guard let session = session, let builder = builder else {
            return false
        }

        // End the session
        session.end()

        do {
            // Finish the workout and save to HealthKit
            try await builder.endCollection(at: Date())
            try await builder.finishWorkout()

            // Reset state
            self.session = nil
            self.builder = nil
            sessionState = .notStarted
            activeCalories = 0
            distance = 0
            heartRate = 0

            return true

        } catch {
            errorMessage = "Failed to save workout: \(error.localizedDescription)"
            return false
        }
    }

    /// Discards the current workout without saving
    public func discardWorkout() {
        session?.end()
        builder?.discardWorkout()

        session = nil
        builder = nil
        sessionState = .notStarted
        activeCalories = 0
        distance = 0
        heartRate = 0
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            sessionState = toState
        }
    }

    nonisolated public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            errorMessage = "Workout session error: \(error.localizedDescription)"
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events (lap markers, etc.) if needed
    }

    nonisolated public func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            // Update live statistics from collected data
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType else { continue }

                if let statistics = workoutBuilder.statistics(for: quantityType) {
                    updateStatistics(statistics)
                }
            }
        }
    }

    /// Updates local properties from HealthKit statistics
    private func updateStatistics(_ statistics: HKStatistics) {
        switch statistics.quantityType {
        case HKQuantityType.quantityType(forIdentifier: .heartRate):
            if let value = statistics.mostRecentQuantity()?.doubleValue(for: .init(from: "count/min")) {
                heartRate = value
            }

        case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
            if let value = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                activeCalories = value
            }

        case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
            if let value = statistics.sumQuantity()?.doubleValue(for: .meter()) {
                distance = value
            }

        default:
            break
        }
    }
}
