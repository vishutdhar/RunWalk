import Testing
import Foundation
@testable import RunWalkShared

// MARK: - HeartRateZone Tests

@Suite("HeartRateZone Tests")
struct HeartRateZoneTests {

    // MARK: - Zone Properties Tests

    @Test("Zone 1 has correct properties")
    func zone1Properties() {
        let zone = HeartRateZone.zone1

        #expect(zone.rawValue == 1)
        #expect(zone.name == "Zone 1")
        #expect(zone.description == "Recovery")
        #expect(zone.percentageRange == "50-60%")
        #expect(zone.lowerBound == 0.50)
        #expect(zone.upperBound == 0.60)
    }

    @Test("Zone 2 has correct properties")
    func zone2Properties() {
        let zone = HeartRateZone.zone2

        #expect(zone.rawValue == 2)
        #expect(zone.name == "Zone 2")
        #expect(zone.description == "Fat Burn")
        #expect(zone.percentageRange == "60-70%")
        #expect(zone.lowerBound == 0.60)
        #expect(zone.upperBound == 0.70)
    }

    @Test("Zone 3 has correct properties")
    func zone3Properties() {
        let zone = HeartRateZone.zone3

        #expect(zone.rawValue == 3)
        #expect(zone.name == "Zone 3")
        #expect(zone.description == "Aerobic")
        #expect(zone.percentageRange == "70-80%")
        #expect(zone.lowerBound == 0.70)
        #expect(zone.upperBound == 0.80)
    }

    @Test("Zone 4 has correct properties")
    func zone4Properties() {
        let zone = HeartRateZone.zone4

        #expect(zone.rawValue == 4)
        #expect(zone.name == "Zone 4")
        #expect(zone.description == "Anaerobic")
        #expect(zone.percentageRange == "80-90%")
        #expect(zone.lowerBound == 0.80)
        #expect(zone.upperBound == 0.90)
    }

    @Test("Zone 5 has correct properties")
    func zone5Properties() {
        let zone = HeartRateZone.zone5

        #expect(zone.rawValue == 5)
        #expect(zone.name == "Zone 5")
        #expect(zone.description == "Max Effort")
        #expect(zone.percentageRange == "90-100%")
        #expect(zone.lowerBound == 0.90)
        #expect(zone.upperBound == 1.00)
    }

    @Test("All zones are iterable via CaseIterable")
    func allCasesIterable() {
        let allZones = HeartRateZone.allCases

        #expect(allZones.count == 5)
        #expect(allZones[0] == .zone1)
        #expect(allZones[1] == .zone2)
        #expect(allZones[2] == .zone3)
        #expect(allZones[3] == .zone4)
        #expect(allZones[4] == .zone5)
    }

    // MARK: - Max Heart Rate Calculation Tests

    @Test("Max HR calculates correctly for various ages")
    func maxHeartRateCalculation() {
        // Standard formula: 220 - age
        #expect(HeartRateZone.maxHeartRate(forAge: 20) == 200)
        #expect(HeartRateZone.maxHeartRate(forAge: 30) == 190)
        #expect(HeartRateZone.maxHeartRate(forAge: 40) == 180)
        #expect(HeartRateZone.maxHeartRate(forAge: 50) == 170)
        #expect(HeartRateZone.maxHeartRate(forAge: 60) == 160)
        #expect(HeartRateZone.maxHeartRate(forAge: 70) == 150)
    }

    @Test("Max HR for edge case ages")
    func maxHeartRateEdgeCases() {
        // Young athlete
        #expect(HeartRateZone.maxHeartRate(forAge: 18) == 202)

        // Senior
        #expect(HeartRateZone.maxHeartRate(forAge: 80) == 140)
    }

    // MARK: - Zone Calculation Tests

    @Test("Zone calculation for 30-year-old (max HR 190)")
    func zoneCalculationAge30() {
        let maxHR = 190.0

        // Zone 1: 50-60% of 190 = 95-114 bpm
        #expect(HeartRateZone.zone(forHeartRate: 95, maxHeartRate: maxHR) == .zone1)
        #expect(HeartRateZone.zone(forHeartRate: 110, maxHeartRate: maxHR) == .zone1)

        // Zone 2: 60-70% of 190 = 114-133 bpm
        #expect(HeartRateZone.zone(forHeartRate: 114, maxHeartRate: maxHR) == .zone2)
        #expect(HeartRateZone.zone(forHeartRate: 125, maxHeartRate: maxHR) == .zone2)

        // Zone 3: 70-80% of 190 = 133-152 bpm
        #expect(HeartRateZone.zone(forHeartRate: 133, maxHeartRate: maxHR) == .zone3)
        #expect(HeartRateZone.zone(forHeartRate: 145, maxHeartRate: maxHR) == .zone3)

        // Zone 4: 80-90% of 190 = 152-171 bpm
        #expect(HeartRateZone.zone(forHeartRate: 152, maxHeartRate: maxHR) == .zone4)
        #expect(HeartRateZone.zone(forHeartRate: 165, maxHeartRate: maxHR) == .zone4)

        // Zone 5: 90-100% of 190 = 171-190 bpm
        #expect(HeartRateZone.zone(forHeartRate: 171, maxHeartRate: maxHR) == .zone5)
        #expect(HeartRateZone.zone(forHeartRate: 185, maxHeartRate: maxHR) == .zone5)
        #expect(HeartRateZone.zone(forHeartRate: 190, maxHeartRate: maxHR) == .zone5)
    }

