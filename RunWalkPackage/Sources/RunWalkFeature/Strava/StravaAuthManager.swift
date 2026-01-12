import Foundation
import AuthenticationServices
import RunWalkShared

/// Handles Strava OAuth authentication flow
@MainActor
public final class StravaAuthManager: NSObject {

    private var authSession: ASWebAuthenticationSession?
    private var presentationContextProvider: ASWebAuthenticationPresentationContextProviding?

    private let apiClient: StravaAPIClient
    private let tokenStorage: StravaTokenStorage

    public init(
        apiClient: StravaAPIClient = StravaAPIClient(),
        tokenStorage: StravaTokenStorage = .shared
    ) {
        self.apiClient = apiClient
        self.tokenStorage = tokenStorage
        super.init()
    }

    // MARK: - Authorization

    /// Starts the OAuth authorization flow
    /// - Parameter contextProvider: Presentation context for the auth sheet
    /// - Returns: The authenticated athlete
    public func authorize(contextProvider: ASWebAuthenticationPresentationContextProviding) async throws -> StravaAthlete {
        self.presentationContextProvider = contextProvider

        // Build authorization URL
        var components = URLComponents(string: StravaConfig.authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: StravaConfig.clientId),
            URLQueryItem(name: "redirect_uri", value: StravaConfig.callbackURL),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope", value: StravaConfig.scope)
        ]

        guard let authURL = components.url else {
            throw StravaError.invalidResponse
        }

        // Start auth session
        let callbackURL = try await startAuthSession(url: authURL)

        // Extract code from callback
        guard let code = extractCode(from: callbackURL) else {
            throw StravaError.authorizationDenied
        }

        // Exchange code for tokens
        let tokenResponse = try await apiClient.exchangeCodeForTokens(code: code)

        // Store tokens
        try await tokenStorage.saveTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: tokenResponse.expiresAtDate,
            athleteId: tokenResponse.athlete?.id ?? 0
        )

        guard let athlete = tokenResponse.athlete else {
            throw StravaError.invalidResponse
        }

        return athlete
    }

    /// Gets a valid access token, refreshing if needed
    public func getValidAccessToken() async throws -> String {
        guard await tokenStorage.hasTokens else {
            throw StravaError.notAuthenticated
        }

        // Check if token needs refresh
        if await tokenStorage.isTokenExpired() {
            try await refreshTokens()
        }

        guard let token = await tokenStorage.getAccessToken() else {
            throw StravaError.notAuthenticated
        }

        return token
    }

    /// Refreshes the access token
    private func refreshTokens() async throws {
        guard let refreshToken = await tokenStorage.getRefreshToken() else {
            throw StravaError.notAuthenticated
        }

        let tokenResponse = try await apiClient.refreshTokens(refreshToken: refreshToken)

        // Get athlete ID from response, or fall back to stored ID
        let existingAthleteId = await tokenStorage.getAthleteId()
        let athleteId = tokenResponse.athlete?.id ?? existingAthleteId ?? 0

        try await tokenStorage.saveTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: tokenResponse.expiresAtDate,
            athleteId: athleteId
        )
    }

    /// Disconnects from Strava
    public func disconnect() async throws {
        if let token = await tokenStorage.getAccessToken() {
            try? await apiClient.deauthorize(accessToken: token)
        }
        await tokenStorage.clearAll()
    }

    // MARK: - Private Helpers

    private func startAuthSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: StravaConfig.callbackURLScheme
            ) { callbackURL, error in
                if let error = error as? ASWebAuthenticationSessionError {
                    if error.code == .canceledLogin {
                        continuation.resume(throwing: StravaError.authorizationDenied)
                    } else {
                        continuation.resume(throwing: StravaError.networkError(error.localizedDescription))
                    }
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: StravaError.invalidResponse)
                }
            }

            session.presentationContextProvider = presentationContextProvider
            session.prefersEphemeralWebBrowserSession = false

            self.authSession = session
            session.start()
        }
    }

    private func extractCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
              let code = codeItem.value else {
            return nil
        }
        return code
    }
}
