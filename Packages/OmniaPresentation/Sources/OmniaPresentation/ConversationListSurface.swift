import OmniaApplication
import OmniaFoundation

/// The conversation list presentation surface: create, select, and delete
/// conversations over `ConversationService`, and present the conversation list
/// as `ConversationListState` (DES-012 §3.3, Conversation module, ARC-007).
/// The v1.1.0 `create(in:)` creates a conversation in the presented workspace
/// over `ConversationService.createConversation(in:)` (DES-012 §3.3, DES-011
/// §3.8).
///
/// The surface is the seam through which the frozen `ConversationService` of
/// DES-011 §3.2 is delivered to the conversation list (DES-012 §3.6, ARC-006).
/// It receives the service through its public initializer and translates user
/// intent — creating, selecting, and deleting a conversation — into
/// use-case invocations, and it composes the ready-to-render list state from
/// the conversations the service loads (ARC-002, ADR-0001).
///
/// It consumes only the frozen DES-011 conversation surface and owns no
/// business rules (ARC-002): the `Conversation` aggregate owns the history and
/// streaming-state invariants, and the service sequences the repository
/// operations. The list item derivation — the display title and preview of a
/// row from the conversation's content — is deterministic presentation logic
/// (DES-012 §3.1, §3.3). The workspace whose conversations the list presents is
/// session state owned at the application edge (DES-011 §3.2); the surface
/// loads the conversations of the workspace it is given.
///
/// The failures the service surfaces — the Domain `RepositoryError` — are
/// presented as they are, never wrapped or redefined (DES-011 §3.6, DES-009
/// §3.9); no failure is silent (ARC-001). The surface never references a
/// concrete Infrastructure implementation and never performs networking,
/// persistence, or credential operations (ARC-002, ADR-0002).
///
/// The surface is a stateless, `Sendable` value type; every operation is
/// deterministic and testable on the Linux build environment (DES-012 §3.7).
public struct ConversationListSurface: Sendable {
    private let service: ConversationService

    /// Creates a conversation list surface over the given conversation
    /// service, delivered by the Composition Root (DES-012 §3.6).
    public init(service: ConversationService) {
        self.service = service
    }

    /// Loads the conversations of `workspace` and composes the ready-to-render
    /// list state (DES-012 §3.3).
    ///
    /// The state's items are derived from the loaded conversations — the
    /// display title and preview of each row (DES-012 §3.1). A failure surfaces
    /// as the Domain `RepositoryError`, as it is, never wrapped (DES-011 §3.6).
    public func load(in workspace: WorkspaceIdentity) async throws -> ConversationListState {
        let conversations = try await service.conversations(in: workspace)
        return ConversationListState(
            items: conversations.map { ConversationListItem(conversation: $0) }
        )
    }

    /// Creates a fresh empty conversation and persists it (DES-012 §3.3,
    /// DES-011 §3.2).
    public func create() async throws -> Conversation {
        try await service.createConversation()
    }

    /// Creates a fresh empty conversation in `workspace`, persists it, and
    /// attaches it to the workspace's membership — the create-in-workspace
    /// flow (DES-012 §3.3 v1.1.0, DES-011 §3.8).
    ///
    /// This is what the list renders for the user's create action: the new
    /// conversation belongs to the workspace the list presents and appears in
    /// the membership-driven list it renders — the list and the create action
    /// never diverge on the workspace (PRD-008). The workspace identity is
    /// received from the application edge — session state owned there, never
    /// selected by this surface (DES-011 §3.8, ARC-009). The v1.0.0 `create()`
    /// remains part of the surface but is not what the list renders (DES-011
    /// §3.2, §3.8).
    public func create(in workspace: WorkspaceIdentity) async throws -> Conversation {
        try await service.createConversation(in: workspace)
    }

    /// Selects the conversation with `identity`, or `nil` when none is stored
    /// (DES-012 §3.3).
    ///
    /// This is the operation an active conversation is resolved from; the
    /// active-conversation selection itself is session state owned at the
    /// application edge (DES-011 §3.2).
    public func select(_ identity: ConversationIdentity) async throws -> Conversation? {
        try await service.conversation(with: identity)
    }

    /// Persists the exact provider/model selection of one conversation.
    public func selectModel(
        _ selection: ProviderModelSelection?,
        for identity: ConversationIdentity
    ) async throws -> Conversation {
        try await service.selectModel(selection, for: identity)
    }

    /// Persists an explicit user title for one conversation.
    public func rename(
        _ identity: ConversationIdentity,
        to title: String
    ) async throws -> Conversation {
        try await service.rename(identity, to: title)
    }

    /// Deletes the conversation with `identity` — the user's removal of their
    /// own content (DES-012 §3.3, ARC-005).
    ///
    /// Removing a conversation that is not stored is not an error; the
    /// operation is idempotent (DES-009 §3.5).
    public func delete(_ identity: ConversationIdentity) async throws {
        try await service.delete(identity)
    }
}
