/// The stream-level streaming state machine of the capability contract
/// (DES-009 §3.11.4, ARC-001).
///
/// The states are **active**, **complete**, and **interrupted**. The legal
/// transitions are:
///
/// - `active → active` — the stream continues delivering content deltas;
///   `appending(_:)` accumulates the received content, which is never reset or
///   discarded.
/// - `active → complete` — terminal: the stream ends with the completion
///   carrying the assembled assistant message, so the Application layer can
///   append and persist it (ARC-001, DES-009 §3.3).
/// - `active → interrupted` — terminal: the stream ends with the interruption
///   carrying the preserved partial content as incomplete. Interruption is
///   cooperative through the stream lifecycle and the Foundation cancellation
///   primitive (DES-008): the consumer observes the cancellation signal at a
///   safe point and applies `interrupting()`.
///
/// `complete` and `interrupted` are terminal — no transition leaves them.
/// Resumption after an interruption is a new stream, a new request with a new
/// identity, starting from the preserved partial content (DES-009 §3.11.4).
///
/// The state machine records the same lifecycle as the Conversation
/// aggregate's streaming state (idle, streaming, interrupted) at the aggregate
/// level; the two are consistent (DES-009 §3.11.4). Partial content is never
/// silently discarded (ARC-001 Streaming Interrupted). Immutable and equal by
/// content (ARC-003).
public enum StreamingState: Equatable, Sendable {
    /// The stream is active, delivering content incrementally.
    case active(partialContent: String)
    /// The stream ended: terminal, carrying the assembled assistant message.
    case complete(message: Message)
    /// The stream was interrupted: terminal, carrying the preserved partial
    /// content as incomplete.
    case interrupted(partialContent: String)

    /// Applies a content delta: `active → active`.
    ///
    /// The accumulated partial content grows and is never reset or discarded.
    /// Throws `StreamingStateError.notActive` from a terminal state; the state
    /// is then unchanged (DES-009 §3.11.4).
    public func appending(_ content: String) throws -> StreamingState {
        guard case .active(let partialContent) = self else {
            throw StreamingStateError.notActive
        }
        return .active(partialContent: partialContent + content)
    }

    /// Completes the stream: `active → complete`, terminal.
    ///
    /// The completion carries the assembled assistant message built from the
    /// accumulated partial content, so the Application layer can append and
    /// persist it (ARC-001, DES-009 §3.3). Throws
    /// `StreamingStateError.notActive` from a terminal state; the state is
    /// then unchanged (DES-009 §3.11.4).
    public func completing() throws -> StreamingState {
        guard case .active(let partialContent) = self else {
            throw StreamingStateError.notActive
        }
        return .complete(message: Message(role: .assistant, content: partialContent))
    }

    /// Interrupts the stream: `active → interrupted`, terminal.
    ///
    /// The partial content received so far is preserved as incomplete; it is
    /// never silently discarded (ARC-001 Streaming Interrupted). Throws
    /// `StreamingStateError.notActive` from a terminal state; the state is
    /// then unchanged (DES-009 §3.11.4).
    public func interrupting() throws -> StreamingState {
        guard case .active(let partialContent) = self else {
            throw StreamingStateError.notActive
        }
        return .interrupted(partialContent: partialContent)
    }

    /// The partial content preserved by this state, if any.
    ///
    /// `active` and `interrupted` preserve the content received so far;
    /// `complete` has none (its content is carried by the assembled message).
    public var partialContent: String? {
        switch self {
        case .active(let partialContent), .interrupted(let partialContent):
            return partialContent
        case .complete:
            return nil
        }
    }

    /// Returns whether this state is terminal (`complete` or `interrupted`).
    public var isTerminal: Bool {
        switch self {
        case .active:
            return false
        case .complete, .interrupted:
            return true
        }
    }
}

/// The failures a streaming state transition can report (DES-009 §3.11.4).
public enum StreamingStateError: Error, Equatable, Sendable {
    /// A transition was attempted from a state that is not active.
    case notActive
}
