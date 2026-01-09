import SwiftUI
import SwiftData
import RunWalkShared

/// Main view for the RunWalk interval timer app
/// Uses TabView with liquid glass effect for modern iOS 26 look
public struct ContentView: View {
    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var timer = IntervalTimer()
    @State private var selectedTab: Tab = .timer
    @State private var showRunCustomPicker = false
    @State private var showWalkCustomPicker = false

    /// Voice announcements setting (persisted)
    @AppStorage("voiceAnnouncementsEnabled") private var voiceEnabled = false
    /// Bells setting (persisted)
    @AppStorage("bellsEnabled") private var bellsEnabled = true
    /// Haptics setting (persisted)
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    /// GPS tracking setting (persisted)
    @AppStorage("gpsTrackingEnabled") private var gpsTrackingEnabled = false
    /// GPS accuracy mode (persisted)
    @AppStorage("gpsAccuracyMode") private var gpsAccuracyMode: GPSAccuracyMode = .balanced

    // MARK: - Tab Enum

    enum Tab: String {
        case timer = "RunWalk"
        case history = "History"
        case settings = "Settings"
    }

    // MARK: - Body

    public var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: RunWalk Timer
            timerTabView
                .tabItem {
                    Label("RunWalk", systemImage: "figure.run")
                }
                .tag(Tab.timer)

            // Tab 2: History
            WorkoutHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(Tab.history)

            // Tab 3: Settings
            SettingsTabView(
                voiceEnabled: $voiceEnabled,
                bellsEnabled: $bellsEnabled,
                hapticsEnabled: $hapticsEnabled,
                gpsTrackingEnabled: $gpsTrackingEnabled,
                gpsAccuracyMode: $gpsAccuracyMode
            )
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(.green)
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
        .onAppear {
            // Sync persisted settings to timer on appear
            timer.voiceAnnouncementsEnabled = voiceEnabled
            timer.bellsEnabled = bellsEnabled
            timer.hapticsEnabled = hapticsEnabled
            timer.gpsTrackingEnabled = gpsTrackingEnabled
            timer.gpsAccuracyMode = gpsAccuracyMode

            // Configure tab bar appearance for liquid glass effect
            configureTabBarAppearance()
        }
    }

    // MARK: - Tab Bar Appearance

    private func configureTabBarAppearance() {
        // Create translucent glass-like appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        // Glass effect: translucent background with blur
        appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterialDark)
        appearance.backgroundColor = UIColor.black.withAlphaComponent(0.2)

        // Apply to all tab bar states
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    // MARK: - Timer Tab View

    private var timerTabView: some View {
        ZStack {
            // Dark background like Apple Fitness
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if timer.isCountingDown {
                    countdownView
                } else if timer.isActive {
                    runningView
                } else {
                    selectionView
                }
            }
        }
        .sheet(isPresented: .init(
            get: { timer.showSummary },
            set: { if !$0 { timer.dismissSummary() } }
        )) {
            WorkoutSummaryView(
                stats: timer.workoutStats,
                savedToHealth: timer.workoutSavedToHealth
            ) {
                saveWorkoutToHistory()
                timer.dismissSummary()
            }
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
            savedToHealthKit: timer.workoutSavedToHealth
        )

        modelContext.insert(record)
    }

    // MARK: - Countdown View (3-2-1 Before Starting)

    private var countdownView: some View {
        VStack(spacing: 40) {
            Spacer()

            // "Get Ready" label
            Text("GET READY")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(2)

            // Large countdown number
            Text("\(timer.countdownValue)")
                .font(.system(size: 180, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeInOut(duration: 0.3), value: timer.countdownValue)

            Spacer()

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

            Spacer()
                .frame(height: 60)
        }
    }

    // MARK: - Selection View (Before Starting)

    private var selectionView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 30) {
                    // Header with colored title
                    HStack(spacing: 0) {
                        Text("Run")
                            .foregroundStyle(.orange)
                        Text("Walk")
                            .foregroundStyle(.green)
                    }
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .padding(.top, 20)

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
                                    isSelected: timer.runIntervalSelection.presetDuration == interval,
                                    color: .orange
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        timer.runIntervalSelection = .preset(interval)
                                    }
                                }
                            }
                        }

                        // Custom interval chip (full width)
                        CustomIntervalChip(
                            isSelected: timer.runIntervalSelection.isCustom,
                            customSeconds: timer.runIntervalSelection.isCustom ? timer.runIntervalSelection.seconds : nil,
                            color: .orange
                        ) {
                            showRunCustomPicker = true
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
                                    isSelected: timer.walkIntervalSelection.presetDuration == interval,
                                    color: .green
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        timer.walkIntervalSelection = .preset(interval)
                                    }
                                }
                            }
                        }

                        // Custom interval chip (full width)
                        CustomIntervalChip(
                            isSelected: timer.walkIntervalSelection.isCustom,
                            customSeconds: timer.walkIntervalSelection.isCustom ? timer.walkIntervalSelection.seconds : nil,
                            color: .green
                        ) {
                            showWalkCustomPicker = true
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .scrollIndicators(.hidden)

            // Start button (fixed at bottom, outside ScrollView)
            Button(action: { timer.start() }) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 22))
                    Text("Start")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(Color.green, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
            .padding(.bottom, 36)
        }
        .sheet(isPresented: $showRunCustomPicker) {
            CustomTimePickerSheet(
                selection: $timer.runIntervalSelection,
                color: .orange,
                title: "Run Interval"
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWalkCustomPicker) {
            CustomTimePickerSheet(
                selection: $timer.walkIntervalSelection,
                color: .green,
                title: "Walk Interval"
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Running View (Timer Active)

    private var runningView: some View {
        VStack(spacing: 0) {
            // Total elapsed time at top
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 14))
                Text(timer.formattedElapsedTime)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)
            .padding(.top, 20)

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

                    Text(timer.currentIntervalSelection.displayName)
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
        let elapsed = timer.currentIntervalSeconds - timer.timeRemaining
        return Double(elapsed) / Double(timer.currentIntervalSeconds)
    }

    // MARK: - Initialization

    public init() {}
}

