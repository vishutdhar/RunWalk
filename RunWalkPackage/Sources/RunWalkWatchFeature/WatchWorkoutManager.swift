import Foundation
import HealthKit
import Observation
import RunWalkShared

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

    /// Maximum heart rate (calculated from age or manual setting)
    public private(set) var maxHeartRate: Double = 190  // Default for ~30 year old

    /// Current heart rate zone based on current HR and max HR
    public var currentHeartRateZone: HeartRateZone? {
        HeartRateZone.zone(forHeartRate: heartRate, maxHeartRate: maxHeartRate)
    }

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
        // Types we want to read (including date of birth for HR zone calculation)
        var readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType()
        ]

        // Add date of birth characteristic for max heart rate calculation
        if let dateOfBirthType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) {
            readTypes.insert(dateOfBirthType)
        }

        // Types we want to write
        let writeTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType()
        ]

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            // After authorization, try to calculate max HR from date of birth
            await updateMaxHeartRateFromAge()
            return true
        } catch {
            errorMessage = "HealthKit authorization failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Heart Rate Zone Support

    /// Updates max heart rate based on user's age from HealthKit
    /// Falls back to stored manual age if date of birth is unavailable
    public func updateMaxHeartRateFromAge() async {
        // First try to get age from HealthKit date of birth
        if let age = getAgeFromHealthKit() {
            maxHeartRate = HeartRateZone.maxHeartRate(forAge: age)
            return
        }

        // Fall back to manually set age from UserDefaults
        let manualAge = UserDefaults.standard.integer(forKey: "manualAge")
        if manualAge > 0 {
            maxHeartRate = HeartRateZone.maxHeartRate(forAge: manualAge)
            return
        }

        // Default: assume 30 years old (max HR = 190)
        maxHeartRate = 190
    }

    /// Attempts to get user's age from HealthKit date of birth
    /// - Returns: Age in years, or nil if unavailable
    private func getAgeFromHealthKit() -> Int? {
        do {
            let birthComponents = try healthStore.dateOfBirthComponents()
            guard let birthYear = birthComponents.year else { return nil }

            let currentYear = Calendar.current.component(.year, from: Date())
            let age = currentYear - birthYear

            // Sanity check: age should be between 10 and 120
            guard age >= 10 && age <= 120 else { return nil }

            return age
        } catch {
            // Date of birth not available - this is normal if user hasn't set it
            return nil
        }
    }

    /// Manually set max heart rate (for users who know their actual max HR)
    /// - Parameter maxHR: Maximum heart rate in BPM
    public func setMaxHeartRate(_ maxHR: Double) {
        guard maxHR > 100 && maxHR < 250 else { return }
        maxHeartRate = maxHR
    }

    /// Set age manually for max HR calculation (fallback when HealthKit DOB unavailable)
    /// - Parameter age: User's age in years
    public func setManualAge(_ age: Int) {
        guard age >= 10 && age <= 120 else { return }
        UserDefaults.standard.set(age, forKey: "manualAge")
        maxHeartRate = HeartRateZone.maxHeartRate(forAge: age)
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
