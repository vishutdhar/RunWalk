import Testing
import Foundation
@testable import RunWalkShared

// MARK: - PresetCategory Tests

@Suite("PresetCategory Tests")
struct PresetCategoryTests {

    @Test("All categories have correct raw values")
    func categoryRawValues() {
        #expect(PresetCategory.beginner.rawValue == "Beginner")
        #expect(PresetCategory.intermediate.rawValue == "Intermediate")
        #expect(PresetCategory.advanced.rawValue == "Advanced")
        #expect(PresetCategory.custom.rawValue == "My Presets")
    }

    @Test("Categories have correct sort order")
    func categorySortOrder() {
        #expect(PresetCategory.beginner.sortOrder == 0)
        #expect(PresetCategory.intermediate.sortOrder == 1)
        #expect(PresetCategory.advanced.sortOrder == 2)
        #expect(PresetCategory.custom.sortOrder == 3)
    }

    @Test("Categories have icons")
    func categoryIcons() {
        #expect(!PresetCategory.beginner.icon.isEmpty)
        #expect(!PresetCategory.intermediate.icon.isEmpty)
        #expect(!PresetCategory.advanced.icon.isEmpty)
        #expect(!PresetCategory.custom.icon.isEmpty)
    }

    @Test("All categories are iterable via CaseIterable")
    func allCasesIterable() {
        let allCategories = PresetCategory.allCases

        #expect(allCategories.count == 4)
        #expect(allCategories.contains(.beginner))
        #expect(allCategories.contains(.intermediate))
        #expect(allCategories.contains(.advanced))
        #expect(allCategories.contains(.custom))
    }
}

// MARK: - WorkoutPreset Tests

@Suite("WorkoutPreset Tests")
struct WorkoutPresetTests {

    // MARK: - Initialization Tests

    @Test("Preset initializes with correct values")
    func presetInitialization() {
        let preset = WorkoutPreset(
            name: "Test Preset",
            description: "A test preset",
            runIntervalSeconds: 60,
            walkIntervalSeconds: 30,
            category: .beginner,
            isBuiltIn: true,
            sortOrder: 5
        )

        #expect(preset.name == "Test Preset")
        #expect(preset.presetDescription == "A test preset")
        #expect(preset.runIntervalSeconds == 60)
        #expect(preset.walkIntervalSeconds == 30)
        #expect(preset.category == .beginner)
        #expect(preset.isBuiltIn == true)
        #expect(preset.sortOrder == 5)
    }

    @Test("Preset initializes with default values")
    func presetDefaultValues() {
        let preset = WorkoutPreset(
            name: "Simple Preset",
            runIntervalSeconds: 30,
            walkIntervalSeconds: 60,
            category: .custom
        )

        #expect(preset.presetDescription == nil)
        #expect(preset.isBuiltIn == false)
        #expect(preset.sortOrder == 0)
        #expect(preset.id != UUID())  // Should have a UUID
    }

    // MARK: - Formatted Interval Tests

    @Test("Formatted run interval for seconds only")
    func formattedRunIntervalSecondsOnly() {
        let preset = WorkoutPreset(
            name: "Test",
            runIntervalSeconds: 30,
            walkIntervalSeconds: 60,
            category: .beginner
        )

        #expect(preset.formattedRunInterval == "30s")
    }

    @Test("Formatted run interval for minutes only")
    func formattedRunIntervalMinutesOnly() {
        let preset = WorkoutPreset(
            name: "Test",
            runIntervalSeconds: 120,
            walkIntervalSeconds: 60,
            category: .beginner
        )

        #expect(preset.formattedRunInterval == "2m")
    }

    @Test("Formatted run interval for minutes and seconds")
    func formattedRunIntervalMinutesAndSeconds() {
        let preset = WorkoutPreset(
            name: "Test",
            runIntervalSeconds: 90,
            walkIntervalSeconds: 60,
            category: .beginner
        )

        #expect(preset.formattedRunInterval == "1m 30s")
    }

    @Test("Formatted walk interval")
    func formattedWalkInterval() {
        let preset = WorkoutPreset(
            name: "Test",
            runIntervalSeconds: 60,
            walkIntervalSeconds: 45,
            category: .beginner
        )

        #expect(preset.formattedWalkInterval == "45s")
    }

    @Test("Interval summary format")
    func intervalSummary() {
        let preset = WorkoutPreset(
            name: "Test",
            runIntervalSeconds: 60,
            walkIntervalSeconds: 30,
            category: .beginner
        )

        #expect(preset.intervalSummary == "1m / 30s")
    }

    // MARK: - Full Description Tests

    @Test("Full description with preset description")
    func fullDescriptionWithDescription() {
        let preset = WorkoutPreset(
            name: "Test",
            description: "Great for beginners",
            runIntervalSeconds: 60,
            walkIntervalSeconds: 30,
            category: .beginner
        )

        #expect(preset.fullDescription.contains("Great for beginners"))
        #expect(preset.fullDescription.contains("Run"))
        #expect(preset.fullDescription.contains("Walk"))
    }

    @Test("Full description without preset description")
    func fullDescriptionWithoutDescription() {
        let preset = WorkoutPreset(
            name: "Test",
            runIntervalSeconds: 60,
            walkIntervalSeconds: 30,
            category: .beginner
        )

        #expect(preset.fullDescription.contains("Run"))
        #expect(preset.fullDescription.contains("Walk"))
    }

