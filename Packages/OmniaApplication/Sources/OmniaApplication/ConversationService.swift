import OmniaDomain

/// The conversation application service: create, load (select), list by
/// workspace membership, and delete conversations, and read message history
/// (DES-011 §3.2). The v1.1.0 `createConversation(in:)` creates a conversation
/// and attaches it to a workspace's membership in one application operation
/// (DES-011 §3.8).
///
/// The service orchestrates the frozen `ConversationRepository` and the
/// workspace membership for listing (DES-009 §3.3, §3.5). It owns no business
/// rules: the `Conversation` aggregate owns the history and streaming-state
/// invariants, and the service only sequences repository operations (ARC-002,
/// ADR-0001). It exposes no separate history type — the full message history is
/// owned by the aggregate and returned with it (DES-011 §3.2).
///
/// Every input is a well-formed typed identity (DES-002): the `Identifier`
/// primitive makes an invalid identity unexpressible, so this surface has no
/// invalid input to reject; the boundary validation required by ARC-009 is
/// applied where invalid values are expressible, on the send-message and
/// provider-connection surfaces (DES-011 §3.6).
///
/// The repositories are injected by the Composition Root; the service never
/// references an Infrastructure implementation (ARC-006, ARC-009).
public struct ConversationService: Sendable {
    private let conversationRepository: any ConversationRepository
    private let workspaceRepository: any WorkspaceRepository
    private let defaultModelSelection: @Sendable () async throws -> ProviderModelSelection?
    private let cleanupAttachments: @Sendable ([MessageAttachment]) async throws -> Void

    /// Creates a conversation service over the given repository contracts.
    public init(
        conversationRepository: any ConversationRepository,
        workspaceRepository: any WorkspaceRepository,
        defaultModelSelection: @escaping @Sendable () async throws -> ProviderModelSelection? = { nil },
        cleanupAttachments: @escaping @Sendable (
            [MessageAttachment]
        ) async throws -> Void = { _ in }
    ) {
        self.conversationRepository = conversationRepository
        self.workspaceRepository = workspaceRepository
        self.defaultModelSelection = defaultModelSelection
        self.cleanupAttachments = cleanupAttachments
    }

    /// Creates an empty conversation with a fresh identity and persists it
    /// (DES-002).
    public func createConversation() async throws -> Conversation {
        let conversation = Conversation(
            identity: ConversationIdentity(),
            modelSelection: try await defaultModelSelection()
        )
        try await conversationRepository.save(conversation)
        return conversation
    }

    /// Creates an empty conversation with a fresh identity, persists it, and
    /// attaches it to `workspace`'s membership as one application operation
    /// (DES-011 §3.8).
    ///
    /// The workspace is loaded before the conversation is created, so a missing
    /// workspace fails the whole operation before any conversation is created —
    /// create and attach are one atomic application operation (PRD-008). The
    /// workspace's `adding(conversation:)` is applied and the new value is
    /// persisted (DES-009 §3.4).
    public func createConversation(in workspace: WorkspaceIdentity) async throws -> Conversation {
        guard let workspace = try await workspaceRepository.workspace(with: workspace) else {
            throw ApplicationValidationError.invalid(reason: "The workspace is not stored.")
        }
        let conversation = Conversation(
            identity: ConversationIdentity(),
            modelSelection: try await defaultModelSelection()
        )
        try await conversationRepository.save(conversation)
        let updated = workspace.adding(conversation: conversation.identity)
        try await workspaceRepository.save(updated)
        return conversation
    }

    /// Returns the conversation with `identity`, or `nil` when none is stored.
    ///
    /// This is the selection operation an active conversation is resolved from
    /// (DES-011 §3.2).
    public func conversation(with identity: ConversationIdentity) async throws -> Conversation? {
        try await conversationRepository.conversation(with: identity)
    }

    /// Persists the exact provider/model pair for one conversation.
    public func selectModel(
        _ selection: ProviderModelSelection?,
        for identity: ConversationIdentity
    ) async throws -> Conversation {
        guard var conversation = try await conversationRepository.conversation(with: identity) else {
            throw ApplicationValidationError.invalid(reason: "The conversation is not stored.")
        }
        try conversation.selectModel(selection)
        try await conversationRepository.save(conversation)
        return conversation
    }

    /// Returns the conversations that belong to `workspace`, via the
    /// workspace's membership, in identity order (DES-011 §3.2).
    ///
    /// The membership lists conversation identities; each identity is loaded by
    /// the repository, and an identity with no stored conversation is skipped.
    /// A workspace that is not stored owns no conversations and yields an empty
    /// list. The result is deterministic (ARC-001, DES-011 §5).
    public func conversations(in workspace: WorkspaceIdentity) async throws -> [Conversation] {
        guard let workspace = try await workspaceRepository.workspace(with: workspace) else {
            return []
        }
        let identities = workspace.conversationIdentities.sorted {
            $0.canonicalString < $1.canonicalString
        }
        var conversations: [Conversation] = []
        conversations.reserveCapacity(identities.count)
        for identity in identities {
            if let conversation = try await conversationRepository.conversation(with: identity) {
                conversations.append(conversation)
            }
        }
        return conversations
    }

    /// Removes the conversation with `identity` (user ownership, ARC-005).
    ///
    /// Removing a conversation that is not stored is not an error; the
    /// operation is idempotent (DES-009 §3.5).
    public func delete(_ identity: ConversationIdentity) async throws {
        let attachments = try await conversationRepository
            .conversation(with: identity)?
            .history
            .flatMap(\.attachments) ?? []
        try await conversationRepository.delete(identity)
        try await cleanupAttachments(attachments)
    }
}
