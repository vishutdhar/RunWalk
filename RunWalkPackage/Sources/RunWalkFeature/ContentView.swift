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
        ScrollView {
            VStack(spacing: 30) {
                Spacer()
                    .frame(height: 20)

                // App title
                Text("WalkRun")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                // RUN interval picker
                VStack(spacing: 16) {
                    HStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 12, height: 12)
                        Text("RUN")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                            .tracking(1)
                    }

                    // 3-column grid for RUN
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(IntervalDuration.allCases) { interval in
                            IntervalChip(
                                interval: interval,
                                isSelected: timer.runInterval == interval,
                                color: .orange
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    timer.runInterval = interval
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                // WALK interval picker
                VStack(spacing: 16) {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                        Text("WALK")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                            .tracking(1)
                    }

                    // 3-column grid for WALK
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(IntervalDuration.allCases) { interval in
                            IntervalChip(
                                interval: interval,
                                isSelected: timer.walkInterval == interval,
                                color: .green
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    timer.walkInterval = interval
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
                    .frame(height: 20)

                // Large circular start button (Apple Timer style)
                Button(action: { timer.start() }) {
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 160, height: 160)

                        Circle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 180, height: 180)

                        VStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 44, weight: .medium))
                            Text("Start")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.black)
                    }
                }
                .buttonStyle(.plain)

                Spacer()
                    .frame(height: 40)
            }
        }
        .scrollIndicators(.hidden)
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

                    Text(timer.currentInterval.displayName)
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
        let elapsed = timer.currentInterval.rawValue - timer.timeRemaining
        return Double(elapsed) / Double(timer.currentInterval.rawValue)
    }

    // MARK: - Initialization

    public init() {}
}

// MARK: - Interval Chip Component

struct IntervalChip: View {
    let interval: IntervalDuration
    let isSelected: Bool
    var color: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(interval.displayName)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? color : Color.white.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
