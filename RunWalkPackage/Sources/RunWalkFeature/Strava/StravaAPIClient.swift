import Foundation
import RunWalkShared

/// Network client for Strava API requests
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

    /// Exchanges an authorization code for access tokens
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

        let decoder = JSONDecoder()
        return try decoder.decode(StravaTokenResponse.self, from: data)
    }

    /// Refreshes expired access token
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

        let decoder = JSONDecoder()
        return try decoder.decode(StravaTokenResponse.self, from: data)
    }

    // MARK: - Upload

    /// Uploads a GPX file to Strava
    public func uploadGPX(
        gpxData: Data,
        name: String,
        description: String,
        accessToken: String
    ) async throws -> StravaUploadResponse {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: StravaConfig.uploadURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add data_type field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"data_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("gpx\r\n".data(using: .utf8)!)

        // Add name field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(name)\r\n".data(using: .utf8)!)

        // Add description field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"description\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(description)\r\n".data(using: .utf8)!)

        // Add activity_type field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"activity_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("run\r\n".data(using: .utf8)!)

        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"activity.gpx\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/gpx+xml\r\n\r\n".data(using: .utf8)!)
        body.append(gpxData)
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = JSONDecoder()
        return try decoder.decode(StravaUploadResponse.self, from: data)
    }

    /// Checks the status of an upload
    public func checkUploadStatus(uploadId: Int, accessToken: String) async throws -> StravaUploadResponse {
        let url = URL(string: "\(StravaConfig.uploadURL)/\(uploadId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = JSONDecoder()
        return try decoder.decode(StravaUploadResponse.self, from: data)
    }

    // MARK: - Deauthorization

    /// Revokes Strava access (disconnect)
    public func deauthorize(accessToken: String) async throws {
        var request = URLRequest(url: URL(string: StravaConfig.deauthorizeURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Response Validation

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
