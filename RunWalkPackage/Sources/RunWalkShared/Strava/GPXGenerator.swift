import Foundation
import CoreGPX

/// Generates GPX files from RouteData for Strava upload
public struct GPXGenerator: Sendable {

    public init() {}

    /// Generates a GPX string from RouteData
    /// - Parameters:
    ///   - routeData: The route data containing coordinates
    ///   - name: Activity name
    ///   - activityType: Type of activity (e.g., "running")
    /// - Returns: GPX XML string, or nil if route is invalid
    public func generate(
        from routeData: RouteData,
        name: String,
        activityType: String = "running"
    ) -> String? {
        guard routeData.hasValidRoute else { return nil }

        // Create GPX root
        let root = GPXRoot(creator: "RunWalk App")

        // Add metadata
        let metadata = GPXMetadata()
        metadata.name = name
        metadata.time = routeData.startTime
        root.metadata = metadata

        // Create track
        let track = GPXTrack()
        track.name = name
        track.type = activityType

        // Create track segment with all points
        let segment = GPXTrackSegment()

        for coordinate in routeData.coordinates {
            let trackPoint = GPXTrackPoint(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            trackPoint.elevation = coordinate.altitude
            trackPoint.time = coordinate.timestamp
            segment.add(trackpoint: trackPoint)
        }

        track.add(trackSegment: segment)
        root.add(track: track)

        return root.gpx()
    }

    /// Generates GPX from a WorkoutRecord
    /// - Parameter record: The workout record to convert
    /// - Returns: GPX XML string, or nil if no valid route data
    public func generate(from record: WorkoutRecord) -> String? {
        guard let routeData = record.routeData else { return nil }

        let name = "Run-Walk: \(record.formattedDuration)"
        return generate(from: routeData, name: name)
    }

    /// Generates GPX data from RouteData (for upload)
    /// - Parameters:
    ///   - routeData: The route data containing coordinates
    ///   - name: Activity name
    /// - Returns: GPX data as UTF-8 encoded Data, or nil if invalid
    public func generateData(
        from routeData: RouteData,
        name: String
    ) -> Data? {
        guard let gpxString = generate(from: routeData, name: name) else {
            return nil
        }
        return gpxString.data(using: .utf8)
    }

    /// Generates GPX data from a WorkoutRecord
    /// - Parameter record: The workout record to convert
    /// - Returns: GPX data as UTF-8 encoded Data, or nil if invalid
    public func generateData(from record: WorkoutRecord) -> Data? {
        guard let gpxString = generate(from: record) else {
            return nil
        }
        return gpxString.data(using: .utf8)
    }
}
