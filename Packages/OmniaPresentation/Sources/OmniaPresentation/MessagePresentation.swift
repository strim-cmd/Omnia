import OmniaApplication
import OmniaFoundation

/// The presentation form of a Domain `Message` for the conversation screen:
/// the role and the markdown content of the message (DES-012 §3.1,
/// Conversation module, ARC-007).
///
/// The value type distinguishes user, assistant, and system content through
/// the frozen `MessageRole` vocabulary of DES-009 §3.3 and carries the message
/// content as the single `MarkdownContent` content model of the package
/// (§3.3.1). It is immutable, equal by content, `Equatable` and `Sendable`,
/// and owns no business logic (ARC-002, ARC-003). It never replaces the Domain
/// `Message` it presents (DES-011 §3.1).
public struct MessagePresentation: Equatable, Sendable {
    /// The role this message plays in the conversation.
    public let role: MessageRole
    /// The markdown content of the message, or `nil` when the message has no
    /// content to render.
    public let content: MarkdownContent?
    /// Safe persisted attachment metadata. Payload bytes never enter
    /// Presentation state.
    public let attachments: [MessageAttachment]

    /// Creates a message presentation with the given role and markdown
    /// content.
    public init(
        role: MessageRole,
        content: MarkdownContent?,
        attachments: [MessageAttachment] = []
    ) {
        self.role = role
        self.content = content
        self.attachments = attachments
    }

    /// Creates the presentation of a Domain `Message` (DES-012 §3.1): the
    /// role maps directly, and the message content is segmented into the
    /// markdown content model. An empty message carries no content.
    public init(message: Message) {
        self.init(
            role: message.role,
            content: message.content.isEmpty ? nil : MarkdownContent(markdown: message.content),
            attachments: message.attachments
        )
    }
}
