import SwiftUI
import MapKit
import CoreLocation
import RunWalkShared

/// Map view that displays a workout route using Apple Maps
/// Supports both live tracking during workout and static display for history
public struct RouteMapView: View {
    // MARK: - Properties

    /// The route data to display
    let routeData: RouteData

    /// Whether this is a live view (follows current location) or static (shows full route)
    var isLive: Bool = false

    /// Current phase for coloring the current position marker
    var currentPhase: TimerPhase?

    /// Whether to show distance overlay
    var showDistance: Bool = true

    /// Current location (for centering when route is empty during live tracking)
    var currentLocation: CLLocation?

    // MARK: - State

    @State private var position: MapCameraPosition = .automatic

    // MARK: - Body

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            if isLive && !routeData.hasValidRoute && currentLocation == nil {
                // Show waiting message when GPS enabled but no data yet
                waitingForGPSView
            } else {
                mapContent
            }

            if showDistance && routeData.hasValidRoute {
                distanceOverlay
            }
        }
    }

    // MARK: - Waiting for GPS View

    private var waitingForGPSView: some View {
        ZStack {
            // Dark background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.8))

            VStack(spacing: 16) {
                // Pulsing location icon
                Image(systemName: "location.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse, options: .repeating)

                Text("Acquiring GPS Signal...")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)

                Text("Make sure you're outdoors with a clear view of the sky")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Map Content

    private var mapContent: some View {
        Map(position: $position) {
            // Route polyline
            if routeData.hasValidRoute {
                MapPolyline(coordinates: routeData.clCoordinates)
                    .stroke(.blue, lineWidth: 4)
            }

            // Start marker (green flag)
            if let start = routeData.startCoordinate {
                Annotation("Start", coordinate: start) {
                    ZStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 24, height: 24)
                        Image(systemName: "flag.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                    }
                }
            }

            // End/Current marker
            if let end = routeData.endCoordinate {
                Annotation(isLive ? "Current" : "End", coordinate: end) {
                    ZStack {
                        Circle()
                            .fill(markerColor)
                            .frame(width: 24, height: 24)

                        if isLive {
                            // Pulsing animation for live tracking
                            Circle()
                                .stroke(markerColor, lineWidth: 2)
                                .frame(width: 32, height: 32)
                                .opacity(0.5)
                        }

                        Image(systemName: isLive ? "figure.run" : "flag.checkered")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            // Only show controls when map is interactive (not live)
            if !isLive {
                MapCompass()
                MapScaleView()
            }
        }
        // Disable map interaction during live tracking so swipe gestures
        // pass through to TabView for page navigation
        .allowsHitTesting(!isLive)
        .onAppear {
            updateCameraPosition()
        }
        .onChange(of: routeData.pointCount) { _, _ in
            if isLive {
                updateCameraPosition()
            }
        }
        .onChange(of: currentLocation?.coordinate.latitude) { _, _ in
            if isLive && !routeData.hasValidRoute {
                // Update position when we get first location but no route yet
                updateCameraPosition()
            }
        }
    }

    // MARK: - Distance Overlay

    private var distanceOverlay: some View {
        HStack(spacing: 4) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.system(size: 12))
            Text(routeData.formattedDistance)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(8)
    }

    // MARK: - Helpers

    private var markerColor: Color {
        if isLive, let phase = currentPhase {
            return phase == .run ? .orange : .green
        }
        return .red
    }

    private func updateCameraPosition() {
        if isLive {
            // During live tracking, prefer route end coordinate, then current location
            if let current = routeData.endCoordinate {
                // Follow the route's current position
                position = .camera(MapCamera(
                    centerCoordinate: current,
                    distance: 500,  // 500 meter view distance
                    heading: 0,
                    pitch: 0
                ))
            } else if let location = currentLocation {
                // Route is empty but we have current location - center on it
                position = .camera(MapCamera(
                    centerCoordinate: location.coordinate,
                    distance: 500,
                    heading: 0,
                    pitch: 0
                ))
            }
            // If neither exists, the "Waiting for GPS" view is shown instead
        } else if let region = routeData.boundingRegion {
            // Show entire route for static view
            position = .region(MKCoordinateRegion(
                center: region.centerCoordinate,
                span: MKCoordinateSpan(
                    latitudeDelta: region.latitudeDelta,
                    longitudeDelta: region.longitudeDelta
                )
            ))
        }
    }
}

// MARK: - Compact Route Map (for embedding in other views)

/// A smaller, simplified map view for embedding in summary or list views
public struct CompactRouteMapView: View {
    let routeData: RouteData

    public init(routeData: RouteData) {
        self.routeData = routeData
    }

    public var body: some View {
        if routeData.hasValidRoute {
            Map {
                MapPolyline(coordinates: routeData.clCoordinates)
                    .stroke(.blue, lineWidth: 3)
            }
            .mapStyle(.standard)
            .disabled(true)  // Non-interactive
            .allowsHitTesting(false)
        } else {
            // Placeholder when no route
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: "map")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                        Text("No Route")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview("Live Route") {
    // Sample route for preview
    let coords = [
        RouteCoordinate(latitude: 37.7749, longitude: -122.4194),
        RouteCoordinate(latitude: 37.7751, longitude: -122.4180),
        RouteCoordinate(latitude: 37.7755, longitude: -122.4165),
        RouteCoordinate(latitude: 37.7760, longitude: -122.4150)
    ]
    let route = RouteData(coordinates: coords)

    return RouteMapView(
        routeData: route,
        isLive: true,
        currentPhase: .run
    )
    .frame(height: 300)
}

#Preview("Static Route") {
    let coords = [
        RouteCoordinate(latitude: 37.7749, longitude: -122.4194),
        RouteCoordinate(latitude: 37.7751, longitude: -122.4180),
        RouteCoordinate(latitude: 37.7755, longitude: -122.4165),
        RouteCoordinate(latitude: 37.7760, longitude: -122.4150)
    ]
    let route = RouteData(coordinates: coords)

    return RouteMapView(
        routeData: route,
        isLive: false
    )
    .frame(height: 300)
}
