import Foundation
import CoreLocation
import RunWalkShared

/// Location manager for iOS GPS tracking during workouts
/// Handles authorization, tracking, and route data collection
@Observable
@MainActor
public final class iOSLocationManager: NSObject, Sendable {
    // MARK: - Published Properties

    /// Current authorization status
    public private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// Whether location services are authorized for use
    public var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// Current location (most recent valid reading)
    public private(set) var currentLocation: CLLocation?

    /// Collected route data
    public private(set) var routeData: RouteData = RouteData()

    /// Whether actively tracking location
    public private(set) var isTracking: Bool = false

    /// Current GPS accuracy mode
    public var accuracyMode: GPSAccuracyMode = .balanced {
        didSet {
            if isTracking {
                configureLocationManager()
            }
        }
    }

    /// Error message if something goes wrong
    public private(set) var errorMessage: String?

    // MARK: - Private Properties

    private let locationManager: CLLocationManager
    private var lastValidLocation: CLLocation?

    // MARK: - Initialization

    public override init() {
        self.locationManager = CLLocationManager()
        super.init()

        // Configure delegate - must be done on MainActor
        locationManager.delegate = self

        // Get initial authorization status
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Authorization

    /// Requests location authorization from the user
    /// - Returns: Whether authorization was granted
    @discardableResult
    public func requestAuthorization() async -> Bool {
        // Check current status
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            // Request authorization and wait for delegate callback
            locationManager.requestWhenInUseAuthorization()

            // Wait a moment for the authorization dialog
            try? await Task.sleep(for: .milliseconds(500))

            // Check status again after request
            return locationManager.authorizationStatus == .authorizedWhenInUse ||
                   locationManager.authorizationStatus == .authorizedAlways

        case .authorizedWhenInUse, .authorizedAlways:
            return true

        case .denied, .restricted:
            errorMessage = "Location access denied. Enable in Settings."
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Tracking Control

    /// Starts GPS location tracking
    public func startTracking() {
        guard isAuthorized else {
            errorMessage = "Location not authorized"
            return
        }

        // Clear previous route
        routeData = RouteData()
        lastValidLocation = nil
        errorMessage = nil

        // Configure for workout tracking
        configureLocationManager()

        // Enable background updates for workout tracking
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.pausesLocationUpdatesAutomatically = false

        // Start updates
        locationManager.startUpdatingLocation()
        isTracking = true
    }

    /// Stops GPS location tracking
    public func stopTracking() {
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        isTracking = false
    }

    /// Clears the current route data
    public func clearRoute() {
        routeData = RouteData()
        lastValidLocation = nil
        currentLocation = nil
    }

    // MARK: - Private Methods

    private func configureLocationManager() {
        locationManager.desiredAccuracy = accuracyMode.desiredAccuracy
        locationManager.distanceFilter = accuracyMode.distanceFilter
        locationManager.activityType = .fitness
    }

    private func processLocation(_ location: CLLocation) {
        // Filter out invalid locations
        guard location.horizontalAccuracy >= 0 else { return }

        // Filter by accuracy threshold based on mode
        guard location.horizontalAccuracy <= accuracyMode.accuracyThreshold else { return }

        // Filter out stale locations (older than 10 seconds)
        let age = -location.timestamp.timeIntervalSinceNow
        guard age < 10 else { return }

        // Check for significant movement to avoid duplicate points
        if let last = lastValidLocation {
            let distance = location.distance(from: last)
            // Only add if moved at least half the distance filter
            if distance < accuracyMode.distanceFilter / 2 {
                return
            }
        }

        // Add to route
        routeData.add(location)
        currentLocation = location
        lastValidLocation = location
    }
}

// MARK: - CLLocationManagerDelegate

extension iOSLocationManager: CLLocationManagerDelegate {
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for location in locations {
                processLocation(location)
            }
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // Ignore location unknown errors (temporary)
            if let clError = error as? CLError, clError.code == .locationUnknown {
                return
            }

            errorMessage = "Location error: \(error.localizedDescription)"
        }
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Capture status before crossing actor boundary
        let newStatus = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = newStatus

            // If tracking was attempted but auth wasn't ready, try starting now
            if isAuthorized && !isTracking && routeData.isEmpty {
                // Authorization granted, ready to track when requested
            }
        }
    }
}
