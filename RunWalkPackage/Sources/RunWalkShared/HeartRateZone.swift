import SwiftUI

/// Represents heart rate training zones based on percentage of maximum heart rate
/// Uses industry-standard 5-zone system (same as Apple Workout app)
public enum HeartRateZone: Int, CaseIterable, Sendable {
    case zone1 = 1  // 50-60% - Recovery
    case zone2 = 2  // 60-70% - Fat Burn
    case zone3 = 3  // 70-80% - Aerobic
    case zone4 = 4  // 80-90% - Anaerobic
    case zone5 = 5  // 90-100% - Max Effort

    // MARK: - Display Properties

    /// Short display name (e.g., "Zone 1")
    public var name: String {
        "Zone \(rawValue)"
    }

    /// Descriptive name for the zone
    public var description: String {
        switch self {
        case .zone1: return "Recovery"
        case .zone2: return "Fat Burn"
        case .zone3: return "Aerobic"
        case .zone4: return "Anaerobic"
        case .zone5: return "Max Effort"
        }
    }

    /// Color associated with each zone
    public var color: Color {
        switch self {
        case .zone1: return .cyan
        case .zone2: return .green
        case .zone3: return .yellow
        case .zone4: return .orange
        case .zone5: return .red
        }
    }

    /// Percentage range for this zone (e.g., "50-60%")
    public var percentageRange: String {
        switch self {
        case .zone1: return "50-60%"
        case .zone2: return "60-70%"
        case .zone3: return "70-80%"
        case .zone4: return "80-90%"
        case .zone5: return "90-100%"
        }
    }

    /// Lower bound percentage (as decimal, e.g., 0.5 for 50%)
    public var lowerBound: Double {
        switch self {
        case .zone1: return 0.50
        case .zone2: return 0.60
        case .zone3: return 0.70
        case .zone4: return 0.80
        case .zone5: return 0.90
        }
    }

    /// Upper bound percentage (as decimal, e.g., 0.6 for 60%)
    public var upperBound: Double {
        switch self {
        case .zone1: return 0.60
        case .zone2: return 0.70
        case .zone3: return 0.80
        case .zone4: return 0.90
        case .zone5: return 1.00
        }
    }

    // MARK: - Zone Calculation

    /// Determines the heart rate zone for a given heart rate and max heart rate
    /// - Parameters:
    ///   - heartRate: Current heart rate in BPM
    ///   - maxHeartRate: Maximum heart rate in BPM
    /// - Returns: The appropriate zone, or nil if heart rate is below Zone 1 threshold
    public static func zone(forHeartRate heartRate: Double, maxHeartRate: Double) -> HeartRateZone? {
        guard maxHeartRate > 0, heartRate > 0 else { return nil }

        let percentage = heartRate / maxHeartRate

        // Below Zone 1 threshold (< 50%)
        if percentage < 0.50 {
            return nil
        }

        switch percentage {
        case 0.50..<0.60: return .zone1
        case 0.60..<0.70: return .zone2
        case 0.70..<0.80: return .zone3
        case 0.80..<0.90: return .zone4
        default: return .zone5  // 90% and above
        }
    }

    /// Calculates maximum heart rate using the standard formula (220 - age)
    /// - Parameter age: User's age in years
    /// - Returns: Estimated maximum heart rate in BPM
    public static func maxHeartRate(forAge age: Int) -> Double {
        Double(220 - age)
    }

    /// Calculates the heart rate range (BPM) for this zone given a max heart rate
    /// - Parameter maxHeartRate: Maximum heart rate in BPM
    /// - Returns: Tuple of (lower, upper) heart rate bounds
    public func heartRateRange(maxHeartRate: Double) -> (lower: Int, upper: Int) {
        let lower = Int(maxHeartRate * lowerBound)
        let upper = Int(maxHeartRate * upperBound)
        return (lower, upper)
    }
}