    @Test("Zone calculation for 50-year-old (max HR 170)")
    func zoneCalculationAge50() {
        let maxHR = 170.0

        // Zone 1: 50-60% of 170 = 85-102 bpm
        #expect(HeartRateZone.zone(forHeartRate: 90, maxHeartRate: maxHR) == .zone1)

        // Zone 2: 60-70% of 170 = 102-119 bpm
        #expect(HeartRateZone.zone(forHeartRate: 110, maxHeartRate: maxHR) == .zone2)

        // Zone 3: 70-80% of 170 = 119-136 bpm
        #expect(HeartRateZone.zone(forHeartRate: 125, maxHeartRate: maxHR) == .zone3)

        // Zone 4: 80-90% of 170 = 136-153 bpm
        #expect(HeartRateZone.zone(forHeartRate: 145, maxHeartRate: maxHR) == .zone4)

        // Zone 5: 90-100% of 170 = 153-170 bpm
        #expect(HeartRateZone.zone(forHeartRate: 160, maxHeartRate: maxHR) == .zone5)
    }

    @Test("Zone returns nil for heart rate below Zone 1 threshold")
    func zoneBelowThreshold() {
        let maxHR = 190.0

        // Below 50% (95 bpm for max HR 190)
        #expect(HeartRateZone.zone(forHeartRate: 80, maxHeartRate: maxHR) == nil)
        #expect(HeartRateZone.zone(forHeartRate: 50, maxHeartRate: maxHR) == nil)
        #expect(HeartRateZone.zone(forHeartRate: 94, maxHeartRate: maxHR) == nil)
    }

    @Test("Zone 5 handles heart rates above max HR")
    func zoneAboveMaxHR() {
        let maxHR = 190.0

        // Heart rate above 100% of max HR should still be Zone 5
        #expect(HeartRateZone.zone(forHeartRate: 195, maxHeartRate: maxHR) == .zone5)
        #expect(HeartRateZone.zone(forHeartRate: 200, maxHeartRate: maxHR) == .zone5)
        #expect(HeartRateZone.zone(forHeartRate: 210, maxHeartRate: maxHR) == .zone5)
    }

    @Test("Zone returns nil for invalid inputs")
    func zoneInvalidInputs() {
        // Zero heart rate
        #expect(HeartRateZone.zone(forHeartRate: 0, maxHeartRate: 190) == nil)

        // Zero max HR
        #expect(HeartRateZone.zone(forHeartRate: 150, maxHeartRate: 0) == nil)

        // Negative heart rate
        #expect(HeartRateZone.zone(forHeartRate: -10, maxHeartRate: 190) == nil)

        // Negative max HR
        #expect(HeartRateZone.zone(forHeartRate: 150, maxHeartRate: -190) == nil)
    }

    // MARK: - Zone Boundary Tests

    @Test("Zone boundaries are correctly calculated")
    func zoneBoundaryTests() {
        let maxHR = 200.0

        // Exact boundary: 50% = 100 bpm (start of Zone 1)
        #expect(HeartRateZone.zone(forHeartRate: 100, maxHeartRate: maxHR) == .zone1)

        // Just below 50% = 99.9 bpm (no zone)
        #expect(HeartRateZone.zone(forHeartRate: 99, maxHeartRate: maxHR) == nil)

        // Exact boundary: 60% = 120 bpm (start of Zone 2)
        #expect(HeartRateZone.zone(forHeartRate: 120, maxHeartRate: maxHR) == .zone2)

        // Exact boundary: 70% = 140 bpm (start of Zone 3)
        #expect(HeartRateZone.zone(forHeartRate: 140, maxHeartRate: maxHR) == .zone3)

        // Exact boundary: 80% = 160 bpm (start of Zone 4)
        #expect(HeartRateZone.zone(forHeartRate: 160, maxHeartRate: maxHR) == .zone4)

        // Exact boundary: 90% = 180 bpm (start of Zone 5)
        #expect(HeartRateZone.zone(forHeartRate: 180, maxHeartRate: maxHR) == .zone5)

        // Exact boundary: 100% = 200 bpm (still Zone 5)
        #expect(HeartRateZone.zone(forHeartRate: 200, maxHeartRate: maxHR) == .zone5)
    }

