import Testing
import Foundation
@testable import RunWalkFeature
import RunWalkShared

// MARK: - Mock Clock for Testing

/// A controllable clock for testing time-dependent code
final class MockClock: Clock, @unchecked Sendable {
    private var currentTime: Date
    private let lock = NSLock()

    init(startTime: Date = Date()) {
        self.currentTime = startTime
    }

    func now() -> Date {
        lock.withLock { currentTime }
    }

    /// Advance time by specified seconds
    func advance(by seconds: TimeInterval) {
        lock.withLock {
            currentTime = currentTime.addingTimeInterval(seconds)
        }
    }

    /// Set time to a specific date
    func set(to date: Date) {
        lock.withLock {
            currentTime = date
        }
    }
}

// MARK: - IntervalTimer Tests

@Suite("IntervalTimer Tests")
struct IntervalTimerTests {

    // MARK: - Initial State Tests

    @Test("Initial state is correct")
    @MainActor
    func initialState() {
        let timer = IntervalTimer(enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)

        #expect(timer.currentPhase == .run)
        #expect(timer.timeRemaining == 30) // Default run interval
        #expect(timer.isRunning == false)
        #expect(timer.isActive == false)
        #expect(timer.runInterval == .thirtySeconds)
        #expect(timer.walkInterval == .oneMinute)
    }

    @Test("Formatted time shows correct format")
    @MainActor
    func formattedTime() {
        let timer = IntervalTimer(enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)

        // Default 30 seconds
        #expect(timer.formattedTime == "0:30")

        // Change to 2 minutes
        timer.runInterval = .twoMinutes
        #expect(timer.formattedTime == "2:00")

        // Change to 90 seconds
        timer.runInterval = .ninetySeconds
        #expect(timer.formattedTime == "1:30")
    }

    // MARK: - Start/Stop Tests

    @Test("Start sets running and active state")
    @MainActor
    func startSetsState() {
        let clock = MockClock()
        let timer = IntervalTimer(clock: clock, enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)

        timer.start()

        #expect(timer.isRunning == true)
        #expect(timer.isActive == true)
        #expect(timer.currentPhase == .run)
    }

    @Test("Stop resets all state")
    @MainActor
    func stopResetsState() {
        let clock = MockClock()
        let timer = IntervalTimer(clock: clock, enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)

        timer.start()
        clock.advance(by: 10)
        timer.triggerTick()
        timer.stop()

        #expect(timer.isRunning == false)
        #expect(timer.isActive == false)
        #expect(timer.currentPhase == .run)
        #expect(timer.timeRemaining == timer.runInterval.rawValue)
    }

    // MARK: - Timestamp-Based Calculation Tests

    @Test("Time remaining decreases based on elapsed time")
    @MainActor
    func timeRemainingDecreasesWithElapsedTime() {
        let clock = MockClock()
        let timer = IntervalTimer(clock: clock, enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)
        timer.runInterval = .thirtySeconds // 30 seconds

        timer.start()
        #expect(timer.timeRemaining == 30)

        // Advance 10 seconds
        clock.advance(by: 10)
        timer.triggerTick()
        #expect(timer.timeRemaining == 20)

        // Advance another 5 seconds
        clock.advance(by: 5)
        timer.triggerTick()
        #expect(timer.timeRemaining == 15)
    }

    @Test("Phase switches when interval completes")
    @MainActor
    func phaseSwitchesAtIntervalEnd() {
        let clock = MockClock()
        let timer = IntervalTimer(clock: clock, enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)
        timer.runInterval = .thirtySeconds // 30 seconds
        timer.walkInterval = .oneMinute // 60 seconds

        timer.start()
        #expect(timer.currentPhase == .run)

        // Advance past the 30 second run interval
        clock.advance(by: 31)
        timer.triggerTick()

        #expect(timer.currentPhase == .walk)
        #expect(timer.timeRemaining == 60) // Walk interval duration
    }

    @Test("Multiple phase transitions work correctly")
    @MainActor
    func multiplePhasTransitions() {
        let clock = MockClock()
        let timer = IntervalTimer(clock: clock, enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)
        timer.runInterval = .thirtySeconds // 30 seconds
        timer.walkInterval = .thirtySeconds // 30 seconds for easier testing

        timer.start()
        #expect(timer.currentPhase == .run)

        // Complete run phase
        clock.advance(by: 31)
        timer.triggerTick()
        #expect(timer.currentPhase == .walk)

        // Complete walk phase
        clock.advance(by: 31)
        timer.triggerTick()
        #expect(timer.currentPhase == .run)

        // Complete another run phase
        clock.advance(by: 31)
        timer.triggerTick()
        #expect(timer.currentPhase == .walk)
    }

    // MARK: - Pause/Resume Tests

