import Foundation
import CoreLocation

/// Codable wrapper for CLLocationCoordinate2D
/// CLLocationCoordinate2D is NOT Codable, so we need this wrapper for SwiftData storage
public struct RouteCoordinate: Codable, Sendable, Equatable {
    // MARK: - Properties

    /// Latitude in degrees (-90 to 90)
    public let latitude: Double

    /// Longitude in degrees (-180 to 180)
    public let longitude: Double

    /// When this coordinate was recorded
    public let timestamp: Date

    /// Altitude in meters (optional - may not be available)
    public let altitude: Double?

    /// Horizontal accuracy in meters (lower is better)
    /// Used to filter out inaccurate readings
    public let horizontalAccuracy: Double

    /// Speed in meters per second (optional)
    public let speed: Double?

    // MARK: - Initialization

    /// Creates a RouteCoordinate from a CLLocation
    /// - Parameter location: The CLLocation to convert
    public init(from location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.timestamp = location.timestamp
        self.altitude = location.altitude >= 0 ? location.altitude : nil
        self.horizontalAccuracy = location.horizontalAccuracy
        self.speed = location.speed >= 0 ? location.speed : nil
    }

    /// Creates a RouteCoordinate with explicit values (useful for testing)
    public init(
        latitude: Double,
        longitude: Double,
        timestamp: Date = Date(),
        altitude: Double? = nil,
        horizontalAccuracy: Double = 10.0,
        speed: Double? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
    }

    // MARK: - Computed Properties

    /// Converts back to CLLocationCoordinate2D for MapKit use
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Converts back to CLLocation (useful for distance calculations)
    public var location: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude ?? 0,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: -1,
            timestamp: timestamp
        )
    }

    // MARK: - Validation

    /// Whether this coordinate appears to be valid
    /// Invalid coordinates have accuracy < 0 or unreasonable lat/long values
    public var isValid: Bool {
        horizontalAccuracy >= 0 &&
        latitude >= -90 && latitude <= 90 &&
        longitude >= -180 && longitude <= 180
    }

    /// Whether this coordinate meets the specified accuracy threshold
    /// - Parameter threshold: Maximum acceptable horizontal accuracy in meters
    /// - Returns: true if this coordinate's accuracy is better (lower) than threshold
    public func meetsAccuracyThreshold(_ threshold: Double) -> Bool {
        horizontalAccuracy > 0 && horizontalAccuracy <= threshold
    }

    // MARK: - Distance Calculation

    /// Calculates distance to another coordinate in meters
    /// - Parameter other: The other coordinate to measure to
    /// - Returns: Distance in meters
    public func distance(to other: RouteCoordinate) -> Double {
        location.distance(from: other.location)
    }
}

// MARK: - Identifiable

extension RouteCoordinate: Identifiable {
    public var id: Date { timestamp }
}

// MARK: - CustomStringConvertible

extension RouteCoordinate: CustomStringConvertible {
    public var description: String {
        let lat = String(format: "%.6f", latitude)
        let lon = String(format: "%.6f", longitude)
        let acc = String(format: "%.1f", horizontalAccuracy)
        return "(\(lat), \(lon)) acc:\(acc)m"
    }
}
