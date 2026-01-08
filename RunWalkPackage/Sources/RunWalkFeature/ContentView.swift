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

    /// Voice announcements setting (persisted)
    @AppStorage("voiceAnnouncementsEnabled") private var voiceEnabled = false
    /// Bells setting (persisted)
    @AppStorage("bellsEnabled") private var bellsEnabled = true
    /// Haptics setting (persisted)
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

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
                hapticsEnabled: $hapticsEnabled
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
        .onAppear {
            // Sync persisted settings to timer on appear
            timer.voiceAnnouncementsEnabled = voiceEnabled
            timer.bellsEnabled = bellsEnabled
            timer.hapticsEnabled = hapticsEnabled

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
            runInterval: timer.runInterval.rawValue,
            walkInterval: timer.walkInterval.rawValue,
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
                    .frame(minHeight: 20)

                // Circular start button
                Button(action: { timer.start() }) {
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 120, height: 120)

                        Circle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 140, height: 140)

                        VStack(spacing: 2) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 36, weight: .medium))
                            Text("Start")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.black)
                    }
                }
                .buttonStyle(.plain)

                Spacer()
                    .frame(minHeight: 20)
            }
        }
        .scrollIndicators(.hidden)
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

// MARK: - Settings Tab View (Full Screen)

struct SettingsTabView: View {
    @Binding var voiceEnabled: Bool
    @Binding var bellsEnabled: Bool
    @Binding var hapticsEnabled: Bool

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

                    // About Section
                    Section {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.3")
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
