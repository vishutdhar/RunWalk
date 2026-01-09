import Foundation
import CoreLocation

/// GPS accuracy modes for balancing battery life vs route precision
/// Higher accuracy = more battery drain but smoother route
/// Lower accuracy = better battery but route may be less precise
public enum GPSAccuracyMode: String, Codable, CaseIterable, Sendable {
    /// Best accuracy - uses more battery
    /// - desiredAccuracy: kCLLocationAccuracyBest
    /// - distanceFilter: 5 meters
    /// - Recommended for: Short workouts, when route precision is critical
    case high

    /// Balanced accuracy and battery (default)
    /// - desiredAccuracy: kCLLocationAccuracyNearestTenMeters
    /// - distanceFilter: 10 meters
    /// - Recommended for: Most workouts
    case balanced

    /// Power saving mode - uses less battery
    /// - desiredAccuracy: kCLLocationAccuracyHundredMeters
    /// - distanceFilter: 25 meters
    /// - Recommended for: Long workouts, when battery is limited
    case low

    // MARK: - CoreLocation Configuration

    /// The CLLocationAccuracy value to use with CLLocationManager
    public var desiredAccuracy: CLLocationAccuracy {
        switch self {
        case .high:
            return kCLLocationAccuracyBest
        case .balanced:
            return kCLLocationAccuracyNearestTenMeters
        case .low:
            return kCLLocationAccuracyHundredMeters
        }
    }

    /// The distance filter in meters - only deliver updates when moved this far
    public var distanceFilter: CLLocationDistance {
        switch self {
        case .high:
            return 5.0
        case .balanced:
            return 10.0
        case .low:
            return 25.0
        }
    }

    /// Maximum acceptable horizontal accuracy - filter out readings worse than this
    public var accuracyThreshold: Double {
        switch self {
        case .high:
            return 20.0  // Accept readings within 20m accuracy
        case .balanced:
            return 50.0  // Accept readings within 50m accuracy
        case .low:
            return 100.0 // Accept readings within 100m accuracy
        }
    }

    // MARK: - Display

    /// Human-readable display name for settings UI
    public var displayName: String {
        switch self {
        case .high:
            return "High Accuracy"
        case .balanced:
            return "Balanced"
        case .low:
            return "Power Saver"
        }
    }

    /// Short description for settings UI
    public var description: String {
        switch self {
        case .high:
            return "Best route precision, uses more battery"
        case .balanced:
            return "Good balance of accuracy and battery"
        case .low:
            return "Saves battery, route may be less precise"
        }
    }

    /// Icon name for settings UI
    public var iconName: String {
        switch self {
        case .high:
            return "location.fill"
        case .balanced:
            return "location"
        case .low:
            return "location.slash"
        }
    }
}

// MARK: - Identifiable

extension GPSAccuracyMode: Identifiable {
    public var id: String { rawValue }
}

// MARK: - RawRepresentable for @AppStorage

// GPSAccuracyMode already conforms to RawRepresentable via String rawValue
// This allows direct use with @AppStorage:
// @AppStorage("gpsAccuracyMode") var accuracyMode: GPSAccuracyMode = .balanced