// MARK: - Settings Tab View (Full Screen)

struct SettingsTabView: View {
    @Binding var voiceEnabled: Bool
    @Binding var bellsEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Binding var gpsTrackingEnabled: Bool
    @Binding var gpsAccuracyMode: GPSAccuracyMode

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                List {
                    // Audio Section
                    Section {
                        // Bells toggle
                        Toggle(isOn: $bellsEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.orange)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Bells")
                                        .font(.system(size: 17, weight: .regular))
                                    Text("Ding sound on phase change")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.green)

                        // Voice Announcements toggle
                        Toggle(isOn: $voiceEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.blue)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Voice Announcements")
                                        .font(.system(size: 17, weight: .regular))
                                    Text("Says \"Run\" or \"Walk\" on phase change")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.green)
                    } header: {
                        Text("Audio")
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    // Haptics Section
                    Section {
                        Toggle(isOn: $hapticsEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.purple)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Haptics")
                                        .font(.system(size: 17, weight: .regular))
                                    Text("Vibration on phase change")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.green)
                    } header: {
                        Text("Feedback")
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    // GPS/Location Section
                    Section {
                        // GPS Tracking toggle
                        Toggle(isOn: $gpsTrackingEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.blue)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("GPS Tracking")
                                        .font(.system(size: 17, weight: .regular))
                                    Text("Track route and distance during workouts")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.green)

                        // Accuracy Mode picker (only shown when GPS is enabled)
                        if gpsTrackingEnabled {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: gpsAccuracyMode.iconName)
                                        .font(.system(size: 18))
                                        .foregroundStyle(.cyan)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Accuracy")
                                            .font(.system(size: 17, weight: .regular))
                                        Text(gpsAccuracyMode.description)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Picker("Accuracy", selection: $gpsAccuracyMode) {
                                    ForEach(GPSAccuracyMode.allCases) { mode in
                                        Text(mode.displayName).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    } header: {
                        Text("Location")
                    } footer: {
                        if gpsTrackingEnabled {
                            Text("Higher accuracy uses more battery. Balanced is recommended for most workouts.")
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    // About Section
                    Section {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.4")
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.white.opacity(0.08))
                    } header: {
                        Text("About")
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
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
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? color : Color.white.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Interval Chip Component

/// A chip that shows "Custom" and displays the custom time when selected
struct CustomIntervalChip: View {
    let isSelected: Bool
    let customSeconds: Int?
    var color: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .medium))

                if let seconds = customSeconds, isSelected {
                    Text(formatCustomTime(seconds))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                } else {
                    Text("Custom")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
            }
            .foregroundStyle(isSelected ? .black : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color : Color.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    private func formatCustomTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes == 0 {
            return "\(seconds) sec"
        } else if seconds == 0 {
            return "\(minutes) min"
        } else {
            return "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Custom Time Picker Sheet

/// A sheet that allows the user to set a custom interval duration
struct CustomTimePickerSheet: View {
    @Binding var selection: IntervalSelection
    let color: Color
    let title: String

    @Environment(\.dismiss) private var dismiss

    @State private var minutes: Int = 1
    @State private var seconds: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 30) {
                    // Time display
                    Text(formattedTime)
                        .font(.system(size: 60, weight: .light, design: .rounded))
                        .foregroundStyle(color)
                        .monospacedDigit()

                    // Pickers
                    HStack(spacing: 20) {
                        // Minutes picker
                        VStack(spacing: 8) {
                            Text("Minutes")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)

                            Picker("Minutes", selection: $minutes) {
                                ForEach(0...30, id: \.self) { min in
                                    Text("\(min)").tag(min)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100, height: 150)
                            .clipped()
                        }

                        Text(":")
                            .font(.system(size: 40, weight: .light, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.top, 30)

                        // Seconds picker
                        VStack(spacing: 8) {
                            Text("Seconds")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)

                            Picker("Seconds", selection: $seconds) {
                                ForEach(0..<60, id: \.self) { sec in
                                    Text(String(format: "%02d", sec)).tag(sec)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100, height: 150)
                            .clipped()
                        }
                    }

                    // Validation message
                    if totalSeconds < IntervalSelection.minimumCustomSeconds {
                        Text("Minimum: 10 seconds")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.red)
                    } else if totalSeconds > IntervalSelection.maximumCustomSeconds {
                        Text("Maximum: 30 minutes")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.red)
                    }

                    Spacer()

                    // Apply button
                    Button(action: applySelection) {
                        Text("Apply")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(isValidSelection ? color : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!isValidSelection)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .padding(.top, 20)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .onAppear {
            // Initialize pickers from current selection if it's custom
            if case .custom(let secs) = selection {
                minutes = secs / 60
                seconds = secs % 60
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
        dismiss()
    }
}

// MARK: - Workout Summary View

struct WorkoutSummaryView: View {
    let stats: WorkoutStats
    var savedToHealth: Bool = false
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 30) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)

                    Text("Workout Complete!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    // HealthKit save indicator
                    if savedToHealth {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                            Text("Saved to Apple Health")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.pink)
                    }
                }
                .padding(.top, 40)

                // Stats Grid
                VStack(spacing: 20) {
                    // Total Time - Large display
                    VStack(spacing: 4) {
                        Text("Total Time")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(stats.formattedDuration)
                            .font(.system(size: 56, weight: .light, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Interval counts
                    HStack(spacing: 16) {
                        // Run intervals
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 10, height: 10)
                                Text("RUN")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.orange)
                            }
                            Text("\(stats.runIntervals)")
                                .font(.system(size: 36, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("intervals")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Walk intervals
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 10, height: 10)
                                Text("WALK")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.green)
                            }
                            Text("\(stats.walkIntervals)")
                                .font(.system(size: 36, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("intervals")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Total intervals
                    HStack {
                        Text("Total Intervals")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(stats.totalIntervals)")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)

                Spacer()

                // Done button
                Button(action: onDismiss) {
                    Text("Done")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

#Preview("Workout Summary") {
    WorkoutSummaryView(
        stats: WorkoutStats(
            totalDuration: 1234,
            runIntervals: 8,
            walkIntervals: 7,
            startTime: Date(),
            endTime: Date()
        ),
        onDismiss: {}
    )
}
