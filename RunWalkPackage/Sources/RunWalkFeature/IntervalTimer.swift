import SwiftUI
import Observation
import Dispatch
import CoreLocation
import RunWalkShared

// Re-export shared types for convenience
public typealias TimerPhase = RunWalkShared.TimerPhase
public typealias IntervalDuration = RunWalkShared.IntervalDuration
public typealias IntervalSelection = RunWalkShared.IntervalSelection
public typealias WorkoutStats = RunWalkShared.WorkoutStats
public typealias Clock = RunWalkShared.Clock
public typealias SystemClock = RunWalkShared.SystemClock
public typealias WorkoutRecord = RunWalkShared.WorkoutRecord

/// Main timer model that handles the interval timing logic
/// Uses timestamp-based calculation for reliable background execution
@Observable
@MainActor
public final class IntervalTimer {
    // MARK: - Published State

    /// Current phase (run or walk)
    public private(set) var currentPhase: TimerPhase = .run

    /// Time remaining in current interval (in seconds)
    /// This is now calculated from timestamps, not decremented
    public private(set) var timeRemaining: Int = 30

    /// Whether the timer is currently running (ticking)
    public private(set) var isRunning: Bool = false

    /// Whether a session is active (started but not cancelled)
    /// This stays true even when paused
    public private(set) var isActive: Bool = false

    /// Total elapsed time for the entire workout
    public private(set) var totalElapsedTime: TimeInterval = 0

    /// Workout statistics for summary
    public private(set) var workoutStats = WorkoutStats()

    /// Whether to show the workout summary (set when workout ends)
    public private(set) var showSummary: Bool = false

    /// Whether the last workout was saved to HealthKit
    public private(set) var workoutSavedToHealth: Bool = false

    /// Whether we're in the 3-2-1 countdown before workout starts
    public private(set) var isCountingDown: Bool = false

    /// Current countdown value (3, 2, 1) during pre-workout countdown
    public private(set) var countdownValue: Int = 3

    /// Previous timeRemaining for countdown detection
    private var previousTimeRemaining: Int = 0

    /// Selected interval for RUN phase (preset or custom)
    public var runIntervalSelection: IntervalSelection = .preset(.thirtySeconds) {
        didSet {
            // Reset timer when interval changes (only if not active and on run phase)
            if !isActive && currentPhase == .run {
                timeRemaining = runIntervalSelection.seconds
            }
        }
    }

