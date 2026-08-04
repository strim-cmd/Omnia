/// A text generation request: the prompt and the requested model
/// (DES-009 §3.11.1).
///
/// Immutable and equal by content (ARC-003). Carries the typed request identity
/// (DES-002) and the model reference; raw identity or model values are never
/// used (DES-004 — Strong typing). It contains no provider-specific concept
/// (ARC-004).
public struct TextGenerationRequest: Equatable, Sendable {
    /// The typed identity of this request.
    public let identity: CapabilityRequestIdentity
    /// The prompt to generate text from.
    public let prompt: String
    /// The requested model.
    public let model: ModelReference

    /// Creates a text generation request.
    public init(
        identity: CapabilityRequestIdentity,
        prompt: String,
        model: ModelReference
    ) {
        self.identity = identity
        self.prompt = prompt
        self.model = model
    }
}
