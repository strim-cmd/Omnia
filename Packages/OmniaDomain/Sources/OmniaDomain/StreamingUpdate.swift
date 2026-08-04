/// An incremental delivery event of a streaming capability (DES-009 §3.11.1).
///
/// A stream delivers content deltas, then ends with the completion event
/// carrying the assembled assistant message or, on interruption, the
/// interruption event carrying the preserved partial content (ARC-001, DES-009
/// §3.3). Every event carries the identity of its request so a consumer can
/// correlate it to the in-flight request (DES-009 §3.11.1).
///
/// Immutable and equal by content (ARC-003).
public enum StreamingUpdate: Equatable, Sendable {
    /// A content fragment of the streamed reply.
    case contentDelta(identity: CapabilityRequestIdentity, content: String)
    /// The stream ended: the assembled assistant message.
    case completion(identity: CapabilityRequestIdentity, message: Message)
    /// The stream was interrupted: the preserved partial content, incomplete.
    case interruption(identity: CapabilityRequestIdentity, partialContent: String)
}
