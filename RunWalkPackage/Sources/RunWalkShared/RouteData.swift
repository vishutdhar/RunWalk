import Foundation
import CoreLocation

/// Container for a complete workout route
/// Stores coordinates and provides computed properties for distance, region, etc.
public struct RouteData: Codable, Sendable, Equatable {
    // MARK: - Properties

    /// All recorded coordinates in chronological order
    public private(set) var coordinates: [RouteCoordinate]

    /// When the route started (first coordinate timestamp)
    public var startTime: Date? {
        coordinates.first?.timestamp
    }

    /// When the route ended (last coordinate timestamp)
    public var endTime: Date? {
        coordinates.last?.timestamp
    }

    // MARK: - Initialization

    /// Creates an empty route
    public init() {
        self.coordinates = []
    }

    /// Creates a route with existing coordinates
    /// - Parameter coordinates: Array of RouteCoordinate points
    public init(coordinates: [RouteCoordinate]) {
        self.coordinates = coordinates
    }

    // MARK: - Mutating Methods

    /// Adds a new coordinate to the route
    /// - Parameter coordinate: The coordinate to add
    public mutating func add(_ coordinate: RouteCoordinate) {
        coordinates.append(coordinate)
    }

    /// Adds a CLLocation to the route (converts to RouteCoordinate)
    /// - Parameter location: The CLLocation to add
    public mutating func add(_ location: CLLocation) {
        coordinates.append(RouteCoordinate(from: location))
    }

    /// Clears all coordinates from the route
    public mutating func clear() {
        coordinates.removeAll()
    }

    /// Removes coordinates that don't meet accuracy threshold
    /// - Parameter threshold: Maximum acceptable horizontal accuracy in meters
    public mutating func filterByAccuracy(_ threshold: Double) {
        coordinates = coordinates.filter { $0.meetsAccuracyThreshold(threshold) }
    }

    // MARK: - Distance Calculations

    /// Total distance of the route in meters
    /// Calculated by summing distances between consecutive points
    public var totalDistanceMeters: Double {
        guard coordinates.count > 1 else { return 0 }

        var total: Double = 0
        for i in 1..<coordinates.count {
            total += coordinates[i - 1].distance(to: coordinates[i])
        }
        return total
    }

    /// Total distance in kilometers
    public var totalDistanceKilometers: Double {
        totalDistanceMeters / 1000.0
    }

    /// Total distance in miles
    public var totalDistanceMiles: Double {
        totalDistanceMeters / 1609.344
    }

    /// Formatted distance string (e.g., "1.5 mi" or "2.4 km")
    /// Uses locale to determine metric vs imperial
    public var formattedDistance: String {
        let usesMetric = Locale.current.measurementSystem == .metric

        if usesMetric {
            if totalDistanceMeters < 1000 {
                return String(format: "%.0f m", totalDistanceMeters)
            } else {
                return String(format: "%.2f km", totalDistanceKilometers)
            }
        } else {
            if totalDistanceMeters < 160.934 { // Less than 0.1 miles
                let feet = totalDistanceMeters * 3.28084
                return String(format: "%.0f ft", feet)
            } else {
                return String(format: "%.2f mi", totalDistanceMiles)
            }
        }
    }

    /// Short formatted distance (e.g., "1.5mi" or "2.4km")
    public var shortFormattedDistance: String {
        let usesMetric = Locale.current.measurementSystem == .metric

        if usesMetric {
            if totalDistanceMeters < 1000 {
                return String(format: "%.0fm", totalDistanceMeters)
            } else {
                return String(format: "%.1fkm", totalDistanceKilometers)
            }
        } else {
            return String(format: "%.1fmi", totalDistanceMiles)
        }
    }

    // MARK: - MapKit Helpers

    /// Coordinates as CLLocationCoordinate2D array for MapKit polyline
    public var clCoordinates: [CLLocationCoordinate2D] {
        coordinates.map { $0.coordinate }
    }

    /// The first coordinate (start point)
    public var startCoordinate: CLLocationCoordinate2D? {
        coordinates.first?.coordinate
    }

    /// The last coordinate (end/current point)
    public var endCoordinate: CLLocationCoordinate2D? {
        coordinates.last?.coordinate
    }

    /// Whether the route has enough points to display
    public var hasValidRoute: Bool {
        coordinates.count >= 2
    }

    /// Whether the route is empty
    public var isEmpty: Bool {
        coordinates.isEmpty
    }

    /// Number of coordinate points
    public var pointCount: Int {
        coordinates.count
    }

    // MARK: - Bounding Region

    /// Calculates the bounding region that contains all coordinates
    /// Useful for setting MapKit camera to show entire route
    /// Returns nil if no coordinates exist
    public var boundingRegion: BoundingRegion? {
        guard !coordinates.isEmpty else { return nil }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let latDelta = (maxLat - minLat) * 1.2  // 20% padding
        let lonDelta = (maxLon - minLon) * 1.2

        // Ensure minimum span for very short routes
        let minSpan = 0.002  // About 200 meters
        let finalLatDelta = max(latDelta, minSpan)
        let finalLonDelta = max(lonDelta, minSpan)

        return BoundingRegion(
            centerLatitude: centerLat,
            centerLongitude: centerLon,
            latitudeDelta: finalLatDelta,
            longitudeDelta: finalLonDelta
        )
    }

    // MARK: - Speed Calculations

    /// Average speed in meters per second
    public var averageSpeedMetersPerSecond: Double? {
        guard let start = startTime,
              let end = endTime,
              totalDistanceMeters > 0 else {
            return nil
        }

        let duration = end.timeIntervalSince(start)
        guard duration > 0 else { return nil }

        return totalDistanceMeters / duration
    }

    /// Average pace in minutes per kilometer
    public var averagePaceMinutesPerKm: Double? {
        guard let speed = averageSpeedMetersPerSecond, speed > 0 else {
            return nil
        }
        return (1000.0 / speed) / 60.0  // Convert m/s to min/km
    }

    /// Average pace in minutes per mile
    public var averagePaceMinutesPerMile: Double? {
        guard let speed = averageSpeedMetersPerSecond, speed > 0 else {
            return nil
        }
        return (1609.344 / speed) / 60.0  // Convert m/s to min/mi
    }

    /// Formatted pace string (e.g., "8:30 /mi" or "5:15 /km")
    public var formattedPace: String? {
        let usesMetric = Locale.current.measurementSystem == .metric

        let pace: Double?
        let unit: String

        if usesMetric {
            pace = averagePaceMinutesPerKm
            unit = "/km"
        } else {
            pace = averagePaceMinutesPerMile
            unit = "/mi"
        }

        guard let paceValue = pace, paceValue.isFinite && paceValue > 0 else {
            return nil
        }

        let minutes = Int(paceValue)
        let seconds = Int((paceValue - Double(minutes)) * 60)
        return String(format: "%d:%02d %@", minutes, seconds, unit)
    }
}

// MARK: - Bounding Region

/// Represents a map region for displaying a route
public struct BoundingRegion: Codable, Sendable, Equatable {
    public let centerLatitude: Double
    public let centerLongitude: Double
    public let latitudeDelta: Double
    public let longitudeDelta: Double

    public var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
}
