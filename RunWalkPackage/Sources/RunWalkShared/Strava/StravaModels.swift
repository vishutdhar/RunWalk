import Foundation

// MARK: - Token Response

/// Response from Strava OAuth token exchange
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

/// Strava athlete profile information
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

/// Response from Strava upload endpoint
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

/// Current status of a Strava upload operation
public enum StravaUploadStatus: Sendable, Equatable {
    case idle
    case uploading
    case processing(uploadId: Int)
    case success(activityId: Int)
    case failed(error: String)
}

// MARK: - Strava Error

/// Errors that can occur during Strava operations
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
