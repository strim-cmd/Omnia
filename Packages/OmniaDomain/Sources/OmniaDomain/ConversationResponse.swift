/// A conversation response: the assistant's reply, expressed as a `Message` so
/// it appends to the history (DES-009 §3.11.1).
///
/// Immutable and equal by content (ARC-003). It contains no provider-specific
/// concept (ARC-004).
public struct ConversationResponse: Equatable, Sendable {
    /// The assistant's reply message.
    public let message: Message

    /// Creates a conversation response.
    public init(message: Message) {
        self.message = message
    }
}
