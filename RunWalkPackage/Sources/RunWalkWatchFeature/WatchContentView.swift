import SwiftUI
import SwiftData
import RunWalkShared

/// Main content view for the watchOS app
/// Shows selection screen, active workout, or summary based on timer state
public struct WatchContentView: View {
    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    /// The interval timer - can be injected externally for deep link support
    @State private var timer: WatchIntervalTimer
    @State private var showHistory = false
    @State private var showSettings = false

    // MARK: - Initialization

    /// Creates a WatchContentView with an optional external timer
    /// - Parameter timer: Optional timer instance. If nil, creates a new one.
    public init(timer: WatchIntervalTimer? = nil) {
        _timer = State(initialValue: timer ?? WatchIntervalTimer())
    }

    /// Voice announcements setting (persisted)
    @AppStorage("voiceAnnouncementsEnabled") private var voiceEnabled = false

    /// Bells setting (persisted)
    @AppStorage("bellsEnabled") private var bellsEnabled = true

    /// Haptics setting (persisted)
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    /// GPS tracking setting (persisted) - ON by default for route tracking
    @AppStorage("gpsTrackingEnabled") private var gpsTrackingEnabled = true

    /// GPS accuracy mode (persisted)
    @AppStorage("gpsAccuracyMode") private var gpsAccuracyMode: GPSAccuracyMode = .balanced

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
                    hapticsEnabled: $hapticsEnabled,
                    gpsTrackingEnabled: $gpsTrackingEnabled,
                    gpsAccuracyMode: $gpsAccuracyMode,
                    onAgeChanged: { newAge in
                        timer.setManualAge(newAge)
                    }
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
        .onChange(of: gpsTrackingEnabled) { _, newValue in
            timer.gpsTrackingEnabled = newValue
        }
        .onChange(of: gpsAccuracyMode) { _, newValue in
            timer.gpsAccuracyMode = newValue
        }
        .task {
            // Sync persisted settings to timer on launch
            timer.voiceAnnouncementsEnabled = voiceEnabled
            timer.bellsEnabled = bellsEnabled
            timer.hapticsEnabled = hapticsEnabled
            timer.gpsTrackingEnabled = gpsTrackingEnabled
            timer.gpsAccuracyMode = gpsAccuracyMode
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
            runInterval: timer.runInterval,
            walkInterval: timer.walkInterval,
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
                            Text(timer.runIntervalSelection.displayName)
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
                            Text(timer.walkIntervalSelection.displayName)
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
                    selection: $timer.runIntervalSelection,
                    isPresented: $showRunPicker
                )
            }
            .navigationDestination(isPresented: $showWalkPicker) {
                IntervalPickerView(
                    title: "Walk Interval",
                    color: .green,
                    selection: $timer.walkIntervalSelection,
                    isPresented: $showWalkPicker
                )
            }
        }
    }

}

// MARK: - Interval Picker View

/// A picker view that shows preset durations and a custom option
struct IntervalPickerView: View {
    let title: String
    let color: Color
    @Binding var selection: IntervalSelection
    @Binding var isPresented: Bool
    @State private var showCustomPicker = false

    var body: some View {
        List {
            // Preset options
            ForEach(IntervalDuration.allCases) { duration in
                Button {
                    selection = .preset(duration)
                    isPresented = false  // Auto-dismiss on selection
                } label: {
                    HStack {
                        Text(duration.displayName)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                        Spacer()
                        if selection.presetDuration == duration {
                            Image(systemName: "checkmark")
                                .foregroundStyle(color)
                        }
                    }
                }
                .listRowBackground(
                    selection.presetDuration == duration
                        ? color.opacity(0.2)
                        : Color.clear
                )
            }

            // Custom option
            Button {
                showCustomPicker = true
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Custom")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                    Spacer()
                    if selection.isCustom {
                        Text(selection.displayName)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        Image(systemName: "checkmark")
                            .foregroundStyle(color)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listRowBackground(
                selection.isCustom
                    ? color.opacity(0.2)
                    : Color.clear
            )
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showCustomPicker) {
            WatchCustomTimePickerView(
                selection: $selection,
                color: color,
                onDismiss: {
                    showCustomPicker = false
                    isPresented = false
                }
            )
        }
    }
}

// MARK: - Watch Custom Time Picker View

/// A view for setting custom interval duration on watchOS
struct WatchCustomTimePickerView: View {
    @Binding var selection: IntervalSelection
    let color: Color
    let onDismiss: () -> Void

    @State private var minutes: Int = 1
    @State private var seconds: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            // Time display
            Text(formattedTime)
                .font(.system(size: 36, weight: .light, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()

            // Pickers in a compact layout
            HStack(spacing: 4) {
                // Minutes
                Picker("Min", selection: $minutes) {
                    ForEach(0...30, id: \.self) { min in
                        Text("\(min)m").tag(min)
                    }
                }
                .frame(width: 70)

                Text(":")
                    .font(.system(size: 20, weight: .light, design: .rounded))
                    .foregroundStyle(.secondary)

                // Seconds
                Picker("Sec", selection: $seconds) {
                    ForEach([0, 15, 30, 45], id: \.self) { sec in
                        Text(String(format: "%02ds", sec)).tag(sec)
                    }
                }
                .frame(width: 70)
            }

            // Validation
            if !isValidSelection {
                Text("Min: 10s, Max: 30m")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.red)
            }

            // Apply button
            Button(action: applySelection) {
                Text("Apply")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isValidSelection ? color : Color.gray, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!isValidSelection)
        }
        .padding(.horizontal, 8)
        .navigationTitle("Custom")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize from current selection if custom
            if case .custom(let secs) = selection {
                minutes = secs / 60
                // Round seconds to nearest 15
                let rawSeconds = secs % 60
                seconds = [0, 15, 30, 45].min(by: { abs($0 - rawSeconds) < abs($1 - rawSeconds) }) ?? 0
            }
        }
    }

    private var totalSeconds: Int {
        minutes * 60 + seconds
    }

    private var formattedTime: String {
        String(format: "%d:%02d", minutes, seconds)
    }

    private var isValidSelection: Bool {
        totalSeconds >= IntervalSelection.minimumCustomSeconds &&
        totalSeconds <= IntervalSelection.maximumCustomSeconds
    }

    private func applySelection() {
        // Use smartSelection to automatically use preset if time matches
        selection = IntervalSelection.smartSelection(seconds: totalSeconds)
        onDismiss()
    }
}

// MARK: - Preview

#Preview {
    WatchContentView()
}
