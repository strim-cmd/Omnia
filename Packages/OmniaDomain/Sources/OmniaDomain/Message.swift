/// The role a message plays in a conversation.
///
/// Roles follow the OpenAI-compatible conversation model the product targets
/// (PRODUCT_CHARTER). A tool role is a future extension point and is not part
/// of this contract (ARC-001, DES-009).
public enum MessageRole: Equatable, Hashable, Sendable {
    /// Sets the context for the conversation.
    case system
    /// A message from the user.
    case user
    /// A message from the assistant.
    case assistant
}

/// A contribution to a conversation (ARC-005, ARC-007).
///
/// A message is an immutable value object; a change produces a new value, never
/// an in-place mutation (ARC-001, ARC-003). It carries no identity; the
/// Conversation aggregate owns its message history (DES-009 §3.3).
public struct Message: Equatable, Hashable, Sendable {
    /// The role this message plays.
    public let role: MessageRole
    /// The message content.
    public let content: String

    /// Creates a message contribution with the given role and content.
    public init(role: MessageRole, content: String) {
        self.role = role
        self.content = content
    }
}
