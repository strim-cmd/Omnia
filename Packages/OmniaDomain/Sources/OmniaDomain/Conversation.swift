import Foundation

/// The streaming state of a conversation (DES-009 §3.3, ARC-001).
///
/// The state records where a stream stands. An interruption preserves the
/// partial content already received and marks it incomplete; it is never
/// silently discarded (ARC-001 Streaming Interrupted).
public enum ConversationStreamingState: Equatable, Sendable {
    /// No stream is active.
    case idle
    /// A stream is active, delivering content incrementally.
    case streaming(partialContent: String)
    /// A stream was interrupted; the partial content is preserved.
    case interrupted(partialContent: String)
}

/// The failures a conversation stream can report (DES-009 §3.3).
public enum ConversationStreamError: Error, Equatable, Sendable {
    /// A stream is already active.
    case streamInProgress
    /// No stream is active for the requested operation.
    case notStreaming
}

public enum ConversationMetadataError: Error, Equatable, Sendable {
    /// A user-authored title contains no visible content after normalization.
    case invalidTitle
}

/// Records whether a durable title was derived from the first user input or
/// explicitly chosen by the user. A user title always wins when independently
/// updated metadata is merged with an in-flight generation snapshot.
public enum ConversationTitleOrigin: String, Equatable, Sendable {
    case automatic
    case user
}

/// The Conversation aggregate: a recorded interaction with identity and
/// continuity (ARC-003 Entity, DES-009 §3.3).
///
/// The aggregate owns its message history and its streaming state (ARC-007).
/// Messages are immutable value objects; the history is only ever appended to
/// and is always preserved. An interruption marks the partial content as
/// incomplete and never silently discards it; the full history is never lost
/// (ARC-001, DES-009 §3.3). The aggregate enforces no behavior beyond its own
/// invariants and owns no provider or storage behavior.
public struct Conversation: Equatable, Sendable {
    /// The conversation's stable identity.
    public let identity: ConversationIdentity
    /// The full message history, in order. It is only ever appended to.
    public private(set) var history: [Message]
    /// The conversation's current streaming state.
    public private(set) var streamingState: ConversationStreamingState
    /// The exact provider/model pair selected for this conversation.
    public private(set) var modelSelection: ProviderModelSelection?
    /// A durable display title. Automatic titles are derived locally from the
    /// first usable user input; an explicit user rename always takes precedence.
    public private(set) var title: String?
    public private(set) var titleOrigin: ConversationTitleOrigin
    /// Durable activity metadata used for deterministic list grouping/sorting.
    public let createdAt: Date
    public private(set) var updatedAt: Date

    /// Creates an empty conversation with the given identity.
    public init(
        identity: ConversationIdentity,
        modelSelection: ProviderModelSelection? = nil,
        title: String? = nil,
        titleOrigin: ConversationTitleOrigin = .automatic,
        createdAt: Date = Date(timeIntervalSince1970: 0),
        updatedAt: Date? = nil
    ) {
        self.identity = identity
        self.history = []
        self.streamingState = .idle
        self.modelSelection = modelSelection
        self.title = title
        self.titleOrigin = titleOrigin
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    /// The partial content of the active or interrupted stream, if any.
    public var partialContent: String? {
        switch streamingState {
        case .streaming(let partialContent), .interrupted(let partialContent):
            return partialContent
        case .idle:
            return nil
        }
    }

    /// Returns whether a stream is currently active.
    public var isStreaming: Bool {
        if case .streaming = streamingState {
            return true
        }
        return false
    }

    /// Replaces the conversation's explicit provider/model choice.
    /// Selection cannot change while the aggregate is streaming, preventing a
    /// stale in-flight operation from overwriting a newer routing choice.
    public mutating func selectModel(_ selection: ProviderModelSelection?) throws {
        guard !isStreaming else {
            throw ConversationStreamError.streamInProgress
        }
        modelSelection = selection
    }

    /// Persists an explicit user title. Automatic title derivation can never
    /// overwrite this value.
    public mutating func rename(to value: String, at timestamp: Date? = nil) throws {
        let normalized = Self.normalizedTitle(value)
        guard !normalized.isEmpty else {
            throw ConversationMetadataError.invalidTitle
        }
        title = String(normalized.prefix(160))
        titleOrigin = .user
        recordActivity(timestamp)
    }

    /// Merges metadata from a newer repository snapshot without touching this
    /// aggregate's message or streaming state. This is used when generation
    /// completes from an older in-memory snapshot after a concurrent rename.
    public mutating func mergeMetadata(from latest: Conversation) {
        guard latest.identity == identity else { return }
        if latest.titleOrigin == .user {
            title = latest.title
            titleOrigin = .user
        } else if titleOrigin != .user, let latestTitle = latest.title {
            title = latestTitle
        }
        updatedAt = max(updatedAt, latest.updatedAt)
    }

    /// Appends `message` to the history.
    ///
    /// Rejected while a stream is active; the history is preserved and never
    /// rewritten (DES-009 §3.3).
    public mutating func append(_ message: Message, at timestamp: Date? = nil) throws {
        guard !isStreaming else {
            throw ConversationStreamError.streamInProgress
        }
        history.append(message)
        if titleOrigin == .automatic, title == nil, message.role == .user {
            let contentTitle = Self.normalizedTitle(message.content)
            let attachmentTitle = message.attachments.first.map {
                Self.normalizedTitle($0.fileName)
            } ?? ""
            let automatic = contentTitle.isEmpty ? attachmentTitle : contentTitle
            if !automatic.isEmpty {
                title = String(automatic.prefix(80))
            }
        }
        recordActivity(timestamp)
    }

    /// Starts a stream, ready to receive partial content.
    ///
    /// From `.idle` the stream starts empty. From `.interrupted` the stream is
    /// resumed: the preserved partial content is carried forward, never lost
    /// or overwritten (ARC-001, DES-009 §3.3).
    public mutating func beginStreaming() throws {
        switch streamingState {
        case .idle:
            streamingState = .streaming(partialContent: "")
        case .interrupted(let partialContent):
            streamingState = .streaming(partialContent: partialContent)
        case .streaming:
            throw ConversationStreamError.streamInProgress
        }
    }

    /// Appends `content` to the active stream's partial content.
    public mutating func appendPartial(_ content: String) throws {
        guard case .streaming(let partialContent) = streamingState else {
            throw ConversationStreamError.notStreaming
        }
        streamingState = .streaming(partialContent: partialContent + content)
    }

    /// Completes the stream: the accumulated partial content becomes an
    /// assistant message in the history, and the stream ends.
    public mutating func completeStreaming(at timestamp: Date? = nil) throws {
        guard case .streaming(let partialContent) = streamingState else {
            throw ConversationStreamError.notStreaming
        }
        history.append(Message(role: .assistant, content: partialContent))
        streamingState = .idle
        recordActivity(timestamp)
    }

    /// Interrupts the stream: the partial content is preserved and marked
    /// incomplete; the full history is never discarded (ARC-001, DES-009 §3.3).
    public mutating func interruptStreaming(at timestamp: Date? = nil) throws {
        guard case .streaming(let partialContent) = streamingState else {
            throw ConversationStreamError.notStreaming
        }
        streamingState = .interrupted(partialContent: partialContent)
        recordActivity(timestamp)
    }

    private mutating func recordActivity(_ timestamp: Date?) {
        guard let timestamp else { return }
        updatedAt = max(updatedAt, timestamp)
    }

    private static func normalizedTitle(_ value: String) -> String {
        value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
