import Foundation
import Security
import RunWalkShared

/// Secure storage for Strava OAuth tokens using Keychain
public actor StravaTokenStorage {

    public static let shared = StravaTokenStorage()

    private init() {}

    // MARK: - Public Interface

    /// Saves OAuth tokens to Keychain
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

    /// Retrieves the current access token
    public func getAccessToken() -> String? {
        retrieve(key: StravaConfig.accessTokenKey)
    }

    /// Retrieves the current refresh token
    public func getRefreshToken() -> String? {
        retrieve(key: StravaConfig.refreshTokenKey)
    }

    /// Retrieves the token expiration date
    public func getExpiresAt() -> Date? {
        guard let value = retrieve(key: StravaConfig.expiresAtKey),
              let interval = TimeInterval(value) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    /// Retrieves the athlete ID
    public func getAthleteId() -> Int? {
        guard let value = retrieve(key: StravaConfig.athleteIdKey) else { return nil }
        return Int(value)
    }

    /// Checks if the current token is expired (with 5 minute buffer)
    public func isTokenExpired() -> Bool {
        guard let expiresAt = getExpiresAt() else { return true }
        // Consider expired 5 minutes before actual expiration
        return Date().addingTimeInterval(300) >= expiresAt
    }

    /// Clears all stored tokens
    public func clearAll() {
        delete(key: StravaConfig.accessTokenKey)
        delete(key: StravaConfig.refreshTokenKey)
        delete(key: StravaConfig.expiresAtKey)
        delete(key: StravaConfig.athleteIdKey)
    }

    /// Whether valid tokens are stored
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
