import SwiftUI
import Observation
import CoreLocation
import RunWalkShared

/// Watch-specific interval timer that coordinates with HKWorkoutSession and haptics
/// Uses timestamp-based calculation for reliable background execution
@Observable
@MainActor
public final class WatchIntervalTimer {
    // MARK: - Published State

    /// Current phase (run or walk)
    public private(set) var currentPhase: TimerPhase = .run

    /// Time remaining in current interval (in seconds)
    public private(set) var timeRemaining: Int = 30

    /// Whether the timer is currently running (ticking)
    /// Uses our own timer state, not HKWorkoutSession (which may not work on simulator)
    public private(set) var isRunning: Bool = false

    /// Whether a session is active (started but not cancelled)
    public private(set) var isActive: Bool = false

    /// Total elapsed time for the entire workout
    public private(set) var totalElapsedTime: TimeInterval = 0

    /// Workout statistics for summary
    public private(set) var workoutStats = WorkoutStats()

    /// Whether to show the workout summary
    public private(set) var showSummary: Bool = false

    /// Whether we're in the 3-2-1 countdown before workout starts
    public private(set) var isCountingDown: Bool = false

    /// Current countdown value (3, 2, 1)
    public private(set) var countdownValue: Int = 3

    /// Selected interval for RUN phase (preset or custom)
    public var runIntervalSelection: IntervalSelection = .preset(.thirtySeconds) {
        didSet {
            if !isActive && currentPhase == .run {
                timeRemaining = runIntervalSelection.seconds
            }
        }
    }

    /// Selected interval for WALK phase (preset or custom)
    public var walkIntervalSelection: IntervalSelection = .preset(.oneMinute) {
        didSet {
            if !isActive && currentPhase == .walk {
                timeRemaining = walkIntervalSelection.seconds
            }
        }
    }

    /// Returns the interval selection for the current phase
    public var currentIntervalSelection: IntervalSelection {
        currentPhase == .run ? runIntervalSelection : walkIntervalSelection
    }

    /// Returns the current interval duration in seconds
    public var currentIntervalSeconds: Int {
        currentIntervalSelection.seconds
    }

    // MARK: - Legacy Accessors (for backward compatibility)

    /// Legacy accessor for run interval - returns the selection's seconds
    public var runInterval: Int {
        runIntervalSelection.seconds
    }

    /// Legacy accessor for walk interval - returns the selection's seconds
    public var walkInterval: Int {
        walkIntervalSelection.seconds
    }

    /// Active calories from HealthKit
    public var activeCalories: Double {
        workoutManager.activeCalories
    }

    /// Heart rate from HealthKit
    public var heartRate: Double {
        workoutManager.heartRate
    }

    // MARK: - Private Properties

    private var timer: Timer?
    private var phaseStartTime: Date?
    private var accumulatedTimeBeforePause: TimeInterval = 0
    private var workoutStartTime: Date?
    private var totalTimeBeforePause: TimeInterval = 0
    private var previousTimeRemaining: Int = 0

    private let clock: Clock
    private let workoutManager: WatchWorkoutManager
    private let hapticManager: WatchHapticManager
    private let voiceManager: WatchVoiceAnnouncementManager
    private let stateManager = SharedWorkoutStateManager.shared

    /// Whether voice announcements are enabled (set from UI)
    public var voiceAnnouncementsEnabled: Bool = false {
        didSet {
            voiceManager.isEnabled = voiceAnnouncementsEnabled
        }
    }

    /// Whether bell sounds are enabled (set from UI)
    /// On watchOS, bells and haptics are played together via WKInterfaceDevice
    public var bellsEnabled: Bool = true {
        didSet {
            hapticManager.bellsEnabled = bellsEnabled
        }
    }

    /// Whether haptic feedback is enabled (set from UI)
    /// On watchOS, bells and haptics are played together via WKInterfaceDevice
    public var hapticsEnabled: Bool = true {
        didSet {
            hapticManager.hapticsEnabled = hapticsEnabled
        }
    }

    /// Whether GPS tracking is enabled (set from UI)
    public var gpsTrackingEnabled: Bool = false {
        didSet {
            locationManager?.accuracyMode = gpsAccuracyMode
        }
    }

