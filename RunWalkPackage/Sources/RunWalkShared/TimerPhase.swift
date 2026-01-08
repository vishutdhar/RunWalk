import SwiftUI

/// Represents the current phase of the interval timer
public enum TimerPhase: String, Sendable {
    case run = "RUN"
    case walk = "WALK"

    /// Returns the opposite phase
    public var next: TimerPhase {
        switch self {
        case .run: return .walk
        case .walk: return .run
        }
    }

    /// Color associated with each phase
    public var color: Color {
        switch self {
        case .run: return .orange
        case .walk: return .green
        }
    }
}
