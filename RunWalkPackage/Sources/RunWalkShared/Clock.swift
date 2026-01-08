import Foundation

// MARK: - Clock Protocol for Testability

/// Protocol for getting current time - allows mocking in tests
public protocol Clock: Sendable {
    func now() -> Date
}

/// Default clock implementation using system time
public struct SystemClock: Clock, Sendable {
    public init() {}

    public func now() -> Date {
        Date()
    }
}
