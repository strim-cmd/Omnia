import OmniaApplication
import OmniaFoundation

/// The ready-to-render state of the settings surface: the provider connection
/// list items of the configured connections, the configuration values the
/// surface presents, and the compose, provider-edit, and error conditions
/// (DES-012 §3.2, Settings module, ARC-007).
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
        /// A provider/model selection operation failed.
        case capability(CapabilityError)
    }

    /// The Test Connection condition of the currently presented provider form.
    public enum ConnectionTestCondition: Equatable, Sendable {
        case idle
        case testing
        case succeeded(models: [ModelReference])
        case failed(ProviderConnectionTestError)
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

    /// The provider-edit condition of the settings surface (DES-012 §3.2,
    /// Settings module): the provider connection whose declaration is being
    /// edited — the unified provider-edit flow, which presents the same
    /// connection form as compose, pre-filled — holding the connection's
    /// current declaration (display name, capabilities, limits, and version)
    /// and its recorded endpoint and model, the values the form pre-fills.
    ///
    /// The condition holds only the configured connection state and the
    /// recorded endpoint and model — never a credential or provider-specific
    /// detail (ARC-001, ARC-004, ARC-005). The declaration, the endpoint, and
    /// the model are connection configuration the user owns (ARC-005, DES-011
    /// §3.1, §3.9, §3.10).
    public struct Editing: Equatable, Sendable {
        /// The identity of the provider connection being edited.
        public let identity: ProviderIdentity
        /// The declared display name of the provider connection.
        public let displayName: String
        /// The capabilities the provider connection declares it can deliver.
        public let capabilities: ProviderCapabilities
        /// The limits the provider connection declares.
        public let limits: ProviderLimits
        /// The version of the provider API the connection targets.
        public let version: SemanticVersion
        /// The endpoint currently recorded for the connection, empty when none
        /// is recorded.
        public let currentEndpoint: String
        /// The model currently recorded for the connection, empty when none is
        /// recorded.
        public let currentModel: String

        /// Creates the provider-edit condition for the provider connection
        /// with the given identity, declaration, current endpoint, and current
        /// model.
        public init(
            identity: ProviderIdentity,
            displayName: String,
            capabilities: ProviderCapabilities,
            limits: ProviderLimits,
            version: SemanticVersion,
            currentEndpoint: String,
            currentModel: String
        ) {
            self.identity = identity
            self.displayName = displayName
            self.capabilities = capabilities
            self.limits = limits
            self.version = version
            self.currentEndpoint = currentEndpoint
            self.currentModel = currentModel
        }
    }

    /// The provider connection list items of the configured connections, in
    /// the deterministic order the service lists them (DES-011 §3.4).
    public let connections: [ProviderConnectionListItem]
    /// The configuration values the settings surface presents.
    public let configuration: [ConfigurationItem]
    /// Cached or refreshed model catalogs for configured providers.
    public let modelCatalogs: [ProviderModelCatalog]
    /// The persisted global default provider/model pair, including an invalid
    /// saved value so the UI can require explicit correction.
    public let defaultModelSelection: ProviderModelSelection?
    /// The compose condition: the provider-connection compose form is
    /// presented and the configure flow is active.
    public let isComposing: Bool
    /// The provider-edit condition: the provider-connection edit form is
    /// presented and the provider-update flow is active.
    public let editing: Editing?
    /// The typed failure of a settings operation, when the settings surface is
    /// in an error condition.
    public let failure: Failure?
    /// Test Connection feedback for the active connection form.
    public let connectionTestCondition: ConnectionTestCondition

    /// Creates a settings state from the configured connections, the
    /// configuration values, the compose condition, the provider-edit
    /// condition, and the optional typed failure.
    public init(
        connections: [ProviderConnectionListItem],
        configuration: [ConfigurationItem] = [],
        modelCatalogs: [ProviderModelCatalog] = [],
        defaultModelSelection: ProviderModelSelection? = nil,
        isComposing: Bool = false,
        editing: Editing? = nil,
        failure: Failure? = nil,
        connectionTestCondition: ConnectionTestCondition = .idle
    ) {
        self.connections = connections
        self.configuration = configuration
        self.modelCatalogs = modelCatalogs
        self.defaultModelSelection = defaultModelSelection
        self.isComposing = isComposing
        self.editing = editing
        self.failure = failure
        self.connectionTestCondition = connectionTestCondition
    }

    /// The error condition: a settings operation failed.
    public var hasError: Bool {
        failure != nil
    }

    /// First-launch/cleared-data setup is incomplete until at least one
    /// provider connection exists. The UI turns this deterministic state into
    /// an Add Provider action rather than a dead empty chat.
    public var requiresProviderSetup: Bool {
        connections.isEmpty
    }

    /// Whether the persisted default still names a ready provider and a model
    /// in that provider's own catalog.
    public var defaultModelSelectionIsAvailable: Bool {
        guard let selection = defaultModelSelection else { return false }
        return modelSelectionIsAvailable(selection)
    }

    public func modelSelectionIsAvailable(
        _ selection: ProviderModelSelection
    ) -> Bool {
        connections.contains {
            $0.identity == selection.provider && $0.state == .ready
        } && modelCatalogs
            .first { $0.provider == selection.provider }?
            .models.contains { $0.selection == selection } == true
    }
}
