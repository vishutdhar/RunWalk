import Foundation

/// Configuration constants for Strava API integration
public enum StravaConfig {
    // MARK: - API Credentials
    public static let clientId = "195508"
    public static let clientSecret = "b06697c038570f0310517983f190f1dfd8802528"

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
