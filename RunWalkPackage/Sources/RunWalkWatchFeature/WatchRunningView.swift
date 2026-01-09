import SwiftUI
import MapKit
import RunWalkShared

/// Active workout view for watchOS
/// Shows phase, countdown timer, and controls
/// Supports swipeable pages: Timer ←→ Map (when GPS enabled)
struct WatchRunningView: View {
    // MARK: - Properties

    @Bindable var timer: WatchIntervalTimer
    @AppStorage("gpsTrackingEnabled") private var gpsTrackingEnabled = true
    @State private var currentPage: WorkoutPage = .timer

    /// Pages available during workout
    enum WorkoutPage: Int {
        case timer = 0
        case map = 1
    }

    // MARK: - Body

    var body: some View {
        Group {
            if gpsTrackingEnabled {
                // Swipeable pages when GPS enabled
                TabView(selection: $currentPage) {
                    timerPageView
                        .tag(WorkoutPage.timer)

                    mapPageView
                        .tag(WorkoutPage.map)
                }
                .tabViewStyle(.verticalPage)  // Vertical swipe on watchOS
            } else {
                // Just timer when GPS disabled
                timerPageView
            }
        }
    }

    // MARK: - Timer Page

    private var timerPageView: some View {
        VStack(spacing: 2) {
            // Phase indicator
            HStack(spacing: 4) {
                Text(timer.currentPhase.rawValue)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(timer.currentPhase == .run ? Color.orange : Color.green)
                    .contentTransition(.interpolate)
                    .animation(.easeInOut(duration: 0.3), value: timer.currentPhase)

                // GPS indicator
                if gpsTrackingEnabled {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                }
            }

            // Timer ring with time display
            ZStack {
                // Progress ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        timer.currentPhase == .run ? Color.orange : Color.green,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: progress)

                // Time display
                VStack(spacing: 0) {
                    Text(timer.formattedTime)
                        .font(.system(size: 38, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.linear(duration: 0.1), value: timer.timeRemaining)

                    Text(timer.currentIntervalSelection.displayName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 115, height: 115)

            // Elapsed time and distance
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(timer.formattedElapsedTime)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }

                if gpsTrackingEnabled && timer.currentRouteData.hasValidRoute {
                    HStack(spacing: 2) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.system(size: 8))
                        Text(timer.currentRouteData.shortFormattedDistance)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .monospacedDigit()
                    }
                }
            }
            .foregroundStyle(.secondary)

            Spacer(minLength: 2)

            // Control buttons - compact
            HStack(spacing: 12) {
                // End button
                Button(action: { timer.stop() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                .controlSize(.mini)

                // Pause/Resume button
                Button(action: {
                    if timer.isRunning {
                        timer.pause()
                    } else {
                        timer.start()
                    }
                }) {
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.mini)
            }

            // Swipe hint (only on timer page when GPS enabled)
            if gpsTrackingEnabled {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                    Text("Map")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }

    // MARK: - Map Page

    private var mapPageView: some View {
        VStack(spacing: 4) {
            // Compact header with phase and time
            HStack {
                // Phase pill
                HStack(spacing: 3) {
                    Circle()
                        .fill(timer.currentPhase == .run ? Color.orange : Color.green)
                        .frame(width: 6, height: 6)
                    Text(timer.currentPhase.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(timer.currentPhase == .run ? Color.orange : Color.green)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.15), in: Capsule())

                Spacer()

                // Time
                Text(timer.formattedTime)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .padding(.horizontal, 4)

            // Live map
            WatchRouteMapView(
                routeData: timer.currentRouteData,
                isLive: true,
                currentPhase: timer.currentPhase
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Compact controls
            HStack(spacing: 16) {
                Button(action: { timer.stop() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                .controlSize(.mini)

                Button(action: {
                    if timer.isRunning {
                        timer.pause()
                    } else {
                        timer.start()
                    }
                }) {
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.mini)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }

    // MARK: - Computed Properties

    private var progress: Double {
        let elapsed = Double(timer.currentIntervalSeconds - timer.timeRemaining)
        return elapsed / Double(timer.currentIntervalSeconds)
    }
}

// MARK: - Preview

#Preview {
    let timer = WatchIntervalTimer()
    return WatchRunningView(timer: timer)
}
