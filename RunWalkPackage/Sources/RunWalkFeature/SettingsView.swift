import SwiftUI

/// Settings view for the iOS app
/// Clean, focused settings with toggle options
struct SettingsView: View {
    // MARK: - Properties

    @Binding var voiceAnnouncementsEnabled: Bool
    @Binding var bellsEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

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
                        Toggle(isOn: $voiceAnnouncementsEnabled) {
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
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(
        voiceAnnouncementsEnabled: .constant(false),
        bellsEnabled: .constant(true),
        hapticsEnabled: .constant(true)
    )
}
