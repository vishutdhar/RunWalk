import SwiftUI

/// Main view for the RunWalk interval timer app
/// Apple-style design: dark background, clean typography, minimal layout
public struct ContentView: View {
    // MARK: - State

    @State private var timer = IntervalTimer()

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Dark background like Apple Fitness
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if timer.isActive {
                    runningView
                } else {
                    selectionView
                }
            }
        }
    }

    // MARK: - Selection View (Before Starting)

    private var selectionView: some View {
        VStack(spacing: 40) {
            Spacer()

            // App title
            Text("RunWalk")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            // Interval picker - 2x3 grid for easy tapping
            VStack(spacing: 20) {
                Text("INTERVAL")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                // 2-column grid of interval options
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(IntervalDuration.allCases) { interval in
                        IntervalChip(
                            interval: interval,
                            isSelected: timer.selectedInterval == interval
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                timer.selectedInterval = interval
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            // Large circular start button (Apple Timer style)
            Button(action: { timer.start() }) {
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 180, height: 180)

                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 200, height: 200)

                    VStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 50, weight: .medium))
                        Text("Start")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                }
            }
            .buttonStyle(.plain)

            Spacer()
                .frame(height: 60)
        }
    }

    // MARK: - Running View (Timer Active)

    private var runningView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Phase indicator with color
            Text(timer.currentPhase.rawValue)
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(timer.currentPhase == .run ? Color.orange : Color.green)
                .contentTransition(.interpolate)
                .animation(.easeInOut(duration: 0.3), value: timer.currentPhase)

            Spacer()
                .frame(height: 20)

            // Large circular timer display (Apple Timer style)
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 280, height: 280)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        timer.currentPhase == .run ? Color.orange : Color.green,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 280, height: 280)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: progress)

                // Time display
                VStack(spacing: 8) {
                    Text(timer.formattedTime)
                        .font(.system(size: 80, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.linear(duration: 0.1), value: timer.timeRemaining)

                    Text(timer.selectedInterval.displayName)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Control buttons
            HStack(spacing: 60) {
                // Cancel button
                Button(action: { timer.stop() }) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 90, height: 90)

                        Text("Cancel")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)

                // Pause button
                Button(action: {
                    if timer.isRunning {
                        timer.pause()
                    } else {
                        timer.start()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 90, height: 90)

                        Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.black)
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()
                .frame(height: 60)
        }
    }

    // MARK: - Computed Properties

    private var progress: Double {
        let elapsed = timer.selectedInterval.rawValue - timer.timeRemaining
        return Double(elapsed) / Double(timer.selectedInterval.rawValue)
    }

    // MARK: - Initialization

    public init() {}
}

// MARK: - Interval Chip Component

struct IntervalChip: View {
    let interval: IntervalDuration
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(interval.displayName)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? Color.white : Color.white.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
