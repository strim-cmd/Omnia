import OmniaApplication
import OmniaFoundation

/// The ready-to-render state of the settings surface: the provider connection
/// list items of the configured connections, the configuration values the
/// surface presents, and the compose, endpoint-edit, model-edit, and error
/// conditions (DES-012 §3.2, Settings module, ARC-007).
///
/// The state is owned by the Presentation layer and composed from the
/// `ProviderConnectionService` and `ConfigurationService` it renders (DES-011
/// §3.4, §3.5, ARC-006). It is session state, never a Domain or Application
/// concept (DES-011 §3.7), immutable, `Equatable` and `Sendable`, and owns no
/// business logic (ARC-002).
///
/// The credential boundary is absolute: the state holds only the configured
/// connection state — never a credential, a raw secret, or provider-specific
/// detail (ARC-001, ARC-004, ARC-005). The configuration values are typed
/// through the frozen `ConfigurationKey` and `ConfigurationLevel` vocabulary
/// (DES-009 §3.6, DES-011 §3.5); raw or untyped values are never presented.
/// The error condition carries the typed failure the services surfaced —
/// `ApplicationValidationError`, and the Domain `RepositoryError` and
/// `CredentialStorageError`, presented as they are, never wrapped (DES-011
/// §3.6, DES-009 §3.9); no failure is silent (ARC-001).
public struct SettingsState: Equatable, Sendable {
    /// A typed failure the settings surface presents (DES-012 §3.2).
    ///
    /// The failure is the typed error the services surfaced —
    /// `ApplicationValidationError`, and the Domain `RepositoryError` and
    /// `CredentialStorageError` — presented as it is, never wrapped or
    /// redefined (DES-011 §3.6, DES-009 §3.9); no failure is silent (ARC-001).
    public enum Failure: Equatable, Sendable {
        /// Input validation failed at the application boundary.
        case application(ApplicationValidationError)
        /// A repository operation failed.
        case repository(RepositoryError)
        /// A credential storage operation failed.
        case credentialStorage(CredentialStorageError)
    }

    /// A configuration value the settings surface presents: a typed
    /// configuration key bound to its typed value (DES-012 §3.2, DES-011
    /// §3.5).
    ///
    /// The key is the frozen `ConfigurationKey<String>` vocabulary of DES-009
    /// §3.6; the value is the typed value the surface reads through
    /// `ConfigurationService` and presents. Raw or untyped values are never
    /// presented (§3.4).
    public struct ConfigurationItem: Equatable, Sendable {
        /// The typed configuration key.
        public let key: ConfigurationKey<String>
        /// The typed value bound to the key.
        public let value: String

        /// Creates a configuration item from the typed key and its typed
        /// value.
        public init(key: ConfigurationKey<String>, value: String) {
            self.key = key
            self.value = value
        }
    }

    /// The endpoint-edit condition of the settings surface (DES-012 §3.2,
    /// Settings module): the provider connection whose OpenAI-compatible
    /// endpoint is being edited, the declared display name presented as the
    /// editor's context, and the endpoint currently recorded — the value the
    /// editor pre-fills (UX audit U7).
    ///
    /// The condition holds only the configured connection state and the
    /// recorded endpoint — never a credential or provider-specific detail
    /// (ARC-001, ARC-004, ARC-005). The endpoint is connection configuration
    /// the user owns (ARC-005, DES-011 §3.9).
    public struct Editing: Equatable, Sendable {
        /// The identity of the provider connection being edited.
        public let identity: ProviderIdentity
        /// The declared display name of the provider connection.
        public let displayName: String
        /// The endpoint currently recorded for the connection, empty when none
        /// is recorded.
        public let currentEndpoint: String

        /// Creates the endpoint-edit condition for the provider connection
        /// with the given identity, display name, and current endpoint.
        public init(
            identity: ProviderIdentity,
            displayName: String,
            currentEndpoint: String
        ) {
            self.identity = identity
            self.displayName = displayName
            self.currentEndpoint = currentEndpoint
        }
    }

    /// The model-edit condition of the settings surface (DES-012 §3.2,
    /// Settings module): the provider connection whose OpenAI-compatible model
    /// — the OmniRoute combo, or any provider model name — is being edited,
    /// the declared display name presented as the editor's context, and the
    /// model currently recorded — the value the editor pre-fills.
    ///
    /// The condition holds only the configured connection state and the
    /// recorded model — never a credential or provider-specific detail
    /// (ARC-001, ARC-004, ARC-005). The model is connection configuration the
    /// user owns (ARC-005, DES-011 §3.10), recorded at the provider-settings
    /// level under the documented `providerModel.<canonical>` key.
    public struct ModelEditing: Equatable, Sendable {
        /// The identity of the provider connection being edited.
        public let identity: ProviderIdentity
        /// The declared display name of the provider connection.
        public let displayName: String
        /// The model currently recorded for the connection, empty when none
        /// is recorded.
        public let currentModel: String

        /// Creates the model-edit condition for the provider connection with
        /// the given identity, display name, and current model.
        public init(
            identity: ProviderIdentity,
            displayName: String,
            currentModel: String
        ) {
            self.identity = identity
            self.displayName = displayName
            self.currentModel = currentModel
        }
    }

    /// The provider connection list items of the configured connections, in
    /// the deterministic order the service lists them (DES-011 §3.4).
    public let connections: [ProviderConnectionListItem]
    /// The configuration values the settings surface presents.
    public let configuration: [ConfigurationItem]
    /// The compose condition: the provider-connection compose form is
    /// presented and the configure flow is active.
    public let isComposing: Bool
    /// The endpoint-edit condition: the provider-connection endpoint editor is
    /// presented and the endpoint-update flow is active.
    public let editing: Editing?
    /// The model-edit condition: the provider-connection model editor is
    /// presented and the model-update flow is active.
    public let editingModel: ModelEditing?
    /// The typed failure of a settings operation, when the settings surface is
    /// in an error condition.
    public let failure: Failure?

    /// Creates a settings state from the configured connections, the
    /// configuration values, the compose condition, the endpoint-edit
    /// condition, the model-edit condition, and the optional typed failure.
    public init(
        connections: [ProviderConnectionListItem],
        configuration: [ConfigurationItem] = [],
        isComposing: Bool = false,
        editing: Editing? = nil,
        editingModel: ModelEditing? = nil,
        failure: Failure? = nil
    ) {
        self.connections = connections
        self.configuration = configuration
        self.isComposing = isComposing
        self.editing = editing
        self.editingModel = editingModel
        self.failure = failure
    }

    /// The error condition: a settings operation failed.
    public var hasError: Bool {
        failure != nil
    }
}
