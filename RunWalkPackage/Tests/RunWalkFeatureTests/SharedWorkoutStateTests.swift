import Testing
import Foundation
@testable import RunWalkShared

// MARK: - SharedWorkoutState Tests

@Suite("SharedWorkoutState Tests")
struct SharedWorkoutStateTests {

    // MARK: - Initialization Tests

    @Test("Idle state has correct default values")
    func idleStateDefaults() {
        let idle = SharedWorkoutState.idle

        #expect(idle.isActive == false)
        #expect(idle.currentPhase == "RUN")
        #expect(idle.timeRemaining == 0)
        #expect(idle.intervalDuration == 0)
        #expect(idle.runIntervalSetting == 30)
        #expect(idle.walkIntervalSetting == 60)
    }

    @Test("Custom initialization sets all properties")
    func customInitialization() {
        let date = Date()
        let state = SharedWorkoutState(
            isActive: true,
            currentPhase: "WALK",
            timeRemaining: 45,
            intervalDuration: 60,
            lastUpdate: date,
            runIntervalSetting: 120,
            walkIntervalSetting: 90
        )

        #expect(state.isActive == true)
        #expect(state.currentPhase == "WALK")
        #expect(state.timeRemaining == 45)
        #expect(state.intervalDuration == 60)
        #expect(state.lastUpdate == date)
        #expect(state.runIntervalSetting == 120)
        #expect(state.walkIntervalSetting == 90)
    }

    // MARK: - Codable Tests

    @Test("State encodes and decodes correctly")
    func encodingDecoding() throws {
        let originalDate = Date()
        let original = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: 25,
            intervalDuration: 30,
            lastUpdate: originalDate,
            runIntervalSetting: 30,
            walkIntervalSetting: 60
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SharedWorkoutState.self, from: data)

        #expect(decoded.isActive == original.isActive)
        #expect(decoded.currentPhase == original.currentPhase)
        #expect(decoded.timeRemaining == original.timeRemaining)
        #expect(decoded.intervalDuration == original.intervalDuration)
        #expect(decoded.runIntervalSetting == original.runIntervalSetting)
        #expect(decoded.walkIntervalSetting == original.walkIntervalSetting)
        // Date comparison with some tolerance for encoding precision
        #expect(abs(decoded.lastUpdate.timeIntervalSince(original.lastUpdate)) < 0.001)
    }

    @Test("Idle state encodes and decodes correctly")
    func idleEncodingDecoding() throws {
        let original = SharedWorkoutState.idle

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SharedWorkoutState.self, from: data)

        #expect(decoded.isActive == false)
        #expect(decoded.currentPhase == "RUN")
        #expect(decoded.timeRemaining == 0)
        #expect(decoded.intervalDuration == 0)
    }

    // MARK: - Computed Property Tests

    @Test("Progress calculates correctly")
    func progressCalculation() {
        // 0% progress (just started)
        let startState = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: 30,
            intervalDuration: 30,
            lastUpdate: Date(),
            runIntervalSetting: 30,
            walkIntervalSetting: 60
        )
        #expect(startState.progress == 0.0)

        // 50% progress (halfway)
        let halfwayState = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: 15,
            intervalDuration: 30,
            lastUpdate: Date(),
            runIntervalSetting: 30,
            walkIntervalSetting: 60
        )
        #expect(halfwayState.progress == 0.5)

        // 100% progress (complete)
        let completeState = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: 0,
            intervalDuration: 30,
            lastUpdate: Date(),
            runIntervalSetting: 30,
            walkIntervalSetting: 60
        )
        #expect(completeState.progress == 1.0)
    }

    @Test("Progress returns 0 when interval duration is 0")
    func progressWithZeroDuration() {
        let state = SharedWorkoutState.idle
        #expect(state.progress == 0.0)
    }

    @Test("Formatted time remaining displays correctly")
    func formattedTimeRemaining() {
        // 0 seconds
        let zeroState = SharedWorkoutState(
            isActive: false,
            currentPhase: "RUN",
            timeRemaining: 0,
            intervalDuration: 0,
            lastUpdate: Date(),
            runIntervalSetting: 30,
            walkIntervalSetting: 60
        )
        #expect(zeroState.formattedTimeRemaining == "0:00")

        // 30 seconds
        let thirtySecState = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: 30,
            intervalDuration: 30,
            lastUpdate: Date(),
            runIntervalSetting: 30,
            walkIntervalSetting: 60
        )
        #expect(thirtySecState.formattedTimeRemaining == "0:30")

        // 90 seconds (1:30)
        let ninetySecState = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: 90,
            intervalDuration: 90,
            lastUpdate: Date(),
            runIntervalSetting: 90,
            walkIntervalSetting: 60
        )
        #expect(ninetySecState.formattedTimeRemaining == "1:30")

        // 300 seconds (5:00)
        let fiveMinState = SharedWorkoutState(
            isActive: true,
            currentPhase: "WALK",
            timeRemaining: 300,
            intervalDuration: 300,
            lastUpdate: Date(),
            runIntervalSetting: 30,
            walkIntervalSetting: 300
        )
        #expect(fiveMinState.formattedTimeRemaining == "5:00")

        // 125 seconds (2:05)
        let twoMinFiveState = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: 125,
            intervalDuration: 180,
            lastUpdate: Date(),
            runIntervalSetting: 180,
            walkIntervalSetting: 60
        )
        #expect(twoMinFiveState.formattedTimeRemaining == "2:05")
    }

    @Test("isRunPhase returns correct value")
    func isRunPhaseComputed() {
        let runState = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: 30,
            intervalDuration: 30,
            lastUpdate: Date(),
            runIntervalSetting: 30,
            walkIntervalSetting: 60
        )
        #expect(runState.isRunPhase == true)

        let walkState = SharedWorkoutState(
            isActive: true,
            currentPhase: "WALK",
            timeRemaining: 60,
            intervalDuration: 60,
            lastUpdate: Date(),
            runIntervalSetting: 30,
            walkIntervalSetting: 60
        )
        #expect(walkState.isRunPhase == false)
    }

    // MARK: - Edge Cases

    @Test("Progress handles edge case of negative time remaining")
    func progressWithNegativeTimeRemaining() {
        let state = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: -5, // Edge case
            intervalDuration: 30,
            lastUpdate: Date(),
            runIntervalSetting: 30,
            walkIntervalSetting: 60
        )
        // Progress should be > 1.0 in this edge case
        #expect(state.progress > 1.0)
    }

    @Test("State is Sendable")
    func sendableConformance() async {
        let state = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: 30,
            intervalDuration: 30,
            lastUpdate: Date(),
            runIntervalSetting: 30,
            walkIntervalSetting: 60
        )

        // Pass state across actor boundaries to verify Sendable
        let result = await Task.detached {
            return state.isActive
        }.value

        #expect(result == true)
    }
}
