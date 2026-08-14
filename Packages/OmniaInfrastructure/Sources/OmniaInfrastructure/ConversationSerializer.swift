import Foundation
import OmniaDomain

/// The stored representation of a `Message` value object (DES-010 §3.3).
///
/// The role is stored by its stable serialized name; content is stored as-is.
internal struct MessageDTO: Codable, Sendable {
    let role: String
    let content: String
}

/// The stored representation of `ConversationStreamingState` (DES-010 §3.3).
///
/// The state name selects the case; `partialContent` is present exactly when
/// the case carries it, preserving the interrupted-stream invariant that
/// partial content is never silently discarded (ARC-001, DES-009 §3.3).
internal struct ConversationStreamingStateDTO: Codable, Sendable {
    let state: String
    let partialContent: String?
}

/// The stored representation of a `Conversation` aggregate (DES-010 §3.3).
///
/// The history is stored in order — the full message history is a preserved
/// user-owned record, and its order round-trips exactly (DES-009 §3.3,
/// ARC-005).
internal struct ConversationDTO: Codable, Sendable {
    let identity: ConversationIdentity
    let history: [MessageDTO]
    let streamingState: ConversationStreamingStateDTO
    /// Added in v1.0. Missing in pre-v1 documents and therefore decoded as nil.
    let modelSelection: ProviderModelSelection?

    init(
        identity: ConversationIdentity,
        history: [MessageDTO],
        streamingState: ConversationStreamingStateDTO,
        modelSelection: ProviderModelSelection? = nil
    ) {
        self.identity = identity
        self.history = history
        self.streamingState = streamingState
        self.modelSelection = modelSelection
    }
}

/// Maps a `Conversation` aggregate to and from its stored representation
/// (DES-010 §3.3).
///
/// The serializer owns no business rules (ARC-005); it stores and restores the
/// aggregate exactly as the Domain defines it, preserving the full message
/// history in order and the streaming state through the aggregate's own public
/// transitions — it never reaches into the aggregate's private state (DES-009
/// §3.3).
internal struct ConversationSerializer: Sendable {
    /// Returns the stored representation of `conversation`.
    func toDTO(_ conversation: Conversation) -> ConversationDTO {
        ConversationDTO(
            identity: conversation.identity,
            history: conversation.history.map {
                MessageDTO(role: $0.role.serializedName, content: $0.content)
            },
            streamingState: Self.streamingStateDTO(from: conversation.streamingState),
            modelSelection: conversation.modelSelection
        )
    }

    /// Restores a `Conversation` from its stored representation.
    ///
    /// - Throws: `RepositoryError.storageUnavailable` when the stored form is
    ///   not a valid `Conversation` representation.
    func fromDTO(_ dto: ConversationDTO) throws -> Conversation {
        var conversation = Conversation(
            identity: dto.identity,
            modelSelection: dto.modelSelection
        )
        for message in dto.history {
            guard let role = MessageRole(serializedName: message.role) else {
                throw RepositoryError.storageUnavailable
            }
            try conversation.append(Message(role: role, content: message.content))
        }
        try Self.restore(streamingState: dto.streamingState, into: &conversation)
        return conversation
    }

    /// Encodes `conversation` to its deterministic JSON stored form.
    ///
    /// - Throws: `RepositoryError.storageUnavailable` when the aggregate cannot
    ///   be encoded.
    func encode(_ conversation: Conversation) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(toDTO(conversation))
    }

    /// Restores a `Conversation` from its JSON stored form.
    ///
    /// - Throws: `RepositoryError.storageUnavailable` when the stored form is
    ///   not a valid `Conversation` representation.
    func decode(from data: Data) throws -> Conversation {
        let dto: ConversationDTO
        do {
            dto = try JSONDecoder().decode(ConversationDTO.self, from: data)
        } catch {
            throw RepositoryError.storageUnavailable
        }
        return try fromDTO(dto)
    }

    /// Replays the stored streaming state through the aggregate's own public
    /// transitions; the history is restored before any stream begins, so the
    /// streaming invariants of the aggregate are preserved (DES-009 §3.3).
    private static func restore(
        streamingState dto: ConversationStreamingStateDTO,
        into conversation: inout Conversation
    ) throws {
        switch (dto.state, dto.partialContent) {
        case ("idle", _):
            return
        case ("streaming", let partialContent?):
            try conversation.beginStreaming()
            try conversation.appendPartial(partialContent)
        case ("interrupted", let partialContent?):
            try conversation.beginStreaming()
            try conversation.appendPartial(partialContent)
            try conversation.interruptStreaming()
        default:
            throw RepositoryError.storageUnavailable
        }
    }

    private static func streamingStateDTO(
        from state: ConversationStreamingState
    ) -> ConversationStreamingStateDTO {
        switch state {
        case .idle:
            return ConversationStreamingStateDTO(state: "idle", partialContent: nil)
        case .streaming(let partialContent):
            return ConversationStreamingStateDTO(state: "streaming", partialContent: partialContent)
        case .interrupted(let partialContent):
            return ConversationStreamingStateDTO(state: "interrupted", partialContent: partialContent)
        }
    }
}

private extension MessageRole {
    var serializedName: String {
        switch self {
        case .system: return "system"
        case .user: return "user"
        case .assistant: return "assistant"
        }
    }

    init?(serializedName: String) {
        switch serializedName {
        case "system": self = .system
        case "user": self = .user
        case "assistant": self = .assistant
        default: return nil
        }
    }
}
