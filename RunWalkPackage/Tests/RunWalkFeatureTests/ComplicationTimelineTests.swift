import Testing
import Foundation
@testable import RunWalkShared

// MARK: - Complication Timeline Tests

/// Tests for the timeline generation logic used by complications
/// These tests verify the timeline entry generation without requiring WidgetKit
@Suite("Complication Timeline Tests")
struct ComplicationTimelineTests {

    // MARK: - Timeline Entry Generation

    @Test("Idle state generates single timeline entry")
    func idleStateTimelineGeneration() {
        let state = SharedWorkoutState.idle
        let currentDate = Date()

        let entries = generateTimelineEntries(for: state, currentDate: currentDate)

        #expect(entries.count == 1)
        #expect(entries.first?.state.isActive == false)
    }

    @Test("Active workout generates multiple countdown entries")
    func activeWorkoutTimelineGeneration() {
        let currentDate = Date()
        let state = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: 30,
            intervalDuration: 30,
            lastUpdate: currentDate,
            runIntervalSetting: 30,
            walkIntervalSetting: 60
        )

        let entries = generateTimelineEntries(for: state, currentDate: currentDate)

        // Should generate entries for remaining time (up to 60 max)
        #expect(entries.count == 30)

        // First entry should have full time remaining
        #expect(entries.first?.state.timeRemaining == 30)

        // Last entry should have 1 second remaining
        #expect(entries.last?.state.timeRemaining == 1)
    }

    @Test("Active workout with long interval caps at 60 entries")
    func activeWorkoutCapsAt60Entries() {
        let currentDate = Date()
        let state = SharedWorkoutState(
            isActive: true,
            currentPhase: "WALK",
            timeRemaining: 120, // 2 minutes
            intervalDuration: 120,
            lastUpdate: currentDate,
            runIntervalSetting: 30,
            walkIntervalSetting: 120
        )

        let entries = generateTimelineEntries(for: state, currentDate: currentDate)

        // Should cap at 60 entries
        #expect(entries.count == 60)

        // First entry has full time
        #expect(entries.first?.state.timeRemaining == 120)

        // Last entry has 61 seconds remaining (120 - 59)
        #expect(entries.last?.state.timeRemaining == 61)
    }

    @Test("Timeline entries have sequential dates")
    func timelineEntriesHaveSequentialDates() {
        let currentDate = Date()
        let state = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: 10,
            intervalDuration: 30,
            lastUpdate: currentDate,
            runIntervalSetting: 30,
            walkIntervalSetting: 60
        )

        let entries = generateTimelineEntries(for: state, currentDate: currentDate)

        // Verify each entry is 1 second apart
        for i in 1..<entries.count {
            let timeDiff = entries[i].date.timeIntervalSince(entries[i-1].date)
            #expect(timeDiff == 1.0)
        }
    }

    @Test("Timeline entries decrement time remaining correctly")
    func timelineEntriesDecrementTimeRemaining() {
        let currentDate = Date()
        let state = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: 10,
            intervalDuration: 30,
            lastUpdate: currentDate,
            runIntervalSetting: 30,
            walkIntervalSetting: 60
        )

        let entries = generateTimelineEntries(for: state, currentDate: currentDate)

        // Verify time decrements by 1 each entry
        for i in 0..<entries.count {
            #expect(entries[i].state.timeRemaining == 10 - i)
        }
    }

    @Test("Timeline entries preserve phase information")
    func timelineEntriesPreservePhase() {
        let currentDate = Date()
        let runState = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: 5,
            intervalDuration: 30,
            lastUpdate: currentDate,
            runIntervalSetting: 30,
            walkIntervalSetting: 60
        )

        let entries = generateTimelineEntries(for: runState, currentDate: currentDate)

        // All entries should have "RUN" phase
        for entry in entries {
            #expect(entry.state.currentPhase == "RUN")
            #expect(entry.state.isRunPhase == true)
        }
    }

    @Test("Timeline entries preserve interval duration")
    func timelineEntriesPreserveIntervalDuration() {
        let currentDate = Date()
        let state = SharedWorkoutState(
            isActive: true,
            currentPhase: "WALK",
            timeRemaining: 5,
            intervalDuration: 60,
            lastUpdate: currentDate,
            runIntervalSetting: 30,
            walkIntervalSetting: 60
        )

        let entries = generateTimelineEntries(for: state, currentDate: currentDate)

        // All entries should preserve the interval duration for progress calculation
        for entry in entries {
            #expect(entry.state.intervalDuration == 60)
        }
    }

    @Test("Timeline entries time remaining never goes below 0")
    func timelineEntriesNeverNegative() {
        let currentDate = Date()
        let state = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: 3,
            intervalDuration: 30,
            lastUpdate: currentDate,
            runIntervalSetting: 30,
            walkIntervalSetting: 60
        )

        let entries = generateTimelineEntries(for: state, currentDate: currentDate)

        for entry in entries {
            #expect(entry.state.timeRemaining >= 0)
        }
    }

    // MARK: - Refresh Policy Tests

    @Test("Idle state refresh interval is 1 hour")
    func idleStateRefreshInterval() {
        let state = SharedWorkoutState.idle
        let currentDate = Date()

        let refreshDate = calculateRefreshDate(for: state, currentDate: currentDate)

        let expectedRefresh = currentDate.addingTimeInterval(3600)
        #expect(abs(refreshDate.timeIntervalSince(expectedRefresh)) < 0.001)
    }

    @Test("Active state refresh interval matches entry count or minimum 30 seconds")
    func activeStateRefreshInterval() {
        let currentDate = Date()

        // Short interval (10 seconds remaining)
        let shortState = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: 10,
            intervalDuration: 30,
            lastUpdate: currentDate,
            runIntervalSetting: 30,
            walkIntervalSetting: 60
        )
        let shortRefresh = calculateRefreshDate(for: shortState, currentDate: currentDate)
        // Should use minimum of 30 seconds
        let shortExpected = currentDate.addingTimeInterval(30)
        #expect(abs(shortRefresh.timeIntervalSince(shortExpected)) < 0.001)

        // Long interval (45 seconds remaining)
        let longState = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: 45,
            intervalDuration: 60,
            lastUpdate: currentDate,
            runIntervalSetting: 60,
            walkIntervalSetting: 60
        )
        let longRefresh = calculateRefreshDate(for: longState, currentDate: currentDate)
        // Should refresh after 45 seconds
        let longExpected = currentDate.addingTimeInterval(45)
        #expect(abs(longRefresh.timeIntervalSince(longExpected)) < 0.001)
    }

    // MARK: - Progress Calculation Tests

    @Test("Progress updates correctly in timeline entries")
    func progressUpdatesInTimeline() {
        let currentDate = Date()
        let state = SharedWorkoutState(
            isActive: true,
            currentPhase: "RUN",
            timeRemaining: 10,
            intervalDuration: 20,
            lastUpdate: currentDate,
            runIntervalSetting: 20,
            walkIntervalSetting: 60
        )

        let entries = generateTimelineEntries(for: state, currentDate: currentDate)

        // First entry: 10/20 remaining = 0.5 progress
        #expect(entries.first?.state.progress == 0.5)

        // Last entry: 1/20 remaining = 0.95 progress
        #expect(entries.last?.state.progress == 0.95)
    }
}

