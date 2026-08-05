import OmniaApplication
import OmniaFoundation

/// The ready-to-render state of the conversation list: the ordered
/// conversation list items and the empty and error conditions the list
/// presents (DES-012 §3.2, Conversation module, ARC-007).
///
/// The state is owned by the Presentation layer and composed from the
/// `ConversationService` it renders — create, select, and delete (DES-011
/// §3.2, ARC-006). It is session state, never a Domain or Application concept
/// (DES-011 §3.7), immutable, `Equatable` and `Sendable`, and owns no business
/// logic (ARC-002).
///
/// The error condition carries the typed failure the service surfaced — the
/// Domain `RepositoryError`, presented as it is, never wrapped (DES-011 §3.6,
/// DES-009 §3.9); no failure is silent (ARC-001). The state never holds a
/// credential or provider-specific detail (ARC-001, ARC-004, ARC-005).
public struct ConversationListState: Equatable, Sendable {
    /// The ordered conversation list items of the list.
    public let items: [ConversationListItem]
    /// The typed failure of the list operation, when the list is in an error
    /// condition.
    public let failure: RepositoryError?

    /// Creates a conversation list state from the ordered list items and the
    /// optional typed failure.
    public init(
        items: [ConversationListItem],
        failure: RepositoryError? = nil
    ) {
        self.items = items
        self.failure = failure
    }

    /// The empty condition: the list owns no conversations.
    public var isEmpty: Bool {
        items.isEmpty
    }

    /// The error condition: a list operation failed.
    public var hasError: Bool {
        failure != nil
    }
}
