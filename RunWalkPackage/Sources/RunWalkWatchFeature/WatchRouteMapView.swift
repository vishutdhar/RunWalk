import SwiftUI
import MapKit
import RunWalkShared

/// Compact map view for displaying workout route on Apple Watch
/// Optimized for small screen with simplified controls
public struct WatchRouteMapView: View {
    // MARK: - Properties

    /// The route data to display
    let routeData: RouteData

    /// Whether this is live tracking or static display
    var isLive: Bool = false

    /// Current phase for marker coloring
    var currentPhase: TimerPhase?

    // MARK: - State

    @State private var position: MapCameraPosition = .automatic

    // MARK: - Body

    public var body: some View {
        ZStack(alignment: .bottom) {
            mapContent

            if routeData.hasValidRoute {
                distanceLabel
            }
        }
    }

    // MARK: - Map Content

    private var mapContent: some View {
        Map(position: $position) {
            // Route polyline - thinner for watch
            if routeData.hasValidRoute {
                MapPolyline(coordinates: routeData.clCoordinates)
                    .stroke(.blue, lineWidth: 3)
            }

            // Start marker
            if let start = routeData.startCoordinate {
                Annotation("", coordinate: start) {
                    Circle()
                        .fill(.green)
                        .frame(width: 12, height: 12)
                }
            }

            // End/Current marker
            if let end = routeData.endCoordinate {
                Annotation("", coordinate: end) {
                    Circle()
                        .fill(markerColor)
                        .frame(width: 14, height: 14)
                        .overlay {
                            if isLive {
                                Circle()
                                    .stroke(markerColor, lineWidth: 2)
                                    .frame(width: 20, height: 20)
                                    .opacity(0.5)
                            }
                        }
                }
            }
        }
        .mapStyle(.standard)
        .mapControls { }  // No controls on watch - too small
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
    }

    // MARK: - Distance Label

    private var distanceLabel: some View {
        Text(routeData.shortFormattedDistance)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 4)
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
            // Follow current location
            position = .camera(MapCamera(
                centerCoordinate: current,
                distance: 300,  // Closer view on watch
                heading: 0,
                pitch: 0
            ))
        } else if let region = routeData.boundingRegion {
            // Show entire route
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

// MARK: - Compact Watch Map (for embedding)

/// Even smaller map for list rows on watch
public struct WatchCompactMapView: View {
    let routeData: RouteData

    public init(routeData: RouteData) {
        self.routeData = routeData
    }

    public var body: some View {
        if routeData.hasValidRoute {
            Map {
                MapPolyline(coordinates: routeData.clCoordinates)
                    .stroke(.blue, lineWidth: 2)
            }
            .mapStyle(.standard)
            .disabled(true)
            .allowsHitTesting(false)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.2))
                .overlay {
                    Image(systemName: "map")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
        }
    }
}

// MARK: - Preview

#Preview("Watch Live Map") {
    let coords = [
        RouteCoordinate(latitude: 37.7749, longitude: -122.4194),
        RouteCoordinate(latitude: 37.7751, longitude: -122.4180),
        RouteCoordinate(latitude: 37.7755, longitude: -122.4165)
    ]
    let route = RouteData(coordinates: coords)

    return WatchRouteMapView(
        routeData: route,
        isLive: true,
        currentPhase: .run
    )
    .frame(width: 180, height: 150)
}