    /// Selected interval for WALK phase (preset or custom)
    public var walkIntervalSelection: IntervalSelection = .preset(.oneMinute) {
        didSet {
            // Reset timer when interval changes (only if not active and on walk phase)
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

    // MARK: - Private Properties

    /// Timer for updating the countdown
    private var timer: Timer?

    /// When the current phase started (used for timestamp-based calculation)
    private var phaseStartTime: Date?

    /// Accumulated time from before pause (handles pause/resume correctly)
    private var accumulatedTimeBeforePause: TimeInterval = 0

    /// When the entire workout started
    private var workoutStartTime: Date?

    /// Total time accumulated before pauses (for total elapsed time)
    private var totalTimeBeforePause: TimeInterval = 0

    private let soundManager: SoundManager?
    private let healthKitManager: HealthKitManager?
    private let voiceManager: VoiceAnnouncementManager?

    /// Clock for getting current time - injectable for testing
    private let clock: Clock

    /// Whether to use the automatic dispatch timer (disabled for unit tests)
    private let enableDispatchTimer: Bool

    /// Whether voice announcements are enabled (set from UI)
    public var voiceAnnouncementsEnabled: Bool = false {
        didSet {
            voiceManager?.isEnabled = voiceAnnouncementsEnabled
        }
    }

    /// Whether bell sounds are enabled (set from UI)
    public var bellsEnabled: Bool = true {
        didSet {
            soundManager?.bellsEnabled = bellsEnabled
        }
    }

    /// Whether haptic feedback is enabled (set from UI)
    public var hapticsEnabled: Bool = true {
        didSet {
            soundManager?.hapticsEnabled = hapticsEnabled
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

    private var locationManager: iOSLocationManager?

    // MARK: - Initialization

    /// Creates an IntervalTimer
    /// - Parameter clock: Clock for getting current time (default: SystemClock)
    /// - Parameter enableAudio: Whether to enable audio managers (set false for testing)
    /// - Parameter enableDispatchTimer: Whether to enable automatic tick timer (set false for unit tests)
    /// - Parameter enableHealthKit: Whether to enable HealthKit integration (set false for testing)
    public init(clock: Clock = SystemClock(), enableAudio: Bool = true, enableDispatchTimer: Bool = true, enableHealthKit: Bool = true) {
        self.clock = clock
        self.soundManager = enableAudio ? SoundManager() : nil
        self.healthKitManager = enableHealthKit ? HealthKitManager() : nil
        self.voiceManager = enableAudio ? VoiceAnnouncementManager() : nil
        self.enableDispatchTimer = enableDispatchTimer
        timeRemaining = runIntervalSelection.seconds
    }

    // MARK: - Timer Controls

    /// Starts or resumes the timer
    public func start() {
        guard !isRunning, !isCountingDown else { return }

        let isFirstStart = !isActive

        // Play 3-2-1 countdown only on first start, not on resume from pause
        if isFirstStart {
            isCountingDown = true
            countdownValue = 3
            showSummary = false

            // Start countdown in a task - when complete, begin workout
            Task { @MainActor in
                await playStartCountdown()
                guard isCountingDown else { return }  // Check if cancelled during countdown
                beginWorkout()
            }
        } else {
            // Resume from pause - no countdown needed
            resumeWorkout()
        }
    }

    /// Plays the 3-2-1 countdown with UI updates
    private func playStartCountdown() async {
        // Play 3... 2... 1... with UI updates
        for i in [3, 2, 1] {
            guard isCountingDown else { return }  // Cancelled
            countdownValue = i
            soundManager?.playCountdownBeep(index: 3 - i)
            try? await Task.sleep(for: .seconds(1.0))
        }
    }

    /// Actually begins the workout after countdown
    private func beginWorkout() {
        isCountingDown = false
        isRunning = true
        isActive = true

        // Fresh start - reset everything
        accumulatedTimeBeforePause = 0
        totalTimeBeforePause = 0
        totalElapsedTime = 0
        workoutStartTime = clock.now()
        workoutStats = WorkoutStats()
        workoutStats.startTime = clock.now()
        workoutStats.runIntervals = 1  // Starting with first run interval
        workoutStats.gpsTrackingEnabled = gpsTrackingEnabled
        previousTimeRemaining = runIntervalSelection.seconds

        // Record when this phase segment started
        phaseStartTime = clock.now()

        // Start GPS tracking if enabled
        if gpsTrackingEnabled {
            startGPSTracking()
        }

        // Play the RUN tone to signal workout has started
        soundManager?.playSound(for: currentPhase)
        voiceManager?.announce(phase: currentPhase)

        // Create Timer for countdown updates
        // (Disabled in unit tests where we manually call triggerTick)
        if enableDispatchTimer {
            startTimer()
        }
    }

    /// Starts GPS tracking for the workout
    private func startGPSTracking() {
        locationManager = iOSLocationManager()
        locationManager?.accuracyMode = gpsAccuracyMode

        // Request authorization and start tracking
        Task { @MainActor in
            let authorized = await locationManager?.requestAuthorization() ?? false
            if authorized {
                locationManager?.startTracking()
            }
        }
    }

    /// Resumes workout from pause (no countdown)
    private func resumeWorkout() {
        isRunning = true
        showSummary = false

        // Record when this phase segment started
        phaseStartTime = clock.now()

        // Create Timer for countdown updates
        if enableDispatchTimer {
            startTimer()
        }
    }

    /// Creates and starts the Timer on the main RunLoop
    private func startTimer() {
        // Cancel any existing timer
        timer?.invalidate()

        // Create a standard Timer on the main run loop
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        // Allow timer to fire even during scrolling/tracking
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Pauses the timer
    public func pause() {
        guard isRunning else { return }

        // Save accumulated time before pausing
        if let startTime = phaseStartTime {
            accumulatedTimeBeforePause += clock.now().timeIntervalSince(startTime)
        }

        // Save total elapsed time before pausing
        if workoutStartTime != nil {
            totalTimeBeforePause = totalElapsedTime
        }

        isRunning = false
        timer?.invalidate()
        timer = nil
        phaseStartTime = nil
    }

    /// Stops and resets the timer (cancels the session)
    /// Shows workout summary with stats and saves workout to HealthKit
    public func stop() {
        // If cancelled during countdown, just reset (no summary)
        let wasCounting = isCountingDown
        isCountingDown = false

        // Stop GPS tracking and capture route data
        if let locManager = locationManager, gpsTrackingEnabled {
            locManager.stopTracking()
            workoutStats.routeData = locManager.routeData
            workoutStats.totalDistance = locManager.routeData.totalDistanceMeters
        }

        // Finalize workout stats before resetting (only if workout actually started)
        if isActive && !wasCounting {
            workoutStats.endTime = clock.now()
            workoutStats.totalDuration = totalElapsedTime
            showSummary = true

            // Save workout to HealthKit in background
            let statsToSave = workoutStats
            Task {
                workoutSavedToHealth = await healthKitManager?.saveWorkout(stats: statsToSave) ?? false
            }
        }

        isRunning = false
        timer?.invalidate()
        timer = nil
        phaseStartTime = nil
        accumulatedTimeBeforePause = 0
        totalTimeBeforePause = 0
        workoutStartTime = nil
        locationManager = nil  // Release location manager

        isActive = false
        currentPhase = .run
        timeRemaining = runIntervalSelection.seconds
    }

    /// Dismisses the workout summary and resets stats
    public func dismissSummary() {
        showSummary = false
        workoutStats = WorkoutStats()
        totalElapsedTime = 0
        workoutSavedToHealth = false
    }

    // MARK: - HealthKit

    /// Whether HealthKit is available on this device
    public var isHealthKitAvailable: Bool {
        healthKitManager?.isAvailable ?? false
    }

    /// Whether the user has authorized HealthKit access
    public var isHealthKitAuthorized: Bool {
        healthKitManager?.isAuthorized ?? false
    }

    /// Requests HealthKit authorization from the user
    public func requestHealthKitAuthorization() async {
        await healthKitManager?.requestAuthorization()
    }

    // MARK: - Private Methods

    /// Called every second to update the timer
    /// Uses timestamp-based calculation for accuracy even after background execution
    private func tick() {
        guard isRunning, let startTime = phaseStartTime else { return }

        // Calculate elapsed time from timestamps (reliable even in background)
        let elapsedSinceStart = clock.now().timeIntervalSince(startTime)
        let totalElapsed = accumulatedTimeBeforePause + elapsedSinceStart

        // Update total workout elapsed time
        if let workoutStart = workoutStartTime {
            totalElapsedTime = totalTimeBeforePause + clock.now().timeIntervalSince(workoutStart) - totalTimeBeforePause
            // Simplified: just track from pause resume point
            if totalTimeBeforePause > 0 {
                totalElapsedTime = totalTimeBeforePause + elapsedSinceStart
            } else {
                totalElapsedTime = clock.now().timeIntervalSince(workoutStart)
            }
        }

        let intervalDuration = TimeInterval(currentIntervalSeconds)
        let remaining = intervalDuration - totalElapsed

        if remaining <= 0 {
            // Phase complete - switch to next phase
            switchPhase()
        } else {
            // Update remaining time (ceiling to show "1" until it actually hits 0)
            let newTimeRemaining = Int(ceil(remaining))

            // Play countdown tick (audio beep + haptic) at 3, 2, 1 seconds
            if newTimeRemaining <= 3 && newTimeRemaining < previousTimeRemaining && newTimeRemaining > 0 {
                soundManager?.playCountdownTick(secondsRemaining: newTimeRemaining)
            }

            previousTimeRemaining = newTimeRemaining
            timeRemaining = newTimeRemaining
        }
    }

    /// Manually trigger a tick - exposed for testing
    public func triggerTick() {
        tick()
    }

    /// Switches between run and walk phases
    private func switchPhase() {
        currentPhase = currentPhase.next

        // Track interval counts
        if currentPhase == .run {
            workoutStats.runIntervals += 1
        } else {
            workoutStats.walkIntervals += 1
        }

        // Reset timing for new phase
        phaseStartTime = clock.now()
        accumulatedTimeBeforePause = 0
        timeRemaining = currentIntervalSeconds
        previousTimeRemaining = currentIntervalSeconds

        // Play sound and voice for new phase
        soundManager?.playSound(for: currentPhase)
        voiceManager?.announce(phase: currentPhase)
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
}