    /// GPS accuracy mode (set from UI)
    public var gpsAccuracyMode: GPSAccuracyMode = .balanced {
        didSet {
            locationManager?.accuracyMode = gpsAccuracyMode
        }
    }

    /// Current route data (for live map display during workout)
    public var currentRouteData: RouteData {
        locationManager?.routeData ?? RouteData()
    }

    /// Current location (for live map centering)
    public var currentLocation: CLLocation? {
        locationManager?.currentLocation
    }

    // MARK: - Location Manager

    private var locationManager: WatchLocationManager?

    // MARK: - Initialization

    public init(
        clock: Clock = SystemClock(),
        workoutManager: WatchWorkoutManager = WatchWorkoutManager(),
        hapticManager: WatchHapticManager = WatchHapticManager(),
        voiceManager: WatchVoiceAnnouncementManager = WatchVoiceAnnouncementManager()
    ) {
        self.clock = clock
        self.workoutManager = workoutManager
        self.hapticManager = hapticManager
        self.voiceManager = voiceManager
        timeRemaining = runIntervalSelection.seconds
    }

    // MARK: - HealthKit

    /// Whether HealthKit is available
    public var isHealthKitAvailable: Bool {
        workoutManager.isHealthKitAvailable
    }

    /// Request HealthKit authorization
    public func requestHealthKitAuthorization() async -> Bool {
        await workoutManager.requestAuthorization()
    }

    // MARK: - Timer Controls

    /// Starts the timer (with 3-2-1 countdown on first start)
    public func start() {
        guard !isRunning, !isCountingDown else { return }

        let isFirstStart = !isActive

        if isFirstStart {
            isCountingDown = true
            countdownValue = 3
            showSummary = false

            Task { @MainActor in
                await playStartCountdown()
                guard isCountingDown else { return }
                await beginWorkout()
            }
        } else {
            resumeWorkout()
        }
    }

    /// Plays the 3-2-1 countdown with haptics
    private func playStartCountdown() async {
        for i in [3, 2, 1] {
            guard isCountingDown else { return }
            countdownValue = i
            hapticManager.playCountdownTick()
            try? await Task.sleep(for: .seconds(1.0))
        }
    }

    /// Begins the workout after countdown
    private func beginWorkout() async {
        isCountingDown = false

        // Start the HKWorkoutSession (critical for background)
        await workoutManager.startWorkout(startDate: clock.now())

        // Initialize timing
        accumulatedTimeBeforePause = 0
        totalTimeBeforePause = 0
        totalElapsedTime = 0
        workoutStartTime = clock.now()
        workoutStats = WorkoutStats()
        workoutStats.startTime = clock.now()
        workoutStats.runIntervals = 1
        workoutStats.gpsTrackingEnabled = gpsTrackingEnabled
        previousTimeRemaining = runIntervalSelection.seconds

        phaseStartTime = clock.now()

        // Start GPS tracking if enabled
        if gpsTrackingEnabled {
            await startGPSTracking()
        }

        // Play RUN haptic and voice
        hapticManager.playPhaseTransition(to: currentPhase)
        voiceManager.announce(phase: currentPhase)

        startTimer()
    }

    /// Starts GPS tracking for the workout
    private func startGPSTracking() async {
        locationManager = WatchLocationManager()
        locationManager?.accuracyMode = gpsAccuracyMode

        let authorized = await locationManager?.requestAuthorization() ?? false
        if authorized {
            locationManager?.startTracking()
        }
    }

    /// Resumes from pause
    private func resumeWorkout() {
        workoutManager.resumeWorkout()
        phaseStartTime = clock.now()
        startTimer()
    }

    /// Creates and starts the Timer
    private func startTimer() {
        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }

        isRunning = true
        isActive = true