    // MARK: - Heart Rate Range Tests

    @Test("Heart rate range calculates correctly for each zone")
    func heartRateRangeCalculation() {
        let maxHR = 200.0

        // Zone 1: 50-60% of 200 = 100-120
        let z1Range = HeartRateZone.zone1.heartRateRange(maxHeartRate: maxHR)
        #expect(z1Range.lower == 100)
        #expect(z1Range.upper == 120)

        // Zone 2: 60-70% of 200 = 120-140
        let z2Range = HeartRateZone.zone2.heartRateRange(maxHeartRate: maxHR)
        #expect(z2Range.lower == 120)
        #expect(z2Range.upper == 140)

        // Zone 3: 70-80% of 200 = 140-160
        let z3Range = HeartRateZone.zone3.heartRateRange(maxHeartRate: maxHR)
        #expect(z3Range.lower == 140)
        #expect(z3Range.upper == 160)

        // Zone 4: 80-90% of 200 = 160-180
        let z4Range = HeartRateZone.zone4.heartRateRange(maxHeartRate: maxHR)
        #expect(z4Range.lower == 160)
        #expect(z4Range.upper == 180)

        // Zone 5: 90-100% of 200 = 180-200
        let z5Range = HeartRateZone.zone5.heartRateRange(maxHeartRate: maxHR)
        #expect(z5Range.lower == 180)
        #expect(z5Range.upper == 200)
    }

    @Test("Heart rate range for realistic max HR (190)")
    func heartRateRangeRealistic() {
        let maxHR = 190.0

        // Zone 3: 70-80% of 190 = 133-152
        let z3Range = HeartRateZone.zone3.heartRateRange(maxHeartRate: maxHR)
        #expect(z3Range.lower == 133)
        #expect(z3Range.upper == 152)
    }

    // MARK: - Sendable Conformance Tests

    @Test("HeartRateZone is Sendable")
    func sendableConformance() async {
        let zone = HeartRateZone.zone3

        // Pass zone across actor boundaries to verify Sendable
        let result = await Task.detached {
            return zone.rawValue
        }.value

        #expect(result == 3)
    }

    // MARK: - Color Tests

    @Test("Each zone has a distinct color")
    func zoneColorsDistinct() {
        let colors = HeartRateZone.allCases.map { $0.color }

        // All colors should be different (simple check using description)
        let colorDescriptions = colors.map { "\($0)" }
        let uniqueColors = Set(colorDescriptions)

        #expect(uniqueColors.count == 5)
    }

    // MARK: - Integration Tests

    @Test("Full workflow: age to zone calculation")
    func fullWorkflowTest() {
        // Simulate a 35-year-old user with current HR of 150
        let age = 35
        let currentHR = 150.0

        // Calculate max HR
        let maxHR = HeartRateZone.maxHeartRate(forAge: age)
        #expect(maxHR == 185) // 220 - 35 = 185

        // Determine zone (150/185 = 81% -> Zone 4)
        let zone = HeartRateZone.zone(forHeartRate: currentHR, maxHeartRate: maxHR)
        #expect(zone == .zone4)

        // Verify zone properties
        #expect(zone?.description == "Anaerobic")
        #expect(zone?.percentageRange == "80-90%")
    }

    @Test("Zone transitions during workout simulation")
    func workoutSimulation() {
        let maxHR = 180.0 // 40-year-old

        // Warm-up: HR gradually increases
        #expect(HeartRateZone.zone(forHeartRate: 85, maxHeartRate: maxHR) == nil)  // Below zone
        #expect(HeartRateZone.zone(forHeartRate: 95, maxHeartRate: maxHR) == .zone1)  // Zone 1
        #expect(HeartRateZone.zone(forHeartRate: 115, maxHeartRate: maxHR) == .zone2) // Zone 2

        // Main workout: higher intensity
        #expect(HeartRateZone.zone(forHeartRate: 135, maxHeartRate: maxHR) == .zone3) // Zone 3
        #expect(HeartRateZone.zone(forHeartRate: 155, maxHeartRate: maxHR) == .zone4) // Zone 4

        // Sprint intervals
        #expect(HeartRateZone.zone(forHeartRate: 170, maxHeartRate: maxHR) == .zone5) // Zone 5

        // Cool-down: HR decreases
        #expect(HeartRateZone.zone(forHeartRate: 120, maxHeartRate: maxHR) == .zone2) // Zone 2
        #expect(HeartRateZone.zone(forHeartRate: 100, maxHeartRate: maxHR) == .zone1) // Zone 1
    }
}
