import SwiftUI
import MapKit
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

    // MARK: - State

    @State private var position: MapCameraPosition = .automatic

    // MARK: - Body

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            mapContent

            if showDistance && routeData.hasValidRoute {
                distanceOverlay
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
            MapCompass()
            MapScaleView()
        }
        .onAppear {
            updateCameraPosition()
        }
        .onChange(of: routeData.pointCount) { _, _ in
            if isLive {
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
        if isLive, let current = routeData.endCoordinate {
            // Follow current location during live tracking
            position = .camera(MapCamera(
                centerCoordinate: current,
                distance: 500,  // 500 meter view distance
                heading: 0,
                pitch: 0
            ))
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
