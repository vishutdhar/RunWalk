import SwiftUI
import SwiftData
import RunWalkShared

/// Main content view for the watchOS app
/// Shows selection screen, active workout, or summary based on timer state
public struct WatchContentView: View {
    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var timer = WatchIntervalTimer()
    @State private var showHistory = false
    @State private var showSettings = false

    /// Voice announcements setting (persisted)
    @AppStorage("voiceAnnouncementsEnabled") private var voiceEnabled = false

    /// Bells setting (persisted)
    @AppStorage("bellsEnabled") private var bellsEnabled = true

    /// Haptics setting (persisted)
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    // MARK: - Body

    public var body: some View {
        Group {
            if timer.showSummary {
                WatchSummaryView(
                    stats: timer.workoutStats,
                    onDismiss: {
                        saveWorkoutToHistory()
                        timer.dismissSummary()
                    }
                )
            } else if timer.isCountingDown {
                countdownView
            } else if timer.isActive {
                WatchRunningView(timer: timer)
            } else {
                selectionView
            }
        }
        .sheet(isPresented: $showHistory) {
            WatchWorkoutHistoryView()
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                WatchSettingsView(
                    voiceAnnouncementsEnabled: $voiceEnabled,
                    bellsEnabled: $bellsEnabled,
                    hapticsEnabled: $hapticsEnabled
                )
            }
        }
        .onChange(of: voiceEnabled) { _, newValue in
            timer.voiceAnnouncementsEnabled = newValue
        }
        .onChange(of: bellsEnabled) { _, newValue in
            timer.bellsEnabled = newValue
        }
        .onChange(of: hapticsEnabled) { _, newValue in
            timer.hapticsEnabled = newValue
        }
        .task {
            // Sync persisted settings to timer on launch
            timer.voiceAnnouncementsEnabled = voiceEnabled
            timer.bellsEnabled = bellsEnabled
            timer.hapticsEnabled = hapticsEnabled
            // Request HealthKit authorization on launch
            _ = await timer.requestHealthKitAuthorization()
        }
    }

    // MARK: - Save Workout

    private func saveWorkoutToHistory() {
        // Only save if we have valid workout data
        guard timer.workoutStats.totalDuration > 0 else { return }

        let record = WorkoutRecord(
            from: timer.workoutStats,
            runInterval: timer.runInterval.rawValue,
            walkInterval: timer.walkInterval.rawValue,
            savedToHealthKit: true  // Watch workouts are always saved to HealthKit
        )

        modelContext.insert(record)
    }

    // MARK: - Countdown View

    private var countdownView: some View {
        VStack(spacing: 8) {
            Text("GET READY")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Text("\(timer.countdownValue)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeInOut(duration: 0.3), value: timer.countdownValue)

            Button("Cancel") {
                timer.stop()
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        }
    }

    // MARK: - Selection View

    @State private var showRunPicker = false
    @State private var showWalkPicker = false

    private var selectionView: some View {
        NavigationStack {
            VStack(spacing: 8) {
                // RUN interval picker
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        Text("RUN")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                    }

                    Button {
                        showRunPicker = true
                    } label: {
                        HStack {
                            Text(timer.runInterval.displayName)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }

                // WALK interval picker
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("WALK")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                    }

                    Button {
                        showWalkPicker = true
                    } label: {
                        HStack {
                            Text(timer.walkInterval.displayName)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }

                // Start button
                Button(action: { timer.start() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                        Text("Start")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.green, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
            .padding(.top, 8)
            .navigationTitle {
                HStack(spacing: 0) {
                    Text("Run")
                        .foregroundStyle(.orange)
                    Text("Walk")
                        .foregroundStyle(.green)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 12))
                    }
                }
            }
            .navigationDestination(isPresented: $showRunPicker) {
                IntervalPickerView(
                    title: "Run Interval",
                    color: .orange,
                    selection: $timer.runInterval,
                    isPresented: $showRunPicker
                )
            }
            .navigationDestination(isPresented: $showWalkPicker) {
                IntervalPickerView(
                    title: "Walk Interval",
                    color: .green,
                    selection: $timer.walkInterval,
                    isPresented: $showWalkPicker
                )
            }
        }
    }

    // MARK: - Initialization

    public init() {}
}

// MARK: - Interval Picker View

/// A picker view that auto-dismisses when a selection is made
struct IntervalPickerView: View {
    let title: String
    let color: Color
    @Binding var selection: IntervalDuration
    @Binding var isPresented: Bool

    var body: some View {
        List {
            ForEach(IntervalDuration.allCases) { duration in
                Button {
                    selection = duration
                    isPresented = false  // Auto-dismiss on selection
                } label: {
                    HStack {
                        Text(duration.displayName)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                        Spacer()
                        if selection == duration {
                            Image(systemName: "checkmark")
                                .foregroundStyle(color)
                        }
                    }
                }
                .listRowBackground(
                    selection == duration
                        ? color.opacity(0.2)
                        : Color.clear
                )
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    WatchContentView()
}
