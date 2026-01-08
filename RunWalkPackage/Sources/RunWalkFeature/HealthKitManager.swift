import HealthKit
import Observation

/// Manages HealthKit integration for saving run-walk workouts
/// Handles authorization, workout saving, and energy burn estimation
@Observable
@MainActor
public final class HealthKitManager {
    // MARK: - Properties

    /// Whether the user has authorized HealthKit access
    public private(set) var isAuthorized: Bool = false

    /// Whether HealthKit is available on this device
    public var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Whether authorization has been requested (to avoid repeated prompts)
    public private(set) var hasRequestedAuthorization: Bool = false

    // MARK: - Private Properties

    private let healthStore: HKHealthStore?

    /// Types we want to write to HealthKit
    private var typesToWrite: Set<HKSampleType> {
        var types: Set<HKSampleType> = [HKObjectType.workoutType() as HKSampleType]

        // Add active energy burned if available
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }

        return types
    }

    /// Types we want to read from HealthKit (for future history feature)
    private var typesToRead: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]

        // Add active energy burned if available
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }

        return types
    }

    // MARK: - Initialization

    public init() {
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HKHealthStore()
        } else {
            self.healthStore = nil
        }
    }

    // MARK: - Authorization

    /// Requests HealthKit authorization from the user
    /// This should be called before attempting to save workouts
    public func requestAuthorization() async {
        guard let healthStore else {
            print("HealthKit not available on this device")
            return
        }

        hasRequestedAuthorization = true

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)

            // Check if we have write permission for workouts
            let workoutStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
            isAuthorized = workoutStatus == .sharingAuthorized

        } catch {
            print("HealthKit authorization failed: \(error)")
            isAuthorized = false
        }
    }

    /// Checks current authorization status without prompting
    public func checkAuthorizationStatus() {
        guard let healthStore else {
            isAuthorized = false
            return
        }

        let workoutStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        isAuthorized = workoutStatus == .sharingAuthorized
    }

    // MARK: - Workout Saving

    /// Saves a completed run-walk workout to HealthKit
    /// - Parameter stats: The workout statistics to save
    /// - Returns: True if the workout was saved successfully
    @discardableResult
    public func saveWorkout(stats: WorkoutStats) async -> Bool {
        guard let healthStore else {
            print("Cannot save workout: HealthKit not available")
            return false
        }

        // Request authorization if not yet authorized
        if !isAuthorized && !hasRequestedAuthorization {
            await requestAuthorization()
        }

        guard isAuthorized else {
            print("Cannot save workout: HealthKit not authorized")
            return false
        }

        guard let startTime = stats.startTime, let endTime = stats.endTime else {
            print("Cannot save workout: Missing start or end time")
            return false
        }

        // Use running as the activity type - run-walk is a recognized running training method
        // (Jeff Galloway's Run-Walk-Run method). This ensures the workout appears properly
        // in Apple Fitness as a "Running" workout with interval metadata.
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        // Estimate calories burned based on duration
        // Using a conservative estimate: ~6-8 calories per minute for interval training
        let estimatedCalories = estimateCaloriesBurned(
            duration: stats.totalDuration,
            runIntervals: stats.runIntervals,
            walkIntervals: stats.walkIntervals
        )

        // Use HKWorkoutBuilder (iOS 17+ recommended approach)
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: nil)

        do {
            // Begin collection at workout start time
            try await builder.beginCollection(at: startTime)

            // Add energy burned sample
            if let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: estimatedCalories)
                let energySample = HKQuantitySample(
                    type: activeEnergyType,
                    quantity: energyQuantity,
                    start: startTime,
                    end: endTime
                )
                try await builder.addSamples([energySample])
            }

            // End collection
            try await builder.endCollection(at: endTime)

            // Add metadata before finishing
            try await builder.addMetadata([
                HKMetadataKeyWorkoutBrandName: "RunWalk",
                "RunIntervals": stats.runIntervals,
                "WalkIntervals": stats.walkIntervals,
                "TotalIntervals": stats.totalIntervals
            ])

            // Finish workout
            let workout = try await builder.finishWorkout()

            if workout != nil {
                print("Workout saved to HealthKit: \(stats.formattedDuration), \(Int(estimatedCalories)) kcal")
                return true
            } else {
                print("Failed to save workout: builder returned nil")
                return false
            }
        } catch {
            print("Failed to save workout to HealthKit: \(error)")
            // Discard the builder on failure
            builder.discardWorkout()
            return false
        }
    }

    // MARK: - Calorie Estimation

    /// Estimates calories burned based on workout duration and interval counts
    /// Uses different rates for running vs walking intervals
    private func estimateCaloriesBurned(
        duration: TimeInterval,
        runIntervals: Int,
        walkIntervals: Int
    ) -> Double {
        // Approximate calories per minute:
        // Running: ~10-12 calories/minute (use 10 to be conservative)
        // Walking: ~3-5 calories/minute (use 4 to be conservative)

        let totalIntervals = runIntervals + walkIntervals
        guard totalIntervals > 0 else {
            // Fallback: use average rate of 7 cal/min
            return (duration / 60.0) * 7.0
        }

        // Estimate time spent in each phase based on interval counts
        let runFraction = Double(runIntervals) / Double(totalIntervals)
        let walkFraction = Double(walkIntervals) / Double(totalIntervals)

        let runDuration = duration * runFraction
        let walkDuration = duration * walkFraction

        // Calculate calories for each phase
        let runCalories = (runDuration / 60.0) * 10.0  // 10 cal/min for running
        let walkCalories = (walkDuration / 60.0) * 4.0  // 4 cal/min for walking

        return runCalories + walkCalories
    }

    // MARK: - Workout History (Future Feature)

    /// Fetches recent workouts saved by this app
    /// - Parameter limit: Maximum number of workouts to fetch
    /// - Returns: Array of workout summaries
    public func fetchRecentWorkouts(limit: Int = 10) async -> [WorkoutStats] {
        guard let healthStore, isAuthorized else {
            return []
        }

        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        // Filter to only our app's workouts
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyWorkoutBrandName,
            allowedValues: ["RunWalk"]
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    print("Failed to fetch workouts: \(error)")
                    continuation.resume(returning: [])
                    return
                }

                let workouts = (samples as? [HKWorkout]) ?? []
                let stats = workouts.map { workout -> WorkoutStats in
                    WorkoutStats(
                        totalDuration: workout.duration,
                        runIntervals: (workout.metadata?["RunIntervals"] as? Int) ?? 0,
                        walkIntervals: (workout.metadata?["WalkIntervals"] as? Int) ?? 0,
                        startTime: workout.startDate,
                        endTime: workout.endDate
                    )
                }

                continuation.resume(returning: stats)
            }

            healthStore.execute(query)
        }
    }
}
