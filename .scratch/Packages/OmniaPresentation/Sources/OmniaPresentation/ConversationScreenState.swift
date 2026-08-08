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
/// failure is silent (ARC-001). The state also renders the provider selection —
/// the provider connections of the settings surface and the user's explicit
/// selection, composed by the shell (UX audit V2) — presenting only the generic
/// connection state of each provider, never provider-specific detail (ARC-001,
/// ARC-004, ARC-005).
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

    /// The ready-to-render provider selection of the screen: the provider
    /// connections the user can choose to serve a conversation, the user's
    /// explicit selection, and the error condition when the provider list could
    /// not be loaded (DES-012 §3.2, Conversation module, ARC-007).
    ///
    /// The selection is composed by the shell — the provider connections of the
    /// settings surface, the typed settings failure, and the user's persisted
    /// selection (UX audit V2) — and presented by the conversation screen's
    /// provider selector. It presents the generic connection state — identity,
    /// display name, and lifecycle state — and never changes the interface per
    /// provider or exposes provider-specific detail (PRODUCT_PRINCIPLES —
    /// Provider Independence, ARC-004).
    ///
    /// The frozen selection policy of DES-009 §3.2 skips a user selection that
    /// is not selectable and applies the next step, so the presentation
    /// distinguishes a selected provider connection that is not available and
    /// announces that the automatic selection applies instead — the explicit
    /// choice is never silently dropped (ARC-001, ARC-004). A selection that is
    /// not among the presented provider connections is normalized to no
    /// selection.
    ///
    /// The value type is immutable, equal by content, `Equatable` and
    /// `Sendable`, and owns no business logic (ARC-002, ARC-003).
    public struct ProviderSelection: Equatable, Sendable {
        /// The provider connections the user can select from, in the
        /// deterministic order the settings surface lists them (DES-011 §3.4).
        public let providers: [ProviderConnectionListItem]
        /// The user's explicit selection, or `nil` when no provider is selected
        /// and the automatic selection applies (DES-009 §3.2).
        public let selected: ProviderIdentity?
        /// The error condition: the provider connections could not be loaded.
        public let failure: Failure?

        /// Creates a provider selection with the given provider connections,
        /// explicit selection, and optional error condition.
        public init(
            providers: [ProviderConnectionListItem],
            selected: ProviderIdentity? = nil,
            failure: Failure? = nil
        ) {
            self.providers = providers
            self.selected = selected
            self.failure = failure
        }

        /// The empty condition: no provider connection is configured.
        public var isEmpty: Bool {
            providers.isEmpty
        }

        /// The selected provider connection, or `nil` when the selection is not
        /// among the presented provider connections.
        public var selectedItem: ProviderConnectionListItem? {
            guard let selected else { return nil }
            return providers.first { $0.identity == selected }
        }

        /// The availability of the selected provider connection: a selection is
        /// available only when its provider connection is ready (DES-009 §3.2);
        /// the frozen selection policy skips a selection that is not selectable,
        /// so an unavailable selection is announced by the presentation, never
        /// silent (ARC-001).
        public var selectedIsAvailable: Bool {
            guard let item = selectedItem else { return false }
            return Self.isAvailable(item.state)
        }

        /// The availability of a provider connection for serving a conversation:
        /// the provider connection is ready (DES-009 §3.1, §3.2).
        public static func isAvailable(_ state: ProviderState) -> Bool {
            state == .ready
        }

        /// Composes a provider selection from the provider connections and the
        /// error condition of the settings state the shell rendered, and the
        /// user's explicit selection (DES-012 §3.2).
        ///
        /// The error condition is presented only when no provider connection is
        /// presented: with connections to present, the selector presents them
        /// and the settings failure is out of its scope; with none — the
        /// connections could not be loaded — the typed settings failure is
        /// presented as the selector's failure, as it is, never wrapped,
        /// never silent (ARC-001, DES-011 §3.6). A selection that is not among
        /// the presented provider connections is normalized to no selection.
        public static func composed(
            providers: [ProviderConnectionListItem],
            settingsFailure: SettingsState.Failure?,
            selected: ProviderIdentity?
        ) -> ProviderSelection {
            let normalizedSelected = providers.contains { $0.identity == selected } ? selected : nil
            let failure: Failure? = providers.isEmpty ? settingsFailure.map(Self.failure(from:)) : nil
            return ProviderSelection(providers: providers, selected: normalizedSelected, failure: failure)
        }

        /// Maps the typed failure of the settings surface into the conversation
        /// screen's typed failure, as it is, never wrapped (DES-011 §3.6,
        /// DES-009 §3.9).
        private static func failure(from settingsFailure: SettingsState.Failure) -> Failure {
            switch settingsFailure {
            case .application(let error): return .application(error)
            case .repository(let error): return .repository(error)
            case .credentialStorage(let error): return .credentialStorage(error)
            }
        }
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
    /// The ready-to-render provider selection of the screen, or `nil` while the
    /// provider connections have not loaded yet (UX audit V2).
    public let providerSelection: ProviderSelection?

    /// Creates a conversation screen state from the message history, the user
    /// input draft, the rendered streaming condition, the optional typed
    /// failure, and the ready-to-render provider selection.
    public init(
        messages: [MessagePresentation],
        draft: String = "",
        streamingCondition: StreamingCondition? = nil,
        failure: Failure? = nil,
        providerSelection: ProviderSelection? = nil
    ) {
        self.messages = messages
        self.draft = draft
        self.streamingCondition = streamingCondition
        self.failure = failure
        self.providerSelection = providerSelection
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
            failure: failure,
            providerSelection: providerSelection
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
            failure: failure,
            providerSelection: providerSelection
        )
    }

    /// Returns a copy of the state with the ready-to-render provider selection
    /// replaced, preserving the history, the draft, the streaming condition,
    /// and the failure. The shell uses it to compose the provider selection of
    /// the settings surface and the user's explicit selection onto every
    /// rendered state of the conversation screen (UX audit V2).
    public func replacingProviderSelection(
        _ selection: ProviderSelection?
    ) -> ConversationScreenState {
        ConversationScreenState(
            messages: messages,
            draft: draft,
            streamingCondition: streamingCondition,
            failure: failure,
            providerSelection: selection
        )
    }
}
