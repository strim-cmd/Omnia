import Foundation
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
    private let now: @Sendable () -> Date

    /// Creates a conversation service over the given repository contracts.
    public init(
        conversationRepository: any ConversationRepository,
        workspaceRepository: any WorkspaceRepository,
        defaultModelSelection: @escaping @Sendable () async throws -> ProviderModelSelection? = { nil },
        cleanupAttachments: @escaping @Sendable (
            [MessageAttachment]
        ) async throws -> Void = { _ in },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.conversationRepository = conversationRepository
        self.workspaceRepository = workspaceRepository
        self.defaultModelSelection = defaultModelSelection
        self.cleanupAttachments = cleanupAttachments
        self.now = now
    }

    /// Creates an empty conversation with a fresh identity and persists it
    /// (DES-002).
    public func createConversation() async throws -> Conversation {
        let timestamp = now()
        let conversation = Conversation(
            identity: ConversationIdentity(),
            modelSelection: try await defaultModelSelection(),
            createdAt: timestamp,
            updatedAt: timestamp
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
        let timestamp = now()
        let conversation = Conversation(
            identity: ConversationIdentity(),
            modelSelection: try await defaultModelSelection(),
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try await conversationRepository.save(conversation)
        let updated = workspace.adding(conversation: conversation.identity)
        do {
            try await workspaceRepository.save(updated)
        } catch {
            // The conversation is not reachable until membership persists. If
            // the second half fails, remove the just-created record so a rapid
            // retry cannot accumulate invisible orphan conversations.
            try? await conversationRepository.delete(conversation.identity)
            throw error
        }
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

    /// Persists a user-authored title without changing message history or the
    /// per-conversation provider/model choice.
    public func rename(
        _ identity: ConversationIdentity,
        to title: String
    ) async throws -> Conversation {
        guard var conversation = try await conversationRepository.conversation(with: identity) else {
            throw ApplicationValidationError.invalid(reason: "The conversation is not stored.")
        }
        do {
            try conversation.rename(to: title, at: now())
        } catch ConversationMetadataError.invalidTitle {
            throw ApplicationValidationError.invalid(
                reason: "The conversation title cannot be empty."
            )
        }
        try await conversationRepository.save(conversation)
        return conversation
    }

    /// Returns the conversations that belong to `workspace`, via the
    /// workspace's membership, in identity order (DES-011 §3.2).
    ///
    /// The membership lists conversation identities; each identity is loaded by
    /// the repository, and an identity with no stored conversation is skipped.
    /// A workspace that is not stored owns no conversations and yields an empty
    /// list. Results are ordered by most recent activity, with stable creation
    /// and identity tie-breakers (ARC-001, DES-011 §5).
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
        return conversations.sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.identity.canonicalString < $1.identity.canonicalString
        }
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

        let owningWorkspaces = try await workspaceRepository
            .allWorkspaces()
            .filter { $0.contains(conversation: identity) }
        var detachedWorkspaces: [Workspace] = []
        do {
            for workspace in owningWorkspaces {
                // Record the original before attempting the save: a repository
                // may persist and still surface an I/O failure, and restoration
                // remains safe when it did not.
                detachedWorkspaces.append(workspace)
                try await workspaceRepository.save(
                    workspace.removing(conversation: identity)
                )
            }
            try await conversationRepository.delete(identity)
        } catch {
            // Keep the record reachable when either membership persistence or
            // conversation deletion fails. Restoration is best-effort because
            // the original repository failure remains the actionable cause.
            for workspace in detachedWorkspaces {
                try? await workspaceRepository.save(workspace)
            }
            throw error
        }
        try await cleanupAttachments(attachments)
    }
}
