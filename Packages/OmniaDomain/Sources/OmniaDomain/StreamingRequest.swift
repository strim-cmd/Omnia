/// A streaming request: the message history and the requested model
/// (DES-009 §3.11.1).
///
/// Immutable and equal by content (ARC-003). Carries the typed request identity
/// (DES-002) and the model reference; raw identity or model values are never
/// used (DES-004 — Strong typing). It contains no provider-specific concept
/// (ARC-004).
public struct StreamingRequest: Equatable, Sendable {
    /// The typed identity of this request.
    public let identity: CapabilityRequestIdentity
    /// The full message history, in order.
    public let history: [Message]
    /// The requested model.
    public let model: ModelReference
    /// The exact provider selected for this request, when explicitly resolved.
    public let provider: ProviderIdentity?

    /// Creates a streaming request.
    public init(
        identity: CapabilityRequestIdentity,
        history: [Message],
        model: ModelReference,
        provider: ProviderIdentity? = nil
    ) {
        self.identity = identity
        self.history = history
        self.model = model
        self.provider = provider
    }
}
