import OmniaDomain

/// A request to send a user message in a conversation (DES-011 §3.1).
///
/// The conversation to drive, the user's message, and the optional selection
/// preferences the Domain selection service honors: `nil` means no choice was
/// expressed, and the service falls through its documented priority (ARC-004,
/// DES-009 §3.2).
///
/// Immutable and equal by content; a change produces a new value, never an
/// in-place mutation (ARC-003). It owns no business logic: input is validated
/// at the application boundary, by the send-message use case (ARC-009).
///
/// Owned by the Conversation module (DES-011 §3.1).
public struct SendMessageRequest: Equatable, Sendable {
    /// The conversation to drive.
    public let conversation: ConversationIdentity
    /// The user's message.
    public let message: Message
    /// The provider the user explicitly selected, if any.
    public let userSelection: ProviderIdentity?
    /// The provider preference of the active workspace, if any.
    public let workspacePreference: ProviderIdentity?
    /// The provider preference for the requested capability, if any.
    public let capabilityPreference: ProviderIdentity?
    /// The exact per-conversation provider/model selection, when present.
    public let modelSelection: ProviderModelSelection?

    /// Creates a send-message request; the selection preferences are optional
    /// and default to `nil` (no choice expressed).
    public init(
        conversation: ConversationIdentity,
        message: Message,
        userSelection: ProviderIdentity? = nil,
        workspacePreference: ProviderIdentity? = nil,
        capabilityPreference: ProviderIdentity? = nil,
        modelSelection: ProviderModelSelection? = nil
    ) {
        self.conversation = conversation
        self.message = message
        self.userSelection = userSelection
        self.workspacePreference = workspacePreference
        self.capabilityPreference = capabilityPreference
        self.modelSelection = modelSelection
    }
}