        // Sync initial state to widget
        syncStateToWidget()
    }

    /// Pauses the timer
    public func pause() {
        guard isRunning else { return }

        if let startTime = phaseStartTime {
            accumulatedTimeBeforePause += clock.now().timeIntervalSince(startTime)
        }

        if workoutStartTime != nil {
            totalTimeBeforePause = totalElapsedTime
        }

        workoutManager.pauseWorkout()
        timer?.invalidate()
        timer = nil
        phaseStartTime = nil
        isRunning = false
    }

    /// Stops and ends the workout
    public func stop() {
        let wasCounting = isCountingDown
        let wasActive = isActive
        isCountingDown = false

        // Stop GPS tracking and capture route data
        if let locManager = locationManager, gpsTrackingEnabled {
            locManager.stopTracking()
            workoutStats.routeData = locManager.routeData
            workoutStats.totalDistance = locManager.routeData.totalDistanceMeters
        }

        if wasActive && !wasCounting {
            workoutStats.endTime = clock.now()
            workoutStats.totalDuration = totalElapsedTime
            showSummary = true

            hapticManager.playWorkoutComplete()

            // End workout and save to HealthKit
            Task {
                await workoutManager.endWorkout()
            }
        } else {
            workoutManager.discardWorkout()
        }

        timer?.invalidate()
        timer = nil
        phaseStartTime = nil
        accumulatedTimeBeforePause = 0
        totalTimeBeforePause = 0
        workoutStartTime = nil
        locationManager = nil  // Release location manager
        currentPhase = .run
        timeRemaining = runIntervalSelection.seconds
        isRunning = false
        isActive = false

        // Clear widget state so it shows idle
        clearWidgetState()
    }

    /// Dismisses the workout summary
    public func dismissSummary() {
        showSummary = false
        workoutStats = WorkoutStats()
        totalElapsedTime = 0
    }

    // MARK: - Private Methods

    private func tick() {
        guard isRunning, let startTime = phaseStartTime else { return }

        let elapsedSinceStart = clock.now().timeIntervalSince(startTime)
        let totalElapsed = accumulatedTimeBeforePause + elapsedSinceStart

        // Update total workout time
        if let workoutStart = workoutStartTime {
            if totalTimeBeforePause > 0 {
                totalElapsedTime = totalTimeBeforePause + elapsedSinceStart
            } else {
                totalElapsedTime = clock.now().timeIntervalSince(workoutStart)
            }
        }

        let intervalDuration = TimeInterval(currentIntervalSeconds)
        let remaining = intervalDuration - totalElapsed

        if remaining <= 0 {
            switchPhase()
        } else {
            let newTimeRemaining = Int(ceil(remaining))

            // Haptic warning at 3, 2, 1 seconds
            if newTimeRemaining <= 3 && newTimeRemaining < previousTimeRemaining && newTimeRemaining > 0 {
                hapticManager.playIntervalWarning(secondsRemaining: newTimeRemaining)
            }

            previousTimeRemaining = newTimeRemaining
            timeRemaining = newTimeRemaining

            // Sync state to widget for live updates
            syncStateToWidget()
        }
    }

    /// Switches between run and walk phases
    private func switchPhase() {
        currentPhase = currentPhase.next

        if currentPhase == .run {
            workoutStats.runIntervals += 1
        } else {
            workoutStats.walkIntervals += 1
        }

        phaseStartTime = clock.now()
        accumulatedTimeBeforePause = 0
        timeRemaining = currentIntervalSeconds
        previousTimeRemaining = currentIntervalSeconds

        // Play phase transition haptic and voice
        hapticManager.playPhaseTransition(to: currentPhase)
        voiceManager.announce(phase: currentPhase)

        // Sync new phase to widget
        syncStateToWidget()
    }

    // MARK: - Computed Properties

    /// Formatted time string (MM:SS)
    public var formattedTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formatted total elapsed workout time (MM:SS)
    public var formattedElapsedTime: String {
        let totalSeconds = Int(totalElapsedTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Widget State Sync

    /// Syncs current workout state to shared storage for widget complications
    private func syncStateToWidget() {
        let state = SharedWorkoutState(
            isActive: isActive,
            currentPhase: currentPhase.rawValue,
            timeRemaining: timeRemaining,
            intervalDuration: currentIntervalSeconds,
            lastUpdate: clock.now(),
            runIntervalSetting: runIntervalSelection.seconds,
            walkIntervalSetting: walkIntervalSelection.seconds
        )
        stateManager.writeState(state)
    }

    /// Clears widget state when workout ends
    private func clearWidgetState() {
        stateManager.clearState()
    }
}
