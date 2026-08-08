import Foundation

/// A stable time abstraction and the only way time enters consumer code.
///
/// Reading the current time, measuring elapsed time, and sleeping are all
/// expressed through a clock. A clock reveals nothing about the platform
/// that provides it. Current time and elapsed measurement are served by the
/// same clock: a consumer that needs both receives one clock and one source
/// of truth (DES-003).
public protocol Clock: Sendable {
    /// Reads the current wall-clock time for calendar purposes.
    ///
    /// The value is wall-clock time and may be adjusted by the system.
    func now() -> Instant

    /// Reads the clock twice and returns the elapsed duration between the reads.
    ///
    /// The elapsed duration is unaffected by adjustments to the current time.
    func measure<Result>(_ body: () async throws -> Result) async throws -> (Result, Duration)

    /// Asynchronously waits until the clock's time has advanced by `duration`.
    ///
    /// Waiting never blocks and never bypasses the clock.
    func sleep(for duration: Duration) async throws

    /// Asynchronously waits until the clock's time has reached `instant`.
    ///
    /// Waiting never blocks and never bypasses the clock.
    func sleep(until instant: Instant) async throws
}

/// An opaque, immutable point in time produced by a clock.
///
/// Instants are compared and used as boundaries. They reveal nothing about
/// how the clock produces them and are meaningful only within the time domain
/// of the clock that produced them.
public struct Instant: Comparable, Sendable {
    let offset: Duration

    /// Creates an instant positioned `offset` after the producing clock's origin.
    ///
    /// This is the construction path for clock implementations.
    public init(offset: Duration) {
        self.offset = offset
    }

    /// Returns an instant advanced from this one by `duration`.
    ///
    /// The result is a boundary on the same clock's time domain.
    public func advanced(by duration: Duration) -> Instant {
        Instant(offset: offset + duration)
    }

    public static func < (lhs: Instant, rhs: Instant) -> Bool {
        lhs.offset < rhs.offset
    }
}
