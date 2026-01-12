# Strava Integration Implementation Plan

## Overview

This document outlines the complete implementation plan for adding Strava integration to RunWalk. Users will be able to connect their Strava account and share workouts with GPS route data.

**Confidence Level: 95%**

---

## Prerequisites (Before Coding)

### 1. Register Strava Application
- Go to [strava.com/settings/api](https://strava.com/settings/api)
- Create new application with:
  - **Application Name:** RunWalk
  - **Category:** Training
  - **Club:** (leave blank)
  - **Website:** Your website or App Store link
  - **Authorization Callback Domain:** `runwalk` (for deep link scheme)
  - **Description:** Run-walk interval timer with GPS tracking
- Save your **Client ID** and **Client Secret**

### 2. Download Brand Assets
- Download from [developers.strava.com/guidelines](https://developers.strava.com/guidelines/)
- Required assets:
  - "Connect with Strava" button (orange, 48px height)
  - "Powered by Strava" logo
- Add to `RunWalk/Assets.xcassets/`

### 3. Decision Point
**Question:** Auto-upload or manual share?
- **Option A (Recommended):** Manual "Share to Strava" button after workout
  - User has control over what gets shared
  - No surprise uploads
  - Simpler error handling
- **Option B:** Auto-upload when Strava is connected
  - More seamless experience
  - Need to handle failures gracefully

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  RunWalkPackage/Sources/RunWalkShared/                          │
│  ├── Strava/                                                    │
│  │   ├── StravaConfig.swift         # Client ID, URLs, scopes   │
│  │   ├── StravaModels.swift         # Token, Athlete, Upload    │
│  │   └── GPXGenerator.swift         # RouteData → GPX string    │
│  └── WorkoutRecord.swift            # Add stravaActivityId      │
├─────────────────────────────────────────────────────────────────┤
│  RunWalkPackage/Sources/RunWalkFeature/                         │
│  ├── Strava/                                                    │
│  │   ├── StravaManager.swift        # Main integration manager  │
│  │   ├── StravaAuthManager.swift    # OAuth flow handling       │
│  │   ├── StravaAPIClient.swift      # Network requests          │
│  │   └── StravaTokenStorage.swift   # Keychain storage          │
│  └── Views/                                                     │
│      ├── StravaSettingsView.swift   # Connect/disconnect UI     │
│      └── StravaShareButton.swift    # Share to Strava button    │
├─────────────────────────────────────────────────────────────────┤
│  RunWalk/                                                       │
│  └── Info.plist                     # URL schemes, queries      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Foundation (Shared Code)

### 1.1 Add CoreGPX Dependency

**File:** `RunWalkPackage/Package.swift`

```swift
// Add to dependencies array
dependencies: [
    .package(url: "https://github.com/vincentneo/CoreGPX.git", from: "0.9.0")
],

// Add to RunWalkShared target
.target(
    name: "RunWalkShared",
    dependencies: ["CoreGPX"],
    path: "Sources/RunWalkShared"
),
```

### 1.2 Create Strava Configuration

**New File:** `RunWalkPackage/Sources/RunWalkShared/Strava/StravaConfig.swift`

```swift
import Foundation

public enum StravaConfig {
    // MARK: - API Credentials (Replace with your values)
    public static let clientId = "YOUR_CLIENT_ID"
    public static let clientSecret = "YOUR_CLIENT_SECRET"

    // MARK: - URLs
    public static let authorizeURL = "https://www.strava.com/oauth/mobile/authorize"
    public static let tokenURL = "https://www.strava.com/oauth/token"
    public static let deauthorizeURL = "https://www.strava.com/oauth/deauthorize"
    public static let uploadURL = "https://www.strava.com/api/v3/uploads"
    public static let baseAPIURL = "https://www.strava.com/api/v3"

    // MARK: - OAuth
    public static let callbackURLScheme = "runwalk"
    public static let callbackURL = "runwalk://strava-callback"
    public static let scope = "activity:write"

    // MARK: - Keychain
    public static let keychainService = "com.vishutdhar.RunWalk.Strava"
    public static let accessTokenKey = "strava_access_token"
    public static let refreshTokenKey = "strava_refresh_token"
    public static let expiresAtKey = "strava_expires_at"
    public static let athleteIdKey = "strava_athlete_id"
}
```

### 1.3 Create Strava Models

**New File:** `RunWalkPackage/Sources/RunWalkShared/Strava/StravaModels.swift`

```swift
import Foundation

// MARK: - Token Response
public struct StravaTokenResponse: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Int
    public let athlete: StravaAthlete?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case athlete
    }

    public var expiresAtDate: Date {
        Date(timeIntervalSince1970: TimeInterval(expiresAt))
    }

    public var isExpired: Bool {
        Date() >= expiresAtDate
    }
}

// MARK: - Athlete
public struct StravaAthlete: Codable, Sendable {
    public let id: Int
    public let firstName: String?
    public let lastName: String?
    public let profileMedium: String?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "firstname"
        case lastName = "lastname"
        case profileMedium = "profile_medium"
    }

    public var displayName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }
}

// MARK: - Upload Response
public struct StravaUploadResponse: Codable, Sendable {
    public let id: Int
    public let status: String
    public let activityId: Int?
    public let error: String?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case activityId = "activity_id"
        case error
    }

    public var isProcessing: Bool {
        activityId == nil && error == nil
    }

    public var isComplete: Bool {
        activityId != nil
    }

    public var hasFailed: Bool {
        error != nil
    }
}

// MARK: - Upload Status
public enum StravaUploadStatus: Sendable {
    case idle
    case uploading
    case processing(uploadId: Int)
    case success(activityId: Int)
    case failed(error: String)
}

// MARK: - Strava Error
public enum StravaError: Error, LocalizedError, Sendable {
    case notAuthenticated
    case tokenExpired
    case tokenRefreshFailed
    case uploadFailed(String)
    case networkError(String)
    case invalidResponse
    case noRouteData
    case authorizationDenied
    case rateLimitExceeded

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not connected to Strava"
        case .tokenExpired:
            return "Strava session expired"
        case .tokenRefreshFailed:
            return "Failed to refresh Strava session"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from Strava"
        case .noRouteData:
            return "No GPS route data to upload"
        case .authorizationDenied:
            return "Strava authorization was denied"
        case .rateLimitExceeded:
            return "Strava rate limit exceeded. Try again later."
        }
    }
}
```

### 1.4 Create GPX Generator

**New File:** `RunWalkPackage/Sources/RunWalkShared/Strava/GPXGenerator.swift`

```swift
import Foundation
import CoreGPX

public struct GPXGenerator: Sendable {

    public init() {}

    /// Generates a GPX string from RouteData
    /// - Parameters:
    ///   - routeData: The route data containing coordinates
    ///   - name: Activity name
    ///   - activityType: Type of activity (e.g., "running")
    /// - Returns: GPX XML string
    public func generate(
        from routeData: RouteData,
        name: String,
        activityType: String = "running"
    ) -> String? {
        guard routeData.hasValidRoute else { return nil }

        // Create GPX root
        let root = GPXRoot(creator: "RunWalk App")

        // Add metadata
        let metadata = GPXMetadata()
        metadata.name = name
        metadata.time = routeData.startTime
        root.metadata = metadata

        // Create track
        let track = GPXTrack()
        track.name = name
        track.type = activityType

        // Create track segment with all points
        let segment = GPXTrackSegment()

        for coordinate in routeData.coordinates {
            let trackPoint = GPXTrackPoint(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            trackPoint.elevation = coordinate.altitude
            trackPoint.time = coordinate.timestamp
            segment.add(trackpoint: trackPoint)
        }

        track.add(trackSegment: segment)
        root.add(track: track)

        return root.gpx()
    }

    /// Generates GPX from a WorkoutRecord
    public func generate(from record: WorkoutRecord) -> String? {
        guard let routeData = record.routeData else { return nil }

        let name = "Run-Walk: \(record.formattedDuration)"
        return generate(from: routeData, name: name)
    }
}
```

### 1.5 Update WorkoutRecord Model

**File:** `RunWalkPackage/Sources/RunWalkShared/WorkoutRecord.swift`

Add new property to track Strava activity:

```swift
// Add to WorkoutRecord class
@Attribute public var stravaActivityId: Int?

// Add computed property
public var isSharedToStrava: Bool {
    stravaActivityId != nil
}

// Add Strava URL computed property
public var stravaActivityURL: URL? {
    guard let activityId = stravaActivityId else { return nil }
    return URL(string: "https://www.strava.com/activities/\(activityId)")
}
```

---

## Phase 2: iOS Implementation

### 2.1 Create Token Storage (Keychain)

**New File:** `RunWalkPackage/Sources/RunWalkFeature/Strava/StravaTokenStorage.swift`

```swift
import Foundation
import Security

public actor StravaTokenStorage {

    public static let shared = StravaTokenStorage()

    private init() {}

    // MARK: - Public Interface

    public func saveTokens(
        accessToken: String,
        refreshToken: String,
        expiresAt: Date,
        athleteId: Int
    ) throws {
        try save(key: StravaConfig.accessTokenKey, value: accessToken)
        try save(key: StravaConfig.refreshTokenKey, value: refreshToken)
        try save(key: StravaConfig.expiresAtKey, value: String(expiresAt.timeIntervalSince1970))
        try save(key: StravaConfig.athleteIdKey, value: String(athleteId))
    }

    public func getAccessToken() -> String? {
        retrieve(key: StravaConfig.accessTokenKey)
    }

    public func getRefreshToken() -> String? {
        retrieve(key: StravaConfig.refreshTokenKey)
    }

    public func getExpiresAt() -> Date? {
        guard let value = retrieve(key: StravaConfig.expiresAtKey),
              let interval = TimeInterval(value) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    public func getAthleteId() -> Int? {
        guard let value = retrieve(key: StravaConfig.athleteIdKey) else { return nil }
        return Int(value)
    }

    public func isTokenExpired() -> Bool {
        guard let expiresAt = getExpiresAt() else { return true }
        // Consider expired 5 minutes before actual expiration
        return Date().addingTimeInterval(300) >= expiresAt
    }

    public func clearAll() {
        delete(key: StravaConfig.accessTokenKey)
        delete(key: StravaConfig.refreshTokenKey)
        delete(key: StravaConfig.expiresAtKey)
        delete(key: StravaConfig.athleteIdKey)
    }

    public var hasTokens: Bool {
        getAccessToken() != nil && getRefreshToken() != nil
    }

    // MARK: - Private Keychain Operations

    private func save(key: String, value: String) throws {
        let data = Data(value.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: StravaConfig.keychainService,
            kSecAttrAccount as String: key
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        var newQuery = query
        newQuery[kSecValueData as String] = data

        let status = SecItemAdd(newQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func retrieve(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: StravaConfig.keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: StravaConfig.keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum KeychainError: Error {
        case saveFailed(OSStatus)
    }
}
```

### 2.2 Create API Client

**New File:** `RunWalkPackage/Sources/RunWalkFeature/Strava/StravaAPIClient.swift`

```swift
import Foundation

public actor StravaAPIClient {

    private let session: URLSession
    private let tokenStorage: StravaTokenStorage

    public init(
        session: URLSession = .shared,
        tokenStorage: StravaTokenStorage = .shared
    ) {
        self.session = session
        self.tokenStorage = tokenStorage
    }

    // MARK: - Token Exchange

    public func exchangeCodeForTokens(code: String) async throws -> StravaTokenResponse {
        var components = URLComponents(string: StravaConfig.tokenURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: StravaConfig.clientId),
            URLQueryItem(name: "client_secret", value: StravaConfig.clientSecret),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "grant_type", value: "authorization_code")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try JSONDecoder().decode(StravaTokenResponse.self, from: data)
    }

    // MARK: - Token Refresh

    public func refreshTokens(refreshToken: String) async throws -> StravaTokenResponse {
        var components = URLComponents(string: StravaConfig.tokenURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: StravaConfig.clientId),
            URLQueryItem(name: "client_secret", value: StravaConfig.clientSecret),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try JSONDecoder().decode(StravaTokenResponse.self, from: data)
    }

    // MARK: - Upload Activity

    public func uploadGPX(
        gpxData: Data,
        name: String,
        description: String?,
        activityType: String,
        accessToken: String
    ) async throws -> StravaUploadResponse {
        let boundary = UUID().uuidString

        var request = URLRequest(url: URL(string: StravaConfig.uploadURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add data_type field
        body.appendMultipartField(name: "data_type", value: "gpx", boundary: boundary)

        // Add name field
        body.appendMultipartField(name: "name", value: name, boundary: boundary)

        // Add description if provided
        if let description = description {
            body.appendMultipartField(name: "description", value: description, boundary: boundary)
        }

        // Add activity_type field
        body.appendMultipartField(name: "activity_type", value: activityType, boundary: boundary)

        // Add external_id for deduplication
        let externalId = "runwalk_\(UUID().uuidString)"
        body.appendMultipartField(name: "external_id", value: externalId, boundary: boundary)

        // Add file
        body.appendMultipartFile(
            name: "file",
            filename: "activity.gpx",
            contentType: "application/gpx+xml",
            data: gpxData,
            boundary: boundary
        )

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try JSONDecoder().decode(StravaUploadResponse.self, from: data)
    }

    // MARK: - Check Upload Status

    public func checkUploadStatus(uploadId: Int, accessToken: String) async throws -> StravaUploadResponse {
        let url = URL(string: "\(StravaConfig.uploadURL)/\(uploadId)")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try JSONDecoder().decode(StravaUploadResponse.self, from: data)
    }

    // MARK: - Deauthorize

    public func deauthorize(accessToken: String) async throws {
        var request = URLRequest(url: URL(string: StravaConfig.deauthorizeURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Validation

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StravaError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw StravaError.tokenExpired
        case 429:
            throw StravaError.rateLimitExceeded
        default:
            throw StravaError.networkError("HTTP \(httpResponse.statusCode)")
        }
    }
}

// MARK: - Data Extension for Multipart

private extension Data {
    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipartFile(name: String, filename: String, contentType: String, data: Data, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
```

### 2.3 Create Auth Manager

**New File:** `RunWalkPackage/Sources/RunWalkFeature/Strava/StravaAuthManager.swift`

```swift
import Foundation
import AuthenticationServices

@MainActor
public class StravaAuthManager: NSObject, ObservableObject {

    @Published public var isAuthenticating = false
    @Published public var error: StravaError?

    private let apiClient: StravaAPIClient
    private let tokenStorage: StravaTokenStorage
    private var webAuthSession: ASWebAuthenticationSession?

    public init(
        apiClient: StravaAPIClient = StravaAPIClient(),
        tokenStorage: StravaTokenStorage = .shared
    ) {
        self.apiClient = apiClient
        self.tokenStorage = tokenStorage
    }

    // MARK: - Authorization

    public func authorize() async throws {
        isAuthenticating = true
        error = nil

        defer { isAuthenticating = false }

        // Build authorization URL
        var components = URLComponents(string: StravaConfig.authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: StravaConfig.clientId),
            URLQueryItem(name: "redirect_uri", value: StravaConfig.callbackURL),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: StravaConfig.scope),
            URLQueryItem(name: "approval_prompt", value: "auto")
        ]

        guard let authURL = components.url else {
            throw StravaError.networkError("Invalid authorization URL")
        }

        // Start web authentication session
        let code = try await withCheckedThrowingContinuation { continuation in
            webAuthSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: StravaConfig.callbackURLScheme
            ) { callbackURL, error in
                if let error = error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: StravaError.authorizationDenied)
                    } else {
                        continuation.resume(throwing: StravaError.networkError(error.localizedDescription))
                    }
                    return
                }

                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: StravaError.authorizationDenied)
                    return
                }

                continuation.resume(returning: code)
            }

            webAuthSession?.presentationContextProvider = self
            webAuthSession?.prefersEphemeralWebBrowserSession = false
            webAuthSession?.start()
        }

        // Exchange code for tokens
        let tokenResponse = try await apiClient.exchangeCodeForTokens(code: code)

        // Save tokens
        try await tokenStorage.saveTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: tokenResponse.expiresAtDate,
            athleteId: tokenResponse.athlete?.id ?? 0
        )
    }

    // MARK: - Get Valid Token

    public func getValidAccessToken() async throws -> String {
        guard await tokenStorage.hasTokens else {
            throw StravaError.notAuthenticated
        }

        // Check if token is expired
        if await tokenStorage.isTokenExpired() {
            guard let refreshToken = await tokenStorage.getRefreshToken() else {
                throw StravaError.notAuthenticated
            }

            // Refresh the token
            let tokenResponse = try await apiClient.refreshTokens(refreshToken: refreshToken)

            // Save new tokens
            try await tokenStorage.saveTokens(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                expiresAt: tokenResponse.expiresAtDate,
                athleteId: tokenResponse.athlete?.id ?? await tokenStorage.getAthleteId() ?? 0
            )

            return tokenResponse.accessToken
        }

        guard let accessToken = await tokenStorage.getAccessToken() else {
            throw StravaError.notAuthenticated
        }

        return accessToken
    }

    // MARK: - Disconnect

    public func disconnect() async {
        if let accessToken = await tokenStorage.getAccessToken() {
            try? await apiClient.deauthorize(accessToken: accessToken)
        }
        await tokenStorage.clearAll()
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension StravaAuthManager: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
```

### 2.4 Create Main Strava Manager

**New File:** `RunWalkPackage/Sources/RunWalkFeature/Strava/StravaManager.swift`

```swift
import Foundation
import SwiftUI

@MainActor
@Observable
public class StravaManager {

    // MARK: - Published State

    public var isConnected: Bool = false
    public var athleteName: String?
    public var uploadStatus: StravaUploadStatus = .idle
    public var error: StravaError?

    // MARK: - Dependencies

    private let authManager: StravaAuthManager
    private let apiClient: StravaAPIClient
    private let tokenStorage: StravaTokenStorage
    private let gpxGenerator: GPXGenerator

    // MARK: - Initialization

    public init(
        authManager: StravaAuthManager = StravaAuthManager(),
        apiClient: StravaAPIClient = StravaAPIClient(),
        tokenStorage: StravaTokenStorage = .shared,
        gpxGenerator: GPXGenerator = GPXGenerator()
    ) {
        self.authManager = authManager
        self.apiClient = apiClient
        self.tokenStorage = tokenStorage
        self.gpxGenerator = gpxGenerator

        Task {
            await checkConnectionStatus()
        }
    }

    // MARK: - Connection Status

    public func checkConnectionStatus() async {
        isConnected = await tokenStorage.hasTokens
    }

    // MARK: - Connect

    public func connect() async {
        error = nil

        do {
            try await authManager.authorize()
            isConnected = true
        } catch let stravaError as StravaError {
            error = stravaError
            isConnected = false
        } catch {
            self.error = .networkError(error.localizedDescription)
            isConnected = false
        }
    }

    // MARK: - Disconnect

    public func disconnect() async {
        await authManager.disconnect()
        isConnected = false
        athleteName = nil
    }

    // MARK: - Upload Workout

    public func uploadWorkout(_ record: WorkoutRecord) async -> Int? {
        guard record.hasRoute else {
            error = .noRouteData
            return nil
        }

        guard let routeData = record.routeData else {
            error = .noRouteData
            return nil
        }

        uploadStatus = .uploading
        error = nil

        do {
            // Get valid access token
            let accessToken = try await authManager.getValidAccessToken()

            // Generate GPX
            guard let gpxString = gpxGenerator.generate(from: routeData, name: generateActivityName(for: record)),
                  let gpxData = gpxString.data(using: .utf8) else {
                throw StravaError.noRouteData
            }

            // Upload to Strava
            let uploadResponse = try await apiClient.uploadGPX(
                gpxData: gpxData,
                name: generateActivityName(for: record),
                description: generateDescription(for: record),
                activityType: "run",
                accessToken: accessToken
            )

            // Poll for completion
            let activityId = try await pollUploadStatus(
                uploadId: uploadResponse.id,
                accessToken: accessToken
            )

            uploadStatus = .success(activityId: activityId)
            return activityId

        } catch let stravaError as StravaError {
            error = stravaError
            uploadStatus = .failed(error: stravaError.localizedDescription)

            // Handle token expiration by disconnecting
            if case .tokenExpired = stravaError {
                await disconnect()
            }

            return nil
        } catch {
            let message = error.localizedDescription
            self.error = .networkError(message)
            uploadStatus = .failed(error: message)
            return nil
        }
    }

    // MARK: - Private Helpers

    private func pollUploadStatus(uploadId: Int, accessToken: String) async throws -> Int {
        uploadStatus = .processing(uploadId: uploadId)

        // Poll up to 30 times (30 seconds)
        for _ in 0..<30 {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            let status = try await apiClient.checkUploadStatus(
                uploadId: uploadId,
                accessToken: accessToken
            )

            if let activityId = status.activityId {
                return activityId
            }

            if let error = status.error {
                throw StravaError.uploadFailed(error)
            }
        }

        throw StravaError.uploadFailed("Upload timed out")
    }

    private func generateActivityName(for record: WorkoutRecord) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let dayName = formatter.string(from: record.startDate)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = timeFormatter.string(from: record.startDate)

        return "\(dayName) Run-Walk (\(timeString))"
    }

    private func generateDescription(for record: WorkoutRecord) -> String {
        var parts: [String] = []

        parts.append("Run-Walk Interval Training")
        parts.append("Duration: \(record.formattedDuration)")
        parts.append("Run intervals: \(record.runIntervals)")
        parts.append("Walk intervals: \(record.walkIntervals)")

        if let distance = record.formattedDistance {
            parts.append("Distance: \(distance)")
        }

        parts.append("")
        parts.append("Recorded with RunWalk App")

        return parts.joined(separator: "\n")
    }

    // MARK: - Reset

    public func resetUploadStatus() {
        uploadStatus = .idle
        error = nil
    }
}
```

### 2.5 Create UI Components

**New File:** `RunWalkPackage/Sources/RunWalkFeature/Views/StravaSettingsView.swift`

```swift
import SwiftUI

public struct StravaSettingsView: View {
    @Bindable var stravaManager: StravaManager
    @State private var showDisconnectAlert = false

    public init(stravaManager: StravaManager) {
        self.stravaManager = stravaManager
    }

    public var body: some View {
        Section {
            if stravaManager.isConnected {
                connectedView
            } else {
                connectButton
            }
        } header: {
            Label("Strava", systemImage: "figure.run.circle")
        } footer: {
            Text("Share your workouts with the Strava community")
        }
    }

    private var connectButton: some View {
        Button {
            Task {
                await stravaManager.connect()
            }
        } label: {
            HStack {
                Image("ConnectWithStrava") // Add to assets
                    .resizable()
                    .scaledToFit()
                    .frame(height: 48)
                Spacer()
            }
        }
        .listRowBackground(Color.clear)
    }

    private var connectedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Connected to Strava")
                    .fontWeight(.medium)
                Spacer()
            }

            Button("Disconnect", role: .destructive) {
                showDisconnectAlert = true
            }
            .font(.subheadline)
        }
        .alert("Disconnect from Strava?", isPresented: $showDisconnectAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Disconnect", role: .destructive) {
                Task {
                    await stravaManager.disconnect()
                }
            }
        } message: {
            Text("You can reconnect at any time.")
        }
    }
}
```

**New File:** `RunWalkPackage/Sources/RunWalkFeature/Views/StravaShareButton.swift`

```swift
import SwiftUI

public struct StravaShareButton: View {
    let record: WorkoutRecord
    @Bindable var stravaManager: StravaManager
    let onSuccess: (Int) -> Void

    @State private var showError = false

    public init(
        record: WorkoutRecord,
        stravaManager: StravaManager,
        onSuccess: @escaping (Int) -> Void
    ) {
        self.record = record
        self.stravaManager = stravaManager
        self.onSuccess = onSuccess
    }

    public var body: some View {
        Group {
            if record.isSharedToStrava {
                viewOnStravaButton
            } else if stravaManager.isConnected {
                shareButton
            }
        }
        .alert("Upload Failed", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(stravaManager.error?.localizedDescription ?? "Unknown error")
        }
    }

    private var shareButton: some View {
        Button {
            Task {
                if let activityId = await stravaManager.uploadWorkout(record) {
                    onSuccess(activityId)
                } else {
                    showError = stravaManager.error != nil
                }
            }
        } label: {
            HStack {
                switch stravaManager.uploadStatus {
                case .uploading, .processing:
                    ProgressView()
                        .tint(.white)
                    Text("Uploading...")
                default:
                    Image(systemName: "square.and.arrow.up")
                    Text("Share to Strava")
                }
            }
        }
        .disabled(isUploading)
    }

    private var viewOnStravaButton: some View {
        Link(destination: record.stravaActivityURL ?? URL(string: "https://strava.com")!) {
            HStack {
                Image(systemName: "arrow.up.right.square")
                Text("View on Strava")
            }
        }
    }

    private var isUploading: Bool {
        switch stravaManager.uploadStatus {
        case .uploading, .processing:
            return true
        default:
            return false
        }
    }
}
```

---

## Phase 3: Configuration Updates

### 3.1 Update Info.plist

**File:** `RunWalk/Info.plist`

Add the following keys:

```xml
<!-- URL Scheme for Strava callback -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>runwalk</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.vishutdhar.RunWalk</string>
    </dict>
</array>

<!-- Query schemes to check if Strava app is installed -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>strava</string>
</array>
```

### 3.2 Update Package.swift

**File:** `RunWalkPackage/Package.swift`

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RunWalkFeature",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "RunWalkShared", targets: ["RunWalkShared"]),
        .library(name: "RunWalkFeature", targets: ["RunWalkFeature"]),
        .library(name: "RunWalkWatchFeature", targets: ["RunWalkWatchFeature"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vincentneo/CoreGPX.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "RunWalkShared",
            dependencies: ["CoreGPX"],
            path: "Sources/RunWalkShared"
        ),
        .target(
            name: "RunWalkFeature",
            dependencies: ["RunWalkShared"],
            path: "Sources/RunWalkFeature"
        ),
        .target(
            name: "RunWalkWatchFeature",
            dependencies: ["RunWalkShared"],
            path: "Sources/RunWalkWatchFeature"
        ),
        .testTarget(
            name: "RunWalkSharedTests",
            dependencies: ["RunWalkShared"],
            path: "Tests/RunWalkSharedTests"
        ),
        .testTarget(
            name: "RunWalkFeatureTests",
            dependencies: ["RunWalkFeature", "RunWalkShared"]
        ),
    ]
)
```

---

## Phase 4: Integration Points

### 4.1 Add to ContentView (Settings Tab)

**File:** `RunWalkPackage/Sources/RunWalkFeature/ContentView.swift`

In the Settings tab, add the Strava section:

```swift
// Add property
@State private var stravaManager = StravaManager()

// In SettingsTabView, add section:
StravaSettingsView(stravaManager: stravaManager)
```

### 4.2 Add to WorkoutDetailView

**File:** `RunWalkPackage/Sources/RunWalkFeature/WorkoutDetailView.swift`

Add share button:

```swift
// Add property
@Environment(StravaManager.self) private var stravaManager

// In the view body, add:
if record.hasRoute {
    StravaShareButton(
        record: record,
        stravaManager: stravaManager,
        onSuccess: { activityId in
            record.stravaActivityId = activityId
        }
    )
}
```

### 4.3 Add to WorkoutSummaryView (Optional)

Add "Share to Strava" option in the summary modal after workout completion.

---

## Phase 5: Testing Strategy

### 5.1 Unit Tests

**New File:** `RunWalkPackage/Tests/RunWalkSharedTests/GPXGeneratorTests.swift`

```swift
import Testing
@testable import RunWalkShared

@Test func testGPXGeneration() {
    let generator = GPXGenerator()

    let coordinates = [
        RouteCoordinate(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: Date(),
            altitude: 10.0,
            horizontalAccuracy: 5.0,
            speed: 3.0
        ),
        RouteCoordinate(
            latitude: 37.7750,
            longitude: -122.4195,
            timestamp: Date().addingTimeInterval(5),
            altitude: 11.0,
            horizontalAccuracy: 5.0,
            speed: 3.0
        )
    ]

    var routeData = RouteData()
    for coord in coordinates {
        routeData.add(coord)
    }

    let gpx = generator.generate(from: routeData, name: "Test Run")

    #expect(gpx != nil)
    #expect(gpx!.contains("<gpx"))
    #expect(gpx!.contains("<trkpt"))
    #expect(gpx!.contains("<time>"))
    #expect(gpx!.contains("RunWalk App"))
}

@Test func testGPXGenerationRequiresValidRoute() {
    let generator = GPXGenerator()
    let emptyRouteData = RouteData()

    let gpx = generator.generate(from: emptyRouteData, name: "Empty")

    #expect(gpx == nil)
}
```

### 5.2 Integration Tests

Test the full OAuth flow in development:
1. Register app at Strava (done in prerequisites)
2. Run app on device/simulator
3. Tap "Connect with Strava"
4. Authenticate with test Strava account
5. Verify tokens are stored
6. Complete a workout with GPS
7. Share to Strava
8. Verify activity appears on Strava

### 5.3 Manual Testing Checklist

- [ ] OAuth flow completes successfully
- [ ] Token refresh works when expired
- [ ] GPX upload succeeds with valid route
- [ ] Error shown when no GPS data
- [ ] Disconnect clears all tokens
- [ ] "View on Strava" opens correct activity
- [ ] Brand guidelines followed (button, logo)

---

## Phase 6: Deployment

### 6.1 Before App Store Submission

1. **Submit app to Strava for review**
   - Go to [Strava Developer Portal](https://developers.strava.com/)
   - Submit app for review to exit "Single Player Mode"
   - Ensure brand guidelines compliance

2. **Add "Powered by Strava" logo**
   - Display in Settings or About section
   - Required by Strava API Agreement

3. **Update App Store description**
   - Mention Strava integration
   - Note that Strava account required for sharing

### 6.2 Post-Launch

- Monitor for 401 errors (token issues)
- Check Strava API usage in developer dashboard
- Request rate limit increase if approaching limits

---

## File Summary

### New Files to Create

| File | Location | Purpose |
|------|----------|---------|
| `StravaConfig.swift` | RunWalkShared/Strava/ | Configuration constants |
| `StravaModels.swift` | RunWalkShared/Strava/ | Data models |
| `GPXGenerator.swift` | RunWalkShared/Strava/ | GPX file generation |
| `StravaTokenStorage.swift` | RunWalkFeature/Strava/ | Keychain storage |
| `StravaAPIClient.swift` | RunWalkFeature/Strava/ | Network requests |
| `StravaAuthManager.swift` | RunWalkFeature/Strava/ | OAuth handling |
| `StravaManager.swift` | RunWalkFeature/Strava/ | Main integration manager |
| `StravaSettingsView.swift` | RunWalkFeature/Views/ | Connect/disconnect UI |
| `StravaShareButton.swift` | RunWalkFeature/Views/ | Share button component |
| `GPXGeneratorTests.swift` | Tests/RunWalkSharedTests/ | Unit tests |

### Files to Modify

| File | Changes |
|------|---------|
| `Package.swift` | Add CoreGPX dependency |
| `WorkoutRecord.swift` | Add `stravaActivityId` property |
| `ContentView.swift` | Add StravaManager, Strava settings section |
| `WorkoutDetailView.swift` | Add StravaShareButton |
| `Info.plist` | Add URL schemes |

---

## Timeline Estimate

| Phase | Tasks | Dependencies |
|-------|-------|--------------|
| **Phase 1** | Foundation (Shared Code) | CoreGPX package |
| **Phase 2** | iOS Implementation | Phase 1 complete |
| **Phase 3** | Configuration | Phase 2 complete |
| **Phase 4** | Integration | Phase 3 complete |
| **Phase 5** | Testing | Phase 4 complete |
| **Phase 6** | Deployment | Phase 5 complete, Strava app approved |

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Strava API changes | Use stable v3 API, monitor changelog |
| Token refresh fails | Clear tokens, prompt re-auth |
| Upload fails | Show clear error, allow retry |
| Rate limit hit | Implement exponential backoff |
| App approval delayed | Can ship without Strava, add later |

---

## Open Questions (Resolved)

1. ~~Auto-upload vs manual?~~ → **Manual "Share to Strava" button**
2. ~~watchOS support?~~ → **iOS only for v1** (watchOS can be added later)
3. ~~Custom library vs existing?~~ → **Custom implementation** (simpler, modern Swift)

---

## Confidence Level: 95%

This plan covers all aspects of Strava integration with clear implementation details. The remaining 5% accounts for:
- Potential Strava API quirks discovered during implementation
- App approval timeline uncertainty
