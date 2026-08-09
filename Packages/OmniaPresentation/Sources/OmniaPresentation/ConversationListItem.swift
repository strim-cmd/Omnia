import OmniaApplication
import OmniaFoundation

/// A row of the conversation list: the identity and the ready-to-render
/// display content of a conversation (DES-012 §3.1, Conversation module,
/// ARC-007).
///
/// A conversation row is derived from the conversation's content — deriving
/// the display title and preview is presentation logic, the rendering of
/// state, never business logic (ARC-002, ADR-0001). The value type is
/// immutable, equal by content, `Equatable` and `Sendable`, and owns no
/// business logic (ARC-002, ARC-003).
///
/// The identity is the frozen `ConversationIdentity` vocabulary of DES-009
/// §3.3; a raw identity is never used (DES-002, DES-004).
public struct ConversationListItem: Equatable, Sendable {
    /// The conversation's stable identity.
    public let identity: ConversationIdentity
    /// The display title of the conversation row.
    public let displayTitle: String
    /// The display preview of the conversation row, when the conversation has
    /// content to preview.
    public let displayPreview: String?

    /// Creates a conversation list item with the given identity and display
    /// content.
    public init(
        identity: ConversationIdentity,
        displayTitle: String,
        displayPreview: String?
    ) {
        self.identity = identity
        self.displayTitle = displayTitle
        self.displayPreview = displayPreview
    }

    /// Creates a conversation list item derived from a conversation's content
    /// (DES-012 §3.1).
    ///
    /// The derivation is deterministic presentation logic: the display title is
    /// the first user message, or the first assistant message when the
    /// conversation has no user message, collapsed to a single line; the
    /// display preview is the most recent message collapsed to a single line,
    /// or `nil` for an empty conversation. The view layer provides any
    /// localized fallback title (`project UI standards`).
    public init(conversation: Conversation) {
        let titleMessage = conversation.history.first(where: { $0.role == .user })
            ?? conversation.history.first(where: { $0.role == .assistant })
        self.init(
            identity: conversation.identity,
            displayTitle: titleMessage.map { Self.singleLine($0.content) } ?? "",
            displayPreview: conversation.history.last.map { Self.singleLine($0.content) }
        )
    }

    /// Collapses the whitespace runs of `content` to single spaces — the
    /// single-line display form of a row's title and preview.
    private static func singleLine(_ content: String) -> String {
        content.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
