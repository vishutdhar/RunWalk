import SwiftUI
import AuthenticationServices
import RunWalkShared

/// View for managing Strava connection in Settings
public struct StravaSettingsView: View {
    @Environment(StravaManager.self) private var stravaManager

    public init() {}

    public var body: some View {
        Section {
            if stravaManager.isConnected {
                connectedView
            } else {
                disconnectedView
            }
        } header: {
            Text("Strava")
        } footer: {
            Text("Share your workouts to Strava to track your progress and connect with friends.")
        }
    }

    @ViewBuilder
    private var connectedView: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Connected to Strava")
            Spacer()
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
                }
                Text("Disconnect")
            }
        }
        .disabled(stravaManager.isLoading)
    }

    @ViewBuilder
    private var disconnectedView: some View {
        StravaConnectButton()
    }
}

/// Button to connect to Strava using ASWebAuthenticationSession
public struct StravaConnectButton: View {
    @Environment(StravaManager.self) private var stravaManager

    public init() {}

    public var body: some View {
        Button {
            // Use ConnectView to handle the auth session
        } label: {
            HStack {
                if stravaManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "link")
                }
                Text("Connect with Strava")
            }
        }
        .disabled(stravaManager.isLoading)
        .background(
            StravaAuthContextView()
        )
    }
}

/// Hidden view that provides ASWebAuthenticationPresentationContextProviding
private struct StravaAuthContextView: UIViewControllerRepresentable {
    @Environment(StravaManager.self) private var stravaManager

    func makeUIViewController(context: Context) -> StravaAuthViewController {
        let vc = StravaAuthViewController()
        vc.stravaManager = stravaManager
        return vc
    }

    func updateUIViewController(_ uiViewController: StravaAuthViewController, context: Context) {
        uiViewController.stravaManager = stravaManager
    }
}

/// UIViewController that handles the auth presentation context
@MainActor
class StravaAuthViewController: UIViewController, ASWebAuthenticationPresentationContextProviding {
    var stravaManager: StravaManager?

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        view.window ?? ASPresentationAnchor()
    }

    func startAuth() {
        guard let manager = stravaManager else { return }
        Task {
            await manager.connect(contextProvider: self)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Don't auto-start, user needs to tap the button
    }
}

// Improved connect button that works with the auth flow
public struct StravaConnectButtonImproved: View {
    @Environment(StravaManager.self) private var stravaManager
    @State private var showingAuth = false

    public init() {}

    public var body: some View {
        Button {
            showingAuth = true
        } label: {
            HStack {
                if stravaManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    // Strava orange color
                    Image(systemName: "link")
                        .foregroundStyle(Color(red: 252/255, green: 76/255, blue: 2/255))
                }
                Text("Connect with Strava")
            }
        }
        .disabled(stravaManager.isLoading)
        .sheet(isPresented: $showingAuth) {
            StravaAuthSheet()
        }
    }
}

/// Sheet that handles the Strava auth flow
private struct StravaAuthSheet: View {
    @Environment(StravaManager.self) private var stravaManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Strava logo placeholder
                ZStack {
                    Circle()
                        .fill(Color(red: 252/255, green: 76/255, blue: 2/255))
                        .frame(width: 80, height: 80)
                    Text("S")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("Connect to Strava")
                    .font(.title2.bold())

                Text("Share your Run-Walk workouts directly to Strava with GPS routes, distance, and stats.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if stravaManager.isLoading {
                    ProgressView("Connecting...")
                } else if let error = stravaManager.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Spacer()

                AuthButton()
                    .padding(.horizontal)
            }
            .padding(.top, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: stravaManager.isConnected) { _, isConnected in
                if isConnected {
                    dismiss()
                }
            }
        }
    }
}

/// The actual auth button that triggers ASWebAuthenticationSession
private struct AuthButton: UIViewControllerRepresentable {
    @Environment(StravaManager.self) private var stravaManager

    func makeUIViewController(context: Context) -> AuthButtonViewController {
        let vc = AuthButtonViewController()
        vc.stravaManager = stravaManager
        return vc
    }

    func updateUIViewController(_ uiViewController: AuthButtonViewController, context: Context) {
        uiViewController.stravaManager = stravaManager
    }
}

@MainActor
private class AuthButtonViewController: UIViewController, ASWebAuthenticationPresentationContextProviding {
    var stravaManager: StravaManager?

    private lazy var button: UIButton = {
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
        view.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            button.heightAnchor.constraint(equalToConstant: 50),
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor)
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

#Preview {
    NavigationStack {
        Form {
            StravaSettingsView()
        }
    }
    .environment(StravaManager())
}
