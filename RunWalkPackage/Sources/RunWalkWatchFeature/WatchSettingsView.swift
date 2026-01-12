import SwiftUI
import RunWalkShared

/// Settings view for the watchOS app
/// Compact design optimized for small watch screen
struct WatchSettingsView: View {
    // MARK: - Properties

    @Binding var voiceAnnouncementsEnabled: Bool
    @Binding var bellsEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Binding var gpsTrackingEnabled: Bool
    @Binding var gpsAccuracyMode: GPSAccuracyMode
    @Environment(\.dismiss) private var dismiss

    /// Manual age for heart rate zone calculation (fallback when HealthKit DOB unavailable)
    @AppStorage("manualAge") private var manualAge: Int = 30

    /// Callback to update the timer with the new age
    var onAgeChanged: ((Int) -> Void)?

    // MARK: - Body

    var body: some View {
        List {
            // Audio Section
            Section {
                // Bells toggle
                Toggle(isOn: $bellsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.orange)
                            Text("Bells")
                                .font(.system(size: 15, weight: .medium))
                        }
                        Text("Ding sounds")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.green)

                // Voice toggle
                Toggle(isOn: $voiceAnnouncementsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.blue)
                            Text("Voice")
                                .font(.system(size: 15, weight: .medium))
                        }
                        Text("Says Run/Walk")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.green)
            } header: {
                Text("Audio")
            }

            // Haptics Section
            Section {
                Toggle(isOn: $hapticsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.purple)
                            Text("Haptics")
                                .font(.system(size: 15, weight: .medium))
                        }
                        Text("Vibrations")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.green)
            } header: {
                Text("Feedback")
            }

            // GPS/Location Section
            Section {
                // GPS Tracking toggle
                Toggle(isOn: $gpsTrackingEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.blue)
                            Text("GPS")
                                .font(.system(size: 15, weight: .medium))
                        }
                        Text("Track route")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.green)

                // Accuracy Mode picker (only shown when GPS is enabled)
                if gpsTrackingEnabled {
                    Picker("Accuracy", selection: $gpsAccuracyMode) {
                        ForEach(GPSAccuracyMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }
            } header: {
                Text("Location")
            }

            // Heart Rate Zones Section
            Section {
                Picker(selection: $manualAge) {
                    ForEach(18..<81, id: \.self) { age in
                        Text("\(age)").tag(age)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.red)
                            Text("Age")
                                .font(.system(size: 15, weight: .medium))
                        }
                        Text("Max HR: \(220 - manualAge) bpm")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: manualAge) { _, newAge in
                    onAgeChanged?(newAge)
                }
            } header: {
                Text("HR Zones")
            } footer: {
                Text("Used for heart rate zone calculation")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WatchSettingsView(
            voiceAnnouncementsEnabled: .constant(false),
            bellsEnabled: .constant(true),
            hapticsEnabled: .constant(true),
            gpsTrackingEnabled: .constant(true),
            gpsAccuracyMode: .constant(.balanced),
            onAgeChanged: nil
        )
    }
}
