import SwiftUI
import RunWalkShared

/// Settings view for the iOS app
/// Clean, focused settings with toggle options
struct SettingsView: View {
    // MARK: - Properties

    @Binding var voiceAnnouncementsEnabled: Bool
    @Binding var bellsEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(StravaManager.self) private var stravaManager

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

                    // Strava Section
                    Section {
                        StravaSettingsRow()
                    } header: {
                        Text("Integrations")
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

// MARK: - Strava Settings Row

/// Row for Strava connection in settings
private struct StravaSettingsRow: View {
    @Environment(StravaManager.self) private var stravaManager
    @State private var showingStravaSheet = false

    var body: some View {
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
        .sheet(isPresented: $showingStravaSheet) {
            StravaConnectionSheet()
        }
    }
}

/// Sheet for connecting/disconnecting Strava
private struct StravaConnectionSheet: View {
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

        StravaConnectAuthButton()
            .padding(.horizontal)
    }
}

/// Button that handles the ASWebAuthenticationSession
private struct StravaConnectAuthButton: UIViewControllerRepresentable {
    @Environment(StravaManager.self) private var stravaManager

    func makeUIViewController(context: Context) -> StravaConnectViewController {
        let vc = StravaConnectViewController()
        vc.stravaManager = stravaManager
        return vc
    }

    func updateUIViewController(_ uiViewController: StravaConnectViewController, context: Context) {
        uiViewController.stravaManager = stravaManager
    }
}

@MainActor
private class StravaConnectViewController: UIViewController {
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
}

import AuthenticationServices

extension StravaConnectViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        view.window ?? ASPresentationAnchor()
    }
}

#Preview {
    SettingsView(
        voiceAnnouncementsEnabled: .constant(false),
        bellsEnabled: .constant(true),
        hapticsEnabled: .constant(true)
    )
    .environment(StravaManager())
}
