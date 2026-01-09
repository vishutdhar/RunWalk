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
        #expect(timer.runIntervalSelection == .preset(.thirtySeconds))
        #expect(timer.walkIntervalSelection == .preset(.oneMinute))
    }

    @Test("Formatted time shows correct format")
    @MainActor
    func formattedTime() {
        let timer = IntervalTimer(enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)

        // Default 30 seconds
        #expect(timer.formattedTime == "0:30")

        // Change to 2 minutes
        timer.runIntervalSelection = .preset(.twoMinutes)
        #expect(timer.formattedTime == "2:00")

        // Change to 90 seconds
        timer.runIntervalSelection = .preset(.ninetySeconds)
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
        #expect(timer.timeRemaining == timer.runIntervalSelection.seconds)
    }

    // MARK: - Timestamp-Based Calculation Tests

    @Test("Time remaining decreases based on elapsed time")
    @MainActor
    func timeRemainingDecreasesWithElapsedTime() {
        let clock = MockClock()
        let timer = IntervalTimer(clock: clock, enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)
        timer.runIntervalSelection = .preset(.thirtySeconds) // 30 seconds

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
        timer.runIntervalSelection = .preset(.thirtySeconds) // 30 seconds
        timer.walkIntervalSelection = .preset(.oneMinute) // 60 seconds

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
        timer.runIntervalSelection = .preset(.thirtySeconds) // 30 seconds
        timer.walkIntervalSelection = .preset(.thirtySeconds) // 30 seconds for easier testing

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
        timer.runIntervalSelection = .preset(.thirtySeconds) // 30 seconds

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
        timer.runIntervalSelection = .preset(.thirtySeconds)

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
        timer.runIntervalSelection = .preset(.thirtySeconds) // 30 seconds
        timer.walkIntervalSelection = .preset(.oneMinute) // 60 seconds

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
        timer.runIntervalSelection = .preset(.oneMinute) // 60 seconds

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

        timer.runIntervalSelection = .preset(.twoMinutes)
        #expect(timer.timeRemaining == 120)

        timer.runIntervalSelection = .preset(.fiveMinutes)
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
        timer.runIntervalSelection = .preset(.fiveMinutes)

        // Time remaining recalculates: 300 - 10 = 290 seconds
        // This is intentional - user can extend/shorten current interval
        timer.triggerTick()
        #expect(timer.timeRemaining == 290)
    }

    // MARK: - Custom Interval Tests

    @Test("Custom interval works correctly")
    @MainActor
    func customIntervalWorks() {
        let clock = MockClock()
        let timer = IntervalTimer(clock: clock, enableAudio: false, enableDispatchTimer: false, enableHealthKit: false)

        // Set a custom 90-second interval (not a preset)
        timer.runIntervalSelection = .custom(seconds: 90)
        #expect(timer.timeRemaining == 90)
        #expect(timer.runIntervalSelection.isCustom == true)
        #expect(timer.runIntervalSelection.seconds == 90)

        timer.start()

        // Advance 60 seconds
        clock.advance(by: 60)
        timer.triggerTick()
        #expect(timer.timeRemaining == 30)

        // Complete the interval
        clock.advance(by: 31)
        timer.triggerTick()
        #expect(timer.currentPhase == .walk)
    }

    @Test("Custom interval display names are correct")
    @MainActor
    func customIntervalDisplayNames() {
        // Test various custom intervals
        let interval30s = IntervalSelection.custom(seconds: 30)
        #expect(interval30s.displayName == "30 sec")
        #expect(interval30s.shortName == "30s")

        let interval90s = IntervalSelection.custom(seconds: 90)
        #expect(interval90s.displayName == "1m 30s")
        #expect(interval90s.shortName == "1:30")

        let interval5m = IntervalSelection.custom(seconds: 300)
        #expect(interval5m.displayName == "5 min")
        #expect(interval5m.shortName == "5m")

        let interval2m45s = IntervalSelection.custom(seconds: 165)
        #expect(interval2m45s.displayName == "2m 45s")
        #expect(interval2m45s.shortName == "2:45")
    }

    @Test("IntervalSelection preset vs custom comparison")
    @MainActor
    func intervalSelectionComparison() {
        let preset30 = IntervalSelection.preset(.thirtySeconds)
        let custom30 = IntervalSelection.custom(seconds: 30)

        // Same seconds but different types
        #expect(preset30.seconds == custom30.seconds)
        #expect(preset30 != custom30)

        #expect(preset30.isPreset == true)
        #expect(preset30.isCustom == false)
        #expect(custom30.isPreset == false)
        #expect(custom30.isCustom == true)

        #expect(preset30.presetDuration == .thirtySeconds)
        #expect(custom30.presetDuration == nil)
    }

    @Test("IntervalSelection clamping works")
    @MainActor
    func intervalSelectionClamping() {
        // Test minimum clamping
        let tooShort = IntervalSelection.customClamped(seconds: 5)
        #expect(tooShort.seconds == 10) // Minimum is 10 seconds

        // Test maximum clamping
        let tooLong = IntervalSelection.customClamped(seconds: 3600)
        #expect(tooLong.seconds == 1800) // Maximum is 30 minutes (1800 seconds)

        // Test valid value passes through
        let valid = IntervalSelection.customClamped(seconds: 90)
        #expect(valid.seconds == 90)
    }

    @Test("IntervalSelection Codable round-trip works")
    @MainActor
    func intervalSelectionCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Test preset encoding/decoding
        let preset = IntervalSelection.preset(.twoMinutes)
        let presetData = try encoder.encode(preset)
        let decodedPreset = try decoder.decode(IntervalSelection.self, from: presetData)
        #expect(decodedPreset == preset)
        #expect(decodedPreset.seconds == 120)

        // Test custom encoding/decoding
        let custom = IntervalSelection.custom(seconds: 90)
        let customData = try encoder.encode(custom)
        let decodedCustom = try decoder.decode(IntervalSelection.self, from: customData)
        #expect(decodedCustom == custom)
        #expect(decodedCustom.seconds == 90)
        #expect(decodedCustom.isCustom == true)
    }

    @Test("IntervalSelection RawRepresentable works for AppStorage")
    @MainActor
    func intervalSelectionRawRepresentable() {
        // Test preset round-trip via rawValue (String)
        let preset = IntervalSelection.preset(.fiveMinutes)
        let presetRaw = preset.rawValue
        let decodedPreset = IntervalSelection(rawValue: presetRaw)
        #expect(decodedPreset == preset)

        // Test custom round-trip via rawValue
        let custom = IntervalSelection.custom(seconds: 165)
        let customRaw = custom.rawValue
        let decodedCustom = IntervalSelection(rawValue: customRaw)
        #expect(decodedCustom == custom)
        #expect(decodedCustom?.seconds == 165)
    }
}
