/// A text generation response: the produced text (DES-009 §3.11.1).
///
/// Immutable and equal by content (ARC-003). It contains no provider-specific
/// concept (ARC-004).
public struct TextGenerationResponse: Equatable, Sendable {
    /// The produced text.
    public let text: String

    /// Creates a text generation response.
    public init(text: String) {
        self.text = text
    }
}
