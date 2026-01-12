import Foundation
import SwiftUI
import AuthenticationServices
import RunWalkShared

/// Main manager for Strava integration
/// Coordinates authentication, upload, and status tracking
@MainActor
@Observable
public final class StravaManager {

    // MARK: - Published State

    /// Whether user is connected to Strava
    public private(set) var isConnected: Bool = false

    /// Current upload status
    public private(set) var uploadStatus: StravaUploadStatus = .idle

    /// Error message to display
    public private(set) var errorMessage: String?

    /// Whether an operation is in progress
    public private(set) var isLoading: Bool = false

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

        // Check initial connection status
        Task {
            await checkConnectionStatus()
        }
    }

    // MARK: - Connection Status

    /// Checks if user is connected to Strava
    public func checkConnectionStatus() async {
        isConnected = await tokenStorage.hasTokens
    }

    // MARK: - Authentication

    /// Connects to Strava (starts OAuth flow)
    public func connect(contextProvider: ASWebAuthenticationPresentationContextProviding) async {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await authManager.authorize(contextProvider: contextProvider)
            isConnected = true
        } catch let error as StravaError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Disconnects from Strava
    public func disconnect() async {
        isLoading = true
        errorMessage = nil

        do {
            try await authManager.disconnect()
            isConnected = false
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Upload

    /// Uploads a workout to Strava
    /// - Parameter record: The workout record to upload
    /// - Returns: The Strava activity ID if successful
    @discardableResult
    public func uploadWorkout(_ record: WorkoutRecord) async throws -> Int {
        guard isConnected else {
            throw StravaError.notAuthenticated
        }

        guard let routeData = record.routeData, routeData.hasValidRoute else {
            throw StravaError.noRouteData
        }

        uploadStatus = .uploading
        errorMessage = nil

        do {
            // Get valid access token
            let accessToken = try await authManager.getValidAccessToken()

            // Generate GPX
            guard let gpxData = gpxGenerator.generateData(from: record) else {
                throw StravaError.noRouteData
            }

            // Create activity name and description
            let name = "Run-Walk: \(record.formattedDuration)"
            let description = buildDescription(for: record)

            // Upload to Strava
            let uploadResponse = try await apiClient.uploadGPX(
                gpxData: gpxData,
                name: name,
                description: description,
                accessToken: accessToken
            )

            // Handle response
            if let activityId = uploadResponse.activityId {
                uploadStatus = .success(activityId: activityId)
                return activityId
            } else if let error = uploadResponse.error {
                throw StravaError.uploadFailed(error)
            } else {
                // Upload is processing, need to poll
                let activityId = try await pollUploadStatus(uploadId: uploadResponse.id, accessToken: accessToken)
                uploadStatus = .success(activityId: activityId)
                return activityId
            }
        } catch let error as StravaError {
            uploadStatus = .failed(error: error.errorDescription ?? "Unknown error")
            errorMessage = error.errorDescription
            throw error
        } catch {
            uploadStatus = .failed(error: error.localizedDescription)
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Resets the upload status to idle
    public func resetUploadStatus() {
        uploadStatus = .idle
        errorMessage = nil
    }

    // MARK: - Private Helpers

    private func pollUploadStatus(uploadId: Int, accessToken: String) async throws -> Int {
        uploadStatus = .processing(uploadId: uploadId)

        // Poll every 2 seconds, max 30 seconds
        for _ in 0..<15 {
            try await Task.sleep(nanoseconds: 2_000_000_000)

            let status = try await apiClient.checkUploadStatus(uploadId: uploadId, accessToken: accessToken)

            if let activityId = status.activityId {
                return activityId
            } else if let error = status.error {
                throw StravaError.uploadFailed(error)
            }
        }

        throw StravaError.uploadFailed("Upload timed out")
    }

    private func buildDescription(for record: WorkoutRecord) -> String {
        var parts: [String] = []

        parts.append("Run-Walk interval workout")

        if record.hasDistance {
            parts.append("Distance: \(record.formattedDistance)")
        }

        if let pace = record.formattedPace {
            parts.append("Avg pace: \(pace)")
        }

        parts.append("Run intervals: \(record.runIntervals)")
        parts.append("Walk intervals: \(record.walkIntervals)")
        parts.append("")
        parts.append("Recorded with RunWalk app")

        return parts.joined(separator: "\n")
    }
}
