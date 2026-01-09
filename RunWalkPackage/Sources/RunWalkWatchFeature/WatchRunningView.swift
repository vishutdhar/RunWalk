import SwiftUI
import RunWalkShared

/// Active workout view for watchOS
/// Shows phase, countdown timer, and controls
struct WatchRunningView: View {
    // MARK: - Properties

    @Bindable var timer: WatchIntervalTimer

    // MARK: - Body

    var body: some View {
        VStack(spacing: 2) {
            // Phase indicator
            Text(timer.currentPhase.rawValue)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(timer.currentPhase == .run ? Color.orange : Color.green)
                .contentTransition(.interpolate)
                .animation(.easeInOut(duration: 0.3), value: timer.currentPhase)

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

            // Elapsed time
            HStack(spacing: 3) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                Text(timer.formattedElapsedTime)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
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
