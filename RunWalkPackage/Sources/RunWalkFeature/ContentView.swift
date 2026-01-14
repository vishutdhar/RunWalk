import SwiftUI
import SwiftData
import MapKit
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
    @State private var workoutPage: WorkoutPage = .timer

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

    // MARK: - Tab Enum

    enum Tab: String {
        case timer = "RunWalk"
        case presets = "Presets"
        case history = "History"
        case settings = "Settings"
    }

    /// Pages available during an active workout (swipeable)
    enum WorkoutPage: Int, CaseIterable {
        case timer = 0
        case map = 1
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

            // Tab 2: Presets
            PresetsView(onPresetSelected: { preset in
                applyPreset(preset)
            })
                .tabItem {
                    Label("Presets", systemImage: "list.bullet.rectangle.portrait")
                }
                .tag(Tab.presets)

            // Tab 3: History
            WorkoutHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(Tab.history)

            // Tab 4: Settings
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
            set: { if !$0 {
                // Save workout to history when sheet is dismissed (handles swipe-dismiss)
                // The guard in saveWorkoutToHistory prevents double-save since
                // totalDuration becomes 0 after dismissSummary resets the data
                saveWorkoutToHistory()
                timer.dismissSummary()
            } }
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
        guard timer.workoutStats.totalDuration > 0 else {
            print("[SaveWorkout] Skipped - totalDuration is 0")
            return
        }

        let record = WorkoutRecord(
            from: timer.workoutStats,
            runInterval: timer.runInterval,
            walkInterval: timer.walkInterval,
            savedToHealthKit: timer.workoutSavedToHealth
        )

        modelContext.insert(record)

        // Explicitly save to ensure persistence
        do {
            try modelContext.save()
            print("[SaveWorkout] Saved workout: duration=\(record.duration)s, intervals=\(record.totalIntervals)")
        } catch {
            print("[SaveWorkout] Error saving: \(error)")
        }
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
    // Uses swipeable pages: Timer (default) ←→ Live Map (when GPS enabled)
    // Follows Apple's Workout app pattern of swipeable metric screens

    private var runningView: some View {
        Group {
            if gpsTrackingEnabled {
                // Swipeable pages when GPS is enabled
                TabView(selection: $workoutPage) {
                    timerPageView
                        .tag(WorkoutPage.timer)

                    liveMapPageView
                        .tag(WorkoutPage.map)
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .indexViewStyle(.page(backgroundDisplayMode: .automatic))
                .onAppear {
                    // Reset to timer page when workout starts
                    workoutPage = .timer
                }
            } else {
                // Just the timer when GPS is disabled
                timerPageView
            }
        }
    }

    // MARK: - Timer Page (Main workout display)

    private var timerPageView: some View {
        VStack(spacing: 0) {
            // Total elapsed time at top
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 14))
                Text(timer.formattedElapsedTime)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .monospacedDigit()

                // GPS indicator when tracking
                if gpsTrackingEnabled {
                    Spacer()
                        .frame(width: 12)
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                }
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

            // Distance indicator (when GPS enabled and has data)
            if gpsTrackingEnabled && timer.currentRouteData.hasValidRoute {
                HStack(spacing: 4) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: 12))
                    Text(timer.currentRouteData.formattedDistance)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
                .padding(.top, 12)
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

            // Page hint (swipe for map)
            if gpsTrackingEnabled {
                HStack(spacing: 4) {
                    Text("Swipe for map")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.tertiary)
                .padding(.top, 16)
            }

            Spacer()
                .frame(height: 40)
        }
    }

    // MARK: - Live Map Page (GPS Route Display)

    private var liveMapPageView: some View {
        VStack(spacing: 0) {
            // Header with phase and time
            HStack {
                // Phase pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(timer.currentPhase == .run ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    Text(timer.currentPhase.rawValue.uppercased())
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(timer.currentPhase == .run ? Color.orange : Color.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1), in: Capsule())

                Spacer()

                // Time remaining
                Text(timer.formattedTime)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Live map - wrapped to ensure swipe gestures pass through for page navigation
            RouteMapView(
                routeData: timer.currentRouteData,
                isLive: true,
                currentPhase: timer.currentPhase,
                showDistance: true,
                currentLocation: timer.currentLocation
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            // Ensure this area doesn't block page swipe gestures
            .contentShape(Rectangle())
            .allowsHitTesting(false)

            // Control buttons (same as timer page for consistency)
            HStack(spacing: 60) {
                // Cancel button
                Button(action: { timer.stop() }) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 70, height: 70)

                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
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
                            .frame(width: 70, height: 70)

                        Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.black)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Computed Properties

    private var progress: Double {
        let elapsed = timer.currentIntervalSeconds - timer.timeRemaining
        return Double(elapsed) / Double(timer.currentIntervalSeconds)
    }

    // MARK: - Preset Actions

    /// Applies a workout preset by setting the run/walk intervals, switching to timer tab, and starting the workout
    private func applyPreset(_ preset: WorkoutPreset) {
        // Apply the preset intervals
        timer.runIntervalSelection = IntervalSelection.smartSelection(seconds: preset.runIntervalSeconds)
        timer.walkIntervalSelection = IntervalSelection.smartSelection(seconds: preset.walkIntervalSeconds)

        // Switch to timer tab
        selectedTab = .timer

        // Start the workout after a brief delay to allow tab switch animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            timer.start()
        }
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

    @Environment(StravaManager.self) private var stravaManager
    @State private var showingStravaSheet = false

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

                    // Strava Integration Section
                    Section {
                        Button {
                            showingStravaSheet = true
                        } label: {
                            HStack(spacing: 12) {
                                // Strava icon (orange circle with S)
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 252/255, green: 76/255, blue: 2/255))
                                        .frame(width: 28, height: 28)
                                    Text("S")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Strava")
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundStyle(.primary)

                                    Text(stravaManager.isConnected ? "Connected" : "Share workouts to Strava")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if stravaManager.isConnected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Integrations")
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    // About Section
                    Section {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.5")
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
            .sheet(isPresented: $showingStravaSheet) {
                StravaConnectionSheetView()
            }
        }
    }
}

// MARK: - Strava Connection Sheet

/// Sheet for connecting/disconnecting Strava in Settings
private struct StravaConnectionSheetView: View {
    @Environment(StravaManager.self) private var stravaManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Strava logo
                ZStack {
                    Circle()
                        .fill(Color(red: 252/255, green: 76/255, blue: 2/255))
                        .frame(width: 80, height: 80)
                    Text("S")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 40)

                if stravaManager.isConnected {
                    connectedContent
                } else {
                    disconnectedContent
                }

                Spacer()
            }
            .navigationTitle("Strava")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var connectedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Connected to Strava")
                .font(.title2.bold())

            Text("Your workouts with GPS routes can now be shared to Strava from the workout detail view.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }

        Button(role: .destructive) {
            Task {
                await stravaManager.disconnect()
            }
        } label: {
            HStack {
                if stravaManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }
                Text("Disconnect from Strava")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(stravaManager.isLoading)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var disconnectedContent: some View {
        VStack(spacing: 16) {
            Text("Connect to Strava")
                .font(.title2.bold())

            Text("Share your Run-Walk workouts directly to Strava with GPS routes, distance, and stats.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let error = stravaManager.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
        }

        StravaConnectAuthButtonView()
            .padding(.horizontal)
    }
}

// MARK: - Strava Connect Auth Button

/// UIViewControllerRepresentable for ASWebAuthenticationSession
private struct StravaConnectAuthButtonView: UIViewControllerRepresentable {
    @Environment(StravaManager.self) private var stravaManager

    func makeUIViewController(context: Context) -> StravaConnectButtonViewController {
        let vc = StravaConnectButtonViewController()
        vc.stravaManager = stravaManager
        return vc
    }

    func updateUIViewController(_ uiViewController: StravaConnectButtonViewController, context: Context) {
        uiViewController.stravaManager = stravaManager
    }
}

import AuthenticationServices

@MainActor
private class StravaConnectButtonViewController: UIViewController, ASWebAuthenticationPresentationContextProviding {
    var stravaManager: StravaManager?

    private lazy var connectButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = UIColor(red: 252/255, green: 76/255, blue: 2/255, alpha: 1)
        config.baseForegroundColor = .white
        config.title = "Connect with Strava"
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)

        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(connectButton)
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            connectButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            connectButton.topAnchor.constraint(equalTo: view.topAnchor),
            connectButton.heightAnchor.constraint(equalToConstant: 50),
            connectButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            connectButton.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    @objc private func connectTapped() {
        guard let manager = stravaManager else { return }
        Task {
            await manager.connect(contextProvider: self)
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        view.window ?? ASPresentationAnchor()
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
        .environment(StravaManager())
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