    @Test("Pause preserves accumulated time")
    @MainActor
    func pausePreservesAccumulatedTime() {
        let clock = MockClock()
        let timer = IntervalTimer(clock: clock, enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)
        timer.runInterval = .thirtySeconds // 30 seconds

        timer.start()

        // Run for 10 seconds then pause
        clock.advance(by: 10)
        timer.triggerTick()
        #expect(timer.timeRemaining == 20)

        timer.pause()
        #expect(timer.isRunning == false)
        #expect(timer.isActive == true) // Still active, just paused

        // Time passes while paused (simulating background)
        clock.advance(by: 100)

        // Resume
        timer.start()
        timer.triggerTick()

        // Should still have ~20 seconds remaining (not affected by time during pause)
        #expect(timer.timeRemaining == 20)
    }

    @Test("Resume continues countdown correctly")
    @MainActor
    func resumeContinuesCountdown() {
        let clock = MockClock()
        let timer = IntervalTimer(clock: clock, enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)
        timer.runInterval = .thirtySeconds

        timer.start()

        // Run for 10 seconds
        clock.advance(by: 10)
        timer.triggerTick()
        #expect(timer.timeRemaining == 20)

        // Pause
        timer.pause()

        // Resume
        timer.start()

        // Run for 15 more seconds (total 25 elapsed)
        clock.advance(by: 15)
        timer.triggerTick()
        #expect(timer.timeRemaining == 5)

        // Complete the interval
        clock.advance(by: 6)
        timer.triggerTick()
        #expect(timer.currentPhase == .walk)
    }

    // MARK: - Background Execution Simulation Tests

    @Test("Timer calculates correctly after long background period")
    @MainActor
    func backgroundExecutionSimulation() {
        let clock = MockClock()
        let timer = IntervalTimer(clock: clock, enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)
        timer.runInterval = .thirtySeconds // 30 seconds
        timer.walkInterval = .oneMinute // 60 seconds

        timer.start()
        #expect(timer.currentPhase == .run)

        // Simulate app going to background for 2 minutes (120 seconds)
        // This should complete: run (30s) -> walk (60s) -> run (30s remaining)
        clock.advance(by: 120)
        timer.triggerTick()

        // After 120 seconds:
        // - Run phase completes at 30s
        // - Walk phase completes at 90s (30 + 60)
        // - New run phase starts at 90s, 30 seconds have passed
        // So we should be back in run phase with 0 seconds (or switched again)

        // Actually let's trace through:
        // Start: run phase, 30s interval
        // At 30s: switch to walk, 60s interval
        // At 90s: switch to run, 30s interval
        // At 120s: switch to walk, 60s interval
        // So after 120s we should be in walk phase
        #expect(timer.currentPhase == .walk)
    }

    @Test("Accurate time calculation after simulated background")
    @MainActor
    func accurateTimeAfterBackground() {
        let clock = MockClock()
        let timer = IntervalTimer(clock: clock, enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)
        timer.runInterval = .oneMinute // 60 seconds

        timer.start()

        // Simulate 45 seconds passing (like phone was in pocket)
        clock.advance(by: 45)
        timer.triggerTick()

        // Should have 15 seconds remaining
        #expect(timer.timeRemaining == 15)
        #expect(timer.currentPhase == .run)
    }

    // MARK: - Edge Cases

    @Test("Tick does nothing when not running")
    @MainActor
    func tickWhenNotRunning() {
        let clock = MockClock()
        let timer = IntervalTimer(clock: clock, enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)

        let initialRemaining = timer.timeRemaining

        clock.advance(by: 10)
        timer.triggerTick()

        #expect(timer.timeRemaining == initialRemaining)
    }

    @Test("Double start has no effect")
    @MainActor
    func doubleStartNoEffect() {
        let clock = MockClock()
        let timer = IntervalTimer(clock: clock, enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)

        timer.start()
        clock.advance(by: 10)
        timer.triggerTick()
        #expect(timer.timeRemaining == 20)

        // Start again (should be ignored)
        timer.start()
        timer.triggerTick()

        // Time should not reset
        #expect(timer.timeRemaining == 20)
    }

    @Test("Pause when not running has no effect")
    @MainActor
    func pauseWhenNotRunningNoEffect() {
        let timer = IntervalTimer(enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)

        timer.pause()

        #expect(timer.isRunning == false)
        #expect(timer.isActive == false)
    }

    @Test("Changing interval while not active updates time remaining")
    @MainActor
    func changingIntervalUpdatesTimeRemaining() {
        let timer = IntervalTimer(enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)

        #expect(timer.timeRemaining == 30) // Default

        timer.runInterval = .twoMinutes
        #expect(timer.timeRemaining == 120)

        timer.runInterval = .fiveMinutes
        #expect(timer.timeRemaining == 300)
    }

    @Test("Changing interval while active recalculates time remaining")
    @MainActor
    func changingIntervalWhileActiveRecalculates() {
        let clock = MockClock()
        let timer = IntervalTimer(clock: clock, enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)

        timer.start()
        clock.advance(by: 10)
        timer.triggerTick()
        #expect(timer.timeRemaining == 20)

        // Change interval while active to 5 minutes (300 seconds)
        timer.runInterval = .fiveMinutes

        // Time remaining recalculates: 300 - 10 = 290 seconds
        // This is intentional - user can extend/shorten current interval
        timer.triggerTick()
        #expect(timer.timeRemaining == 290)
    }
}