// MARK: - Timeline Generation Helper

/// Represents a timeline entry (mirrors WidgetKit's TimelineEntry)
struct TestTimelineEntry {
    let date: Date
    let state: SharedWorkoutState
}

/// Generates timeline entries for a given state
/// This mirrors the logic in ComplicationTimelineProvider.getTimeline
func generateTimelineEntries(for state: SharedWorkoutState, currentDate: Date) -> [TestTimelineEntry] {
    if state.isActive {
        var entries: [TestTimelineEntry] = []

        // Generate entries for the next 60 seconds (or until interval ends)
        let entriesToGenerate = min(state.timeRemaining, 60)

        for secondOffset in 0..<entriesToGenerate {
            let entryDate = currentDate.addingTimeInterval(TimeInterval(secondOffset))
            let updatedState = SharedWorkoutState(
                isActive: true,
                currentPhase: state.currentPhase,
                timeRemaining: max(0, state.timeRemaining - secondOffset),
                intervalDuration: state.intervalDuration,
                lastUpdate: entryDate,
                runIntervalSetting: state.runIntervalSetting,
                walkIntervalSetting: state.walkIntervalSetting
            )
            entries.append(TestTimelineEntry(date: entryDate, state: updatedState))
        }

        return entries
    } else {
        // Idle state: single entry
        return [TestTimelineEntry(date: currentDate, state: state)]
    }
}

/// Calculates the refresh date for a timeline
/// This mirrors the logic in ComplicationTimelineProvider.getTimeline
func calculateRefreshDate(for state: SharedWorkoutState, currentDate: Date) -> Date {
    if state.isActive {
        let entriesToGenerate = min(state.timeRemaining, 60)
        return currentDate.addingTimeInterval(TimeInterval(max(entriesToGenerate, 30)))
    } else {
        // Refresh every hour when idle
        return currentDate.addingTimeInterval(3600)
    }
}
