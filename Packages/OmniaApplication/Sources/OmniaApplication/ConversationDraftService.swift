import OmniaDomain

/// Durable unsent text drafts keyed by conversation identity. Configuration is
/// the single persistence source for drafts; conversation history remains the
/// source for accepted messages.
public actor ConversationDraftService {
    private let configurationService: ConfigurationService

    public init(configurationService: ConfigurationService) {
        self.configurationService = configurationService
    }

    public func draft(for conversation: ConversationIdentity) async throws -> String {
        try await configurationService.value(
            for: Self.key(for: conversation),
            at: .workspaceOverride
        ) ?? ""
    }

    public func save(
        _ draft: String,
        for conversation: ConversationIdentity
    ) async throws {
        if draft.isEmpty {
            try await remove(for: conversation)
        } else {
            try await configurationService.store(
                draft,
                for: Self.key(for: conversation),
                at: .workspaceOverride
            )
        }
    }

    public func remove(for conversation: ConversationIdentity) async throws {
        try await configurationService.remove(
            Self.key(for: conversation),
            at: .workspaceOverride
        )
    }

    public static func key(
        for conversation: ConversationIdentity
    ) -> ConfigurationKey<String> {
        ConfigurationKey("conversationDraft.\(conversation.canonicalString)")
    }
}
