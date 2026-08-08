import OmniaApplication
import OmniaFoundation

/// The ready-to-render state of the conversation screen: the message
/// presentations of the active conversation's history, the user input draft,
/// and the rendered streaming condition (DES-012 §3.2, Conversation module,
/// ARC-007).
///
/// The state is owned by the Presentation layer and composed from the
/// `SendMessageUseCase` it renders — the streaming send-message flow with the
/// Domain `StreamingUpdate` events rendered incrementally (DES-011 §3.3,
/// ARC-006). It is session state, never a Domain or Application concept
/// (DES-011 §3.7), immutable, `Equatable` and `Sendable`, and owns no business
/// logic (ARC-002).
///
/// The rendered streaming condition mirrors the Domain stream's active,
/// complete, and interrupted conditions without redefining them (DES-009
/// §3.11.4, DES-011 §3.3): the partial content on interruption is preserved
/// and presented, never discarded (ARC-001). The error condition carries the
/// typed failure the use case surfaced — `ApplicationValidationError`, and the
/// Domain `RepositoryError`, `CapabilityError`, and `CredentialStorageError`,
/// presented as they are, never wrapped (DES-011 §3.6, DES-009 §3.9); no
/// failure is silent (ARC-001). The state never holds a credential or
/// provider-specific detail (ARC-001, ARC-004, ARC-005).
public struct ConversationScreenState: Equatable, Sendable {
    /// A typed failure the conversation screen presents (DES-012 §3.2).
    ///
    /// The failure is the typed error the `SendMessageUseCase` surfaced —
    /// `ApplicationValidationError`, and the Domain `RepositoryError`,
    /// `CapabilityError`, and `CredentialStorageError` — presented as it is,
    /// never wrapped or redefined (DES-011 §3.6, DES-009 §3.9); an error the
    /// presentation layer cannot map to a typed failure is presented as
    /// `.unexpected`, still never silent (ARC-001).
    public enum Failure: Equatable, Sendable {
        /// Input validation failed at the application boundary.
        case application(ApplicationValidationError)
        /// A repository operation failed.
        case repository(RepositoryError)
        /// A provider capability or the streaming flow failed.
        case capability(CapabilityError)
        /// A credential storage operation failed.
        case credentialStorage(CredentialStorageError)
        /// The streaming flow failed with an error the presentation layer cannot
        /// map to a typed failure; the failure is never silent (ARC-001).
        case unexpected
    }

    /// The rendered streaming condition of the screen (DES-012 §3.2).
    ///
    /// The condition mirrors the Domain stream conditions of DES-009 §3.11.4
    /// and DES-011 §3.3 without redefining them: `active` renders the deltas
    /// of the stream incrementally, `complete` renders the assembled assistant
    /// message of the completion event (appended to the history), and
    /// `interrupted` renders the preserved partial content as incomplete —
    /// never discarded (ARC-001).
    public enum StreamingCondition: Equatable, Sendable {
        /// A stream is active, delivering content incrementally.
        case active(partialContent: String)
        /// The stream completed; the assembled assistant message is appended
        /// to the history.
        case complete
        /// The stream was interrupted; the partial content is preserved.
        case interrupted(partialContent: String)
    }

    /// The message presentations of the active conversation's history.
    public let messages: [MessagePresentation]
    /// The user input draft of the conversation screen.
    public let draft: String
    /// The rendered streaming condition, or `nil` when no stream condition is
    /// presented.
    public let streamingCondition: StreamingCondition?
    /// The typed failure of the send operation, when the screen is in an error
    /// condition.
    public let failure: Failure?

    /// Creates a conversation screen state from the message history, the user
    /// input draft, the rendered streaming condition, and the optional typed
    /// failure.
    public init(
        messages: [MessagePresentation],
        draft: String = "",
        streamingCondition: StreamingCondition? = nil,
        failure: Failure? = nil
    ) {
        self.messages = messages
        self.draft = draft
        self.streamingCondition = streamingCondition
        self.failure = failure
    }

    /// The error condition: a send operation failed.
    public var hasError: Bool {
        failure != nil
    }

    /// Returns a copy of the state with the rendered draft replaced, preserving
    /// the history, the streaming condition, and the failure. The draft is the
    /// user's in-progress composer input — rendered from state through a
    /// binding (UX audit U4) — so this is the way the shell preserves it across
    /// streaming updates and rehydrates it when a conversation is reopened.
    public func replacingDraft(_ draft: String) -> ConversationScreenState {
        ConversationScreenState(
            messages: messages,
            draft: draft,
            streamingCondition: streamingCondition,
            failure: failure
        )
    }

    /// Returns a copy of the state with the rendered streaming condition
    /// replaced, preserving the history, the draft, and the failure. The shell
    /// uses it to render a user-initiated stop as the interrupted condition the
    /// Domain preserved — the partial content is never discarded (ARC-001) —
    /// so the screen announces the interruption and the Stop affordance gives
    /// way to the composer (UX audit A4).
    public func replacingStreamingCondition(
        _ condition: StreamingCondition?
    ) -> ConversationScreenState {
        ConversationScreenState(
            messages: messages,
            draft: draft,
            streamingCondition: condition,
            failure: failure
        )
    }
}
