import Foundation

/// Workout statistics for summary screen
public struct WorkoutStats: Sendable {
    public var totalDuration: TimeInterval
    public var runIntervals: Int
    public var walkIntervals: Int
    public var startTime: Date?
    public var endTime: Date?

    // MARK: - GPS/Route Properties

    /// Route data collected during workout (nil if GPS was disabled)
    public var routeData: RouteData?

    /// Total distance in meters (from GPS or HealthKit)
    public var totalDistance: Double

    /// Whether GPS tracking was enabled for this workout
    public var gpsTrackingEnabled: Bool

    public init(
        totalDuration: TimeInterval = 0,
        runIntervals: Int = 0,
        walkIntervals: Int = 0,
        startTime: Date? = nil,
        endTime: Date? = nil,
        routeData: RouteData? = nil,
        totalDistance: Double = 0,
        gpsTrackingEnabled: Bool = false
    ) {
        self.totalDuration = totalDuration
        self.runIntervals = runIntervals
        self.walkIntervals = walkIntervals
        self.startTime = startTime
        self.endTime = endTime
        self.routeData = routeData
        self.totalDistance = totalDistance
        self.gpsTrackingEnabled = gpsTrackingEnabled
    }

    // MARK: - Duration Formatting

    public var formattedDuration: String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    public var totalIntervals: Int {
        runIntervals + walkIntervals
    }

    // MARK: - Distance Formatting

    /// Whether this workout has distance data (either from GPS or HealthKit)
    public var hasDistance: Bool {
        totalDistance > 0
    }

    /// Formatted distance string using locale preference (e.g., "1.5 mi" or "2.4 km")
    public var formattedDistance: String {
        // Prefer route data's formatted distance if available
        if let route = routeData, route.hasValidRoute {
            return route.formattedDistance
        }

        // Otherwise format totalDistance directly
        let usesMetric = Locale.current.measurementSystem == .metric

        if usesMetric {
            let km = totalDistance / 1000.0
            if totalDistance < 1000 {
                return String(format: "%.0f m", totalDistance)
            } else {
                return String(format: "%.2f km", km)
            }
        } else {
            let miles = totalDistance / 1609.344
            if totalDistance < 160.934 {
                let feet = totalDistance * 3.28084
                return String(format: "%.0f ft", feet)
            } else {
                return String(format: "%.2f mi", miles)
            }
        }
    }

    /// Short formatted distance (e.g., "1.5mi" or "2.4km")
    public var shortFormattedDistance: String {
        if let route = routeData, route.hasValidRoute {
            return route.shortFormattedDistance
        }

        let usesMetric = Locale.current.measurementSystem == .metric

        if usesMetric {
            let km = totalDistance / 1000.0
            if totalDistance < 1000 {
                return String(format: "%.0fm", totalDistance)
            } else {
                return String(format: "%.1fkm", km)
            }
        } else {
            let miles = totalDistance / 1609.344
            return String(format: "%.1fmi", miles)
        }
    }

    // MARK: - Pace

    /// Formatted pace string (e.g., "8:30 /mi" or "5:15 /km")
    /// Returns nil if no valid distance/duration data
    public var formattedPace: String? {
        guard totalDistance > 0, totalDuration > 0 else { return nil }

        let usesMetric = Locale.current.measurementSystem == .metric
        let speedMetersPerSecond = totalDistance / totalDuration

        let paceMinutes: Double
        let unit: String

        if usesMetric {
            paceMinutes = (1000.0 / speedMetersPerSecond) / 60.0  // min/km
            unit = "/km"
        } else {
            paceMinutes = (1609.344 / speedMetersPerSecond) / 60.0  // min/mi
            unit = "/mi"
        }

        guard paceMinutes.isFinite && paceMinutes > 0 && paceMinutes < 60 else {
            return nil
        }

        let minutes = Int(paceMinutes)
        let seconds = Int((paceMinutes - Double(minutes)) * 60)
        return String(format: "%d:%02d %@", minutes, seconds, unit)
    }
}