    // MARK: - Category Tests

    @Test("Category getter returns correct value")
    func categoryGetter() {
        let preset = WorkoutPreset(
            name: "Test",
            runIntervalSeconds: 60,
            walkIntervalSeconds: 30,
            category: .intermediate
        )

        #expect(preset.category == .intermediate)
        #expect(preset.categoryRaw == "Intermediate")
    }

    @Test("Category setter updates raw value")
    func categorySetter() {
        let preset = WorkoutPreset(
            name: "Test",
            runIntervalSeconds: 60,
            walkIntervalSeconds: 30,
            category: .beginner
        )

        preset.category = .advanced

        #expect(preset.category == .advanced)
        #expect(preset.categoryRaw == "Advanced")
    }

    // MARK: - Built-in Presets Tests

    @Test("Built-in presets exist")
    func builtInPresetsExist() {
        let builtIn = WorkoutPreset.builtInPresets

        #expect(builtIn.count >= 6)  // At least 6 presets
    }

    @Test("Built-in presets have correct properties")
    func builtInPresetsProperties() {
        let builtIn = WorkoutPreset.builtInPresets

        for preset in builtIn {
            #expect(preset.isBuiltIn == true)
            #expect(!preset.name.isEmpty)
            #expect(preset.runIntervalSeconds > 0)
            #expect(preset.walkIntervalSeconds > 0)
        }
    }

    @Test("Built-in presets have valid categories")
    func builtInPresetsCategories() {
        let builtIn = WorkoutPreset.builtInPresets
        let categories = Set(builtIn.map { $0.category })

        // Should have beginner, intermediate, and advanced
        #expect(categories.contains(.beginner))
        #expect(categories.contains(.intermediate))
        #expect(categories.contains(.advanced))

        // Should not have custom (built-in presets aren't custom)
        #expect(!categories.contains(.custom))
    }

    @Test("Built-in preset lookup by name")
    func builtInPresetLookup() {
        let easyStart = WorkoutPreset.builtInPreset(named: "Easy Start")

        #expect(easyStart != nil)
        #expect(easyStart?.category == .beginner)
        #expect(easyStart?.runIntervalSeconds == 30)
        #expect(easyStart?.walkIntervalSeconds == 60)
    }

    @Test("Built-in preset lookup returns nil for unknown name")
    func builtInPresetLookupUnknown() {
        let unknown = WorkoutPreset.builtInPreset(named: "Unknown Preset")

        #expect(unknown == nil)
    }

    // MARK: - Sorting Tests

    @Test("Sorted comparator orders by category first")
    func sortedComparatorCategory() {
        let beginner = WorkoutPreset(
            name: "A",
            runIntervalSeconds: 30,
            walkIntervalSeconds: 30,
            category: .beginner,
            sortOrder: 0
        )
        let advanced = WorkoutPreset(
            name: "B",
            runIntervalSeconds: 30,
            walkIntervalSeconds: 30,
            category: .advanced,
            sortOrder: 0
        )

        #expect(WorkoutPreset.sortedComparator(beginner, advanced) == true)
        #expect(WorkoutPreset.sortedComparator(advanced, beginner) == false)
    }

    @Test("Sorted comparator orders by sortOrder within category")
    func sortedComparatorSortOrder() {
        let first = WorkoutPreset(
            name: "B",
            runIntervalSeconds: 30,
            walkIntervalSeconds: 30,
            category: .beginner,
            sortOrder: 0
        )
        let second = WorkoutPreset(
            name: "A",
            runIntervalSeconds: 30,
            walkIntervalSeconds: 30,
            category: .beginner,
            sortOrder: 1
        )

        #expect(WorkoutPreset.sortedComparator(first, second) == true)
        #expect(WorkoutPreset.sortedComparator(second, first) == false)
    }

    @Test("Sorted comparator orders by name when category and sortOrder are equal")
    func sortedComparatorName() {
        let alpha = WorkoutPreset(
            name: "Alpha",
            runIntervalSeconds: 30,
            walkIntervalSeconds: 30,
            category: .beginner,
            sortOrder: 0
        )
        let beta = WorkoutPreset(
            name: "Beta",
            runIntervalSeconds: 30,
            walkIntervalSeconds: 30,
            category: .beginner,
            sortOrder: 0
        )

        #expect(WorkoutPreset.sortedComparator(alpha, beta) == true)
        #expect(WorkoutPreset.sortedComparator(beta, alpha) == false)
    }

    // MARK: - Edge Cases

    @Test("Preset with zero seconds")
    func presetZeroSeconds() {
        let preset = WorkoutPreset(
            name: "Zero",
            runIntervalSeconds: 0,
            walkIntervalSeconds: 0,
            category: .custom
        )

        #expect(preset.formattedRunInterval == "0s")
        #expect(preset.formattedWalkInterval == "0s")
    }

    @Test("Preset with very long intervals")
    func presetLongIntervals() {
        let preset = WorkoutPreset(
            name: "Long",
            runIntervalSeconds: 1800,  // 30 minutes
            walkIntervalSeconds: 900,   // 15 minutes
            category: .advanced
        )

        #expect(preset.formattedRunInterval == "30m")
        #expect(preset.formattedWalkInterval == "15m")
    }
}
