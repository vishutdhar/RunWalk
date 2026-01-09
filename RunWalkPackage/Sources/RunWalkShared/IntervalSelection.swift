import Foundation

/// Represents an interval selection - either a preset duration or a custom value
/// This type wraps IntervalDuration presets and allows arbitrary custom durations
public enum IntervalSelection: Equatable, Sendable {
    /// A preset interval duration from the standard options
    case preset(IntervalDuration)
    /// A custom interval with arbitrary seconds (10-1800 seconds = 10s to 30min)
    case custom(seconds: Int)

    // MARK: - Validation Constants

    /// Minimum allowed custom interval (10 seconds)
    public static let minimumCustomSeconds = 10
    /// Maximum allowed custom interval (30 minutes = 1800 seconds)
    public static let maximumCustomSeconds = 1800

    // MARK: - Computed Properties

    /// The duration in seconds
    public var seconds: Int {
        switch self {
        case .preset(let duration):
            return duration.rawValue
        case .custom(let seconds):
            return seconds
        }
    }

    /// Human-readable display name (e.g., "2 min" or "2m 30s")
    public var displayName: String {
        switch self {
        case .preset(let duration):
            return duration.displayName
        case .custom(let seconds):
            return Self.formatDuration(seconds)
        }
    }

    /// Compact name for small screens (e.g., "2m" or "2:30")
    public var shortName: String {
        switch self {
        case .preset(let duration):
            return duration.shortName
        case .custom(let seconds):
            return Self.formatShortDuration(seconds)
        }
    }

    /// Whether this is a custom interval (not a preset)
    public var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }

    /// Whether this is a preset interval
    public var isPreset: Bool {
        if case .preset = self { return true }
        return false
    }

    /// Returns the preset duration if this is a preset, nil otherwise
    public var presetDuration: IntervalDuration? {
        if case .preset(let duration) = self {
            return duration
        }
        return nil
    }

    // MARK: - Factory Methods

    /// Creates a custom interval with validation
    /// - Parameter seconds: The duration in seconds (clamped to valid range)
    /// - Returns: A custom IntervalSelection with the validated duration
    public static func customClamped(seconds: Int) -> IntervalSelection {
        let clampedSeconds = max(minimumCustomSeconds, min(maximumCustomSeconds, seconds))
        return .custom(seconds: clampedSeconds)
    }

    /// Creates the appropriate selection for given seconds - preset if it matches, custom otherwise
    /// Use this when user selects a custom time to avoid showing "1 min" as custom when it's a preset
    /// - Parameter seconds: The duration in seconds (clamped to valid range)
    /// - Returns: A preset IntervalSelection if seconds match a preset, otherwise custom
    public static func smartSelection(seconds: Int) -> IntervalSelection {
        let clampedSeconds = max(minimumCustomSeconds, min(maximumCustomSeconds, seconds))

        // Check if the seconds match any preset duration
        if let matchingPreset = IntervalDuration.allCases.first(where: { $0.rawValue == clampedSeconds }) {
            return .preset(matchingPreset)
        }

        return .custom(seconds: clampedSeconds)
    }

    // MARK: - Formatting Helpers

    /// Formats seconds as a human-readable duration string
    /// Examples: "30 sec", "1 min", "2m 30s", "10 min"
    private static func formatDuration(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes == 0 {
            return "\(seconds) sec"
        } else if seconds == 0 {
            return "\(minutes) min"
        } else {
            return "\(minutes)m \(seconds)s"
        }
    }

    /// Formats seconds as a compact duration string
    /// Examples: "30s", "1m", "2:30", "10m"
    private static func formatShortDuration(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes == 0 {
            return "\(seconds)s"
        } else if seconds == 0 {
            return "\(minutes)m"
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Codable Conformance

extension IntervalSelection: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    private enum SelectionType: String, Codable {
        case preset
        case custom
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(SelectionType.self, forKey: .type)

        switch type {
        case .preset:
            let rawValue = try container.decode(Int.self, forKey: .value)
            if let duration = IntervalDuration(rawValue: rawValue) {
                self = .preset(duration)
            } else {
                // Fallback to custom if preset value is not recognized
                self = .custom(seconds: rawValue)
            }
        case .custom:
            let seconds = try container.decode(Int.self, forKey: .value)
            self = .custom(seconds: seconds)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .preset(let duration):
            try container.encode(SelectionType.preset, forKey: .type)
            try container.encode(duration.rawValue, forKey: .value)
        case .custom(let seconds):
            try container.encode(SelectionType.custom, forKey: .type)
            try container.encode(seconds, forKey: .value)
        }
    }
}

// MARK: - RawRepresentable for @AppStorage

extension IntervalSelection: RawRepresentable {
    public typealias RawValue = String

    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(IntervalSelection.self, from: data) else {
            return nil
        }
        self = decoded
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            // Fallback to default preset
            return "{\"type\":\"preset\",\"value\":30}"
        }
        return string
    }
}

// MARK: - Identifiable

extension IntervalSelection: Identifiable {
    public var id: String {
        switch self {
        case .preset(let duration):
            return "preset_\(duration.rawValue)"
        case .custom(let seconds):
            return "custom_\(seconds)"
        }
    }
}
