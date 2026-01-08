import Foundation

/// Available interval durations based on market research
/// Common intervals from Jeff Galloway's Run-Walk-Run method and Couch to 5K
public enum IntervalDuration: Int, CaseIterable, Identifiable, Sendable {
    case thirtySeconds = 30
    case fortyFiveSeconds = 45
    case oneMinute = 60
    case twoMinutes = 120
    case threeMinutes = 180
    case fiveMinutes = 300
    case sevenMinutes = 420
    case tenMinutes = 600
    case fifteenMinutes = 900

    public var id: Int { rawValue }

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .thirtySeconds: return "30 sec"
        case .fortyFiveSeconds: return "45 sec"
        case .oneMinute: return "1 min"
        case .twoMinutes: return "2 min"
        case .threeMinutes: return "3 min"
        case .fiveMinutes: return "5 min"
        case .sevenMinutes: return "7 min"
        case .tenMinutes: return "10 min"
        case .fifteenMinutes: return "15 min"
        }
    }

    /// Compact name for small screens (watchOS)
    public var shortName: String {
        switch self {
        case .thirtySeconds: return "30s"
        case .fortyFiveSeconds: return "45s"
        case .oneMinute: return "1m"
        case .twoMinutes: return "2m"
        case .threeMinutes: return "3m"
        case .fiveMinutes: return "5m"
        case .sevenMinutes: return "7m"
        case .tenMinutes: return "10m"
        case .fifteenMinutes: return "15m"
        }
    }
}
