import Foundation

/// The operation's handle: the one place an operation learns whether
/// cancellation has been requested.
///
/// An operation holds the observation for the operation's lifetime. The
/// signal is delivered by composition; there is no global cancellation state
/// and nothing is acquired by lookup (DES-008, ARC-006).
public protocol CancellationObservation: Sendable {
    /// Whether cancellation has been requested.
    ///
    /// This is the safe point at which an operation observes the signal and
    /// decides to stop. A request is one-way: once made, every subsequent
    /// read reports cancelled.
    var isCancelled: Bool { get }
}

/// The owner's handle: the one place a cancellation request is made.
///
/// A source is created by composition when a cancellable operation starts,
/// governs one operation, and is never reused for a later one. Requests are
/// cooperative: they signal the operation and never hard-interrupt it
/// (DES-008, ARC-006).
public protocol CancellationSource: Sendable {
    /// Requests cancellation.
    ///
    /// The request is one-way and never revoked. It takes effect at the
    /// operation's next observation, never by force.
    func request()

    /// An observation of this source's signal.
    ///
    /// Any number of observers may hold observations of the same source; they
    /// all receive the same signal.
    var observation: any CancellationObservation { get }
}

/// The distinct result of a flow that stopped.
///
/// A cancelled flow is reported distinctly from a failed flow; the two
/// outcomes are never conflated (DES-008, ARC-001).
public enum CancelledOutcome: Sendable, Equatable {
    /// The flow stopped because cancellation was requested.
    case cancelled
    /// The flow stopped because it failed.
    case failed
}
