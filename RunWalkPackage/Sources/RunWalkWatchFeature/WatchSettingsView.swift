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
            gpsAccuracyMode: .constant(.balanced)
        )
    }
}
