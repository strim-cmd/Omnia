import OmniaApplication
import OmniaFoundation

/// The settings presentation surface: provider connections and configuration —
/// configure, list, remove, update the endpoint and the model of provider
/// connections over `ProviderConnectionService`, and present typed configuration
/// over `ConfigurationService` as `SettingsState` (DES-012 §3.4, Settings
/// module, ARC-007).
///
/// The surface is the seam through which the frozen `ProviderConnectionService`
/// of DES-011 §3.4 and the frozen `ConfigurationService` of DES-011 §3.5 are
/// delivered to the settings surface (DES-012 §3.6, ARC-006). It receives them
/// through its public initializer, translates user intent — declaring a new
/// provider connection, removing one, updating the endpoint and the model of
/// one (DES-011 §3.9, §3.10, UX audit U7), and storing, reading, resolving, and
/// removing typed configuration values — into use-case invocations, and it
/// composes the ready-to-render settings state from the configured connections
/// and the configuration values the services load (ARC-002, ADR-0001).
///
/// It consumes only the frozen DES-011 settings surface and owns no business
/// rules (ARC-002): the provider aggregate and its lifecycle are the Domain's,
/// and the services sequence the repository and credential operations. The
/// provider-connection list item derivation — the display name and lifecycle
/// state of a row from the provider — is deterministic presentation logic
/// (DES-012 §3.1, §3.4). The surface presents the generic connection state —
/// identity, display name, capabilities, and lifecycle state — and never
/// changes the interface per provider or exposes provider-specific detail
/// (PRODUCT_PRINCIPLES — Provider Independence, ARC-004).
///
/// The credential boundary is absolute: the entered secret passes into the
/// frozen `ConfigureProviderRequest`, whose storage by reference is the
/// service's concern (DES-011 §3.4, ARC-005); the secret is never rendered,
/// stored, persisted, or logged by the package, and only the configured state
/// is presented (ARC-001, ARC-005).
///
/// The failures the services surface — `ApplicationValidationError`, and the
/// Domain `RepositoryError` and `CredentialStorageError` — are presented as
/// they are, never wrapped or redefined (DES-011 §3.6, DES-009 §3.9); no
/// failure is silent (ARC-001). The surface never references a concrete
/// Infrastructure implementation and never performs networking, persistence,
/// or credential operations (ARC-002, ADR-0002).
///
/// The surface is a stateless, `Sendable` value type; every operation is
/// deterministic and testable on the Linux build environment (DES-012 §3.7).
public struct SettingsSurface: Sendable {
    private let connectionService: ProviderConnectionService
    private let configurationService: ConfigurationService
    private let modelService: ProviderModelService?
    private let validationService: ProviderValidationService?
    private let dataManagementService: DataManagementService?

    /// Creates a settings surface over the given provider connection service
    /// and configuration service, delivered by the Composition Root (DES-012
    /// §3.6).
    public init(
        connectionService: ProviderConnectionService,
        configurationService: ConfigurationService
    ) {
        self.connectionService = connectionService
        self.configurationService = configurationService
        self.modelService = nil
        self.validationService = nil
        self.dataManagementService = nil
    }

    /// Production initializer including M1 model discovery/defaults and Test
    /// Connection. The two-argument initializer remains for isolated legacy
    /// surface tests that do not exercise M1.
    public init(
        connectionService: ProviderConnectionService,
        configurationService: ConfigurationService,
        modelService: ProviderModelService,
        validationService: ProviderValidationService,
        dataManagementService: DataManagementService? = nil
    ) {
        self.connectionService = connectionService
        self.configurationService = configurationService
        self.modelService = modelService
        self.validationService = validationService
        self.dataManagementService = dataManagementService
    }

    /// Clears the exact app-data scope described by Settings.
    public func clearData() async throws {
        guard let dataManagementService else {
            throw ApplicationValidationError.invalid(
                reason: "Data management is unavailable."
            )
        }
        try await dataManagementService.clearAll()
    }

    /// Composes the ready-to-render settings state (DES-012 §3.2): the provider
    /// connection list items of the configured connections — in the
    /// deterministic identity order the service lists them (DES-011 §3.4) — and
    /// the configuration values the surface presents.
    ///
    /// The configuration values presented are the resolved values of the given
    /// typed keys — the effective value a key resolves to across the documented
    /// levels (DES-011 §3.5); a key no level sets is not presented. The state
    /// holds only the configured connection state and the typed configuration
    /// values — never a credential, a raw secret, or provider-specific detail
    /// (ARC-001, ARC-004, ARC-005).
    ///
    /// A failure surfaces as the Domain `RepositoryError`, as it is, never
    /// wrapped (DES-011 §3.6).
    public func load(
        configurationKeys: [ConfigurationKey<String>] = []
    ) async throws -> SettingsState {
        var configuration: [SettingsState.ConfigurationItem] = []
        for key in configurationKeys {
            if let value = try await configurationService.resolved(for: key) {
                configuration.append(SettingsState.ConfigurationItem(key: key, value: value))
            }
        }
        let providers = try await connectionService.allProviders()
        var catalogs: [ProviderModelCatalog] = []
        if let modelService {
            for provider in providers {
                catalogs.append(
                    try await modelService.refreshCatalog(for: provider.identity)
                )
            }
        }
        return SettingsState(
            connections: providers.map { ProviderConnectionListItem(provider: $0) },
            configuration: configuration,
            modelCatalogs: catalogs,
            defaultModelSelection: try await modelService?.defaultSelection()
        )
    }

    /// Composes the cached-first state shown while model discovery is running.
    /// Existing models and defaults remain visible, but each provider catalog
    /// explicitly reports loading until `load` replaces it with a terminal
    /// discovery/cache condition.
    public func loadModelCatalogsLoading(
        configurationKeys: [ConfigurationKey<String>] = []
    ) async throws -> SettingsState {
        var configuration: [SettingsState.ConfigurationItem] = []
        for key in configurationKeys {
            if let value = try await configurationService.resolved(for: key) {
                configuration.append(SettingsState.ConfigurationItem(key: key, value: value))
            }
        }
        let providers = try await connectionService.allProviders()
        var catalogs: [ProviderModelCatalog] = []
        if let modelService {
            for provider in providers {
                let cached = try await modelService.cachedCatalog(for: provider.identity)
                catalogs.append(
                    ProviderModelCatalog(
                        provider: cached.provider,
                        models: cached.models,
                        status: .loading
                    )
                )
            }
        }
        return SettingsState(
            connections: providers.map { ProviderConnectionListItem(provider: $0) },
            configuration: configuration,
            modelCatalogs: catalogs,
            defaultModelSelection: try await modelService?.defaultSelection()
        )
    }

    public func refreshModels(
        for provider: ProviderIdentity
    ) async throws -> ProviderModelCatalog {
        guard let modelService else {
            throw ApplicationValidationError.invalid(reason: "Model discovery is unavailable.")
        }
        return try await modelService.refreshCatalog(for: provider)
    }

    public func testConnection(
        _ request: ProviderConnectionTestRequest
    ) async throws -> ProviderConnectionTestResult {
        guard let validationService else {
            throw ApplicationValidationError.invalid(reason: "Connection testing is unavailable.")
        }
        return try await validationService.test(request)
    }

    public func setDefaultModelSelection(
        _ selection: ProviderModelSelection?
    ) async throws {
        guard let modelService else {
            throw ApplicationValidationError.invalid(reason: "Model defaults are unavailable.")
        }
        try await modelService.setDefaultSelection(selection)
    }

    public func setModelCapabilityOverride(
        _ profile: ModelCapabilityProfile?,
        for selection: ProviderModelSelection
    ) async throws {
        guard let modelService else {
            throw ApplicationValidationError.invalid(reason: "Model capabilities are unavailable.")
        }
        try await modelService.setCapabilityOverride(profile, for: selection)
    }

    /// Configures a new provider connection for `request` (DES-011 §3.4): the
    /// connection is created with a fresh identity, persisted, and the
    /// credential is stored by reference by the service.
    ///
    /// The secret enters only the frozen `ConfigureProviderRequest` and passes
    /// to the service; it never enters any representation of the package beyond
    /// the request (ARC-001, ARC-005). Input validation and the failures of the
    /// provider, credential, and configuration operations surface as they are —
    /// `ApplicationValidationError`, and the Domain `RepositoryError` and
    /// `CredentialStorageError` — never wrapped (DES-011 §3.6, DES-009 §3.9).
    public func configure(
        _ request: ConfigureProviderRequest
    ) async throws -> ProviderConnection {
        try await connectionService.configure(request)
    }

    /// Configures a new provider connection for `request` and records its
    /// OpenAI-compatible endpoint — the endpoint collection of the connection
    /// form (DES-011 §3.9, PRESENTATION API §3.4).
    ///
    /// The connection is configured and the endpoint is recorded through the
    /// service's endpoint surface, keyed by the fresh connection identity; the
    /// endpoint never enters the `ConfigureProviderRequest` or any rendered
    /// state (ARC-001, ARC-004, ARC-005). The endpoint is validated at the
    /// service boundary before any write; a malformed endpoint surfaces as the
    /// typed `ApplicationValidationError`, never wrapped (DES-011 §3.6,
    /// DES-009 §3.9).
    public func configure(
        _ request: ConfigureProviderRequest,
        endpoint: String
    ) async throws -> ProviderConnection {
        let validationResult: ProviderConnectionTestResult?
        if let validationService {
            validationResult = try await validationService.test(
                ProviderConnectionTestRequest(
                    endpoint: endpoint,
                    credential: request.credential
                )
            )
        } else {
            validationResult = nil
        }
        let connection = try await connectionService.configure(request, endpoint: endpoint)
        if let validationResult, let modelService {
            try await modelService.recordValidatedModels(
                validationResult.models,
                for: connection.identity
            )
        }
        return connection
    }

    /// Configures a new provider connection for `request`, records its
    /// OpenAI-compatible endpoint, and records its optional model — the model
    /// and endpoint collection of the connection form (DES-011 §3.9, §3.10,
    /// PRESENTATION API §3.4).
    ///
    /// The connection is configured and the endpoint and model are recorded
    /// through the service's surfaces, keyed by the fresh connection identity;
    /// the endpoint and model never enter the `ConfigureProviderRequest` or
    /// any rendered state (ARC-001, ARC-004, ARC-005). The endpoint is
    /// validated at the service boundary before any write; a malformed
    /// endpoint surfaces as the typed `ApplicationValidationError`. `nil`
    /// records no manual model, so discovery/cache supplies any catalog;
    /// a non-empty model is validated at the service boundary before any
    /// write, and an empty model surfaces as the typed
    /// `ApplicationValidationError` (DES-011 §3.6, DES-009 §3.9).
    public func configure(
        _ request: ConfigureProviderRequest,
        endpoint: String,
        model: String?
    ) async throws -> ProviderConnection {
        let validationResult: ProviderConnectionTestResult?
        if let validationService {
            validationResult = try await validationService.test(
                ProviderConnectionTestRequest(
                    endpoint: endpoint,
                    model: model,
                    credential: request.credential
                )
            )
        } else {
            validationResult = nil
        }
        let connection = try await connectionService.configure(
            request,
            endpoint: endpoint,
            model: model
        )
        if let validationResult, let modelService {
            try await modelService.recordValidatedModels(
                validationResult.models,
                for: connection.identity
            )
        }
        return connection
    }

    /// Removes the provider connection with `identity` and its stored credential
    /// (user ownership, ARC-005, DES-011 §3.4).
    ///
    /// Removing a provider that is not stored is not an error; the operation is
    /// idempotent (DES-009 §3.5). Failures surface as they are — the Domain
    /// `RepositoryError` and `CredentialStorageError` — never wrapped (DES-011
    /// §3.6).
    public func remove(_ identity: ProviderIdentity) async throws {
        try await connectionService.remove(identity)
    }

    /// Updates the provider connection's OpenAI-compatible endpoint — the
    /// endpoint-edit intent of the settings surface (DES-012 §3.4, UX audit
    /// U7): the endpoint is recorded through the service's endpoint surface,
    /// keyed by the provider identity, replacing any previously recorded
    /// endpoint (DES-011 §3.9).
    ///
    /// The endpoint is connection configuration the user owns (ARC-005); it
    /// never enters the `ProviderConnection` or `Provider` aggregate or any
    /// rendered state (DES-011 §3.9, ARC-004). It is validated at the service
    /// boundary before any write; a malformed endpoint surfaces as the typed
    /// `ApplicationValidationError`, never wrapped (DES-011 §3.6, DES-009
    /// §3.9).
    public func updateEndpoint(
        _ endpoint: String,
        for identity: ProviderIdentity
    ) async throws {
        try await connectionService.updateEndpoint(endpoint, for: identity)
    }

    /// Returns the provider connection's recorded OpenAI-compatible endpoint,
    /// or `nil` when none is recorded — the value the unified provider form
    /// pre-fills when editing a connection (DES-012 §3.4, DES-011 §3.9, UX
    /// audit U7).
    ///
    /// The endpoint is connection configuration the user owns (ARC-005);
    /// failures surface as the Domain `RepositoryError`, never wrapped (DES-011
    /// §3.6).
    public func endpoint(
        for identity: ProviderIdentity
    ) async throws -> String? {
        try await connectionService.endpoint(for: identity)
    }

    /// Updates the provider connection's OpenAI-compatible model — the
    /// model-edit intent of the settings surface (DES-012 §3.4): the model is
    /// recorded through the service's model surface, keyed by the provider
    /// identity, replacing any previously recorded model (DES-011 §3.10).
    ///
    /// The model is connection configuration the user owns (ARC-005); it
    /// never enters the `ProviderConnection` or `Provider` aggregate or any
    /// rendered state (DES-011 §3.10, ARC-004). It is validated at the service
    /// boundary before any write; an empty model surfaces as the typed
    /// `ApplicationValidationError`, never wrapped (DES-011 §3.6, DES-009
    /// §3.9).
    public func updateModel(
        _ model: String,
        for identity: ProviderIdentity
    ) async throws {
        try await connectionService.updateModel(model, for: identity)
    }

    /// Returns the provider connection's recorded OpenAI-compatible model, or
    /// `nil` when none is recorded — the value the model editor pre-fills
    /// (DES-012 §3.4, DES-011 §3.10).
    ///
    /// The model is connection configuration the user owns (ARC-005);
    /// failures surface as the Domain `RepositoryError`, never wrapped (DES-011
    /// §3.6).
    public func model(
        for identity: ProviderIdentity
    ) async throws -> String? {
        try await connectionService.model(for: identity)
    }

    /// Updates the declaration of the provider connection with `identity` and
    /// records its OpenAI-compatible endpoint and optional model — the
    /// provider-edit intent of the providers surface (DES-012 §3.4): the same
    /// connection form as compose, submitted as the frozen `ProviderUpdateRequest`
    /// (DES-011 §3.1).
    ///
    /// The edited declaration, the endpoint, and the model are connection
    /// configuration the user owns (ARC-005); the endpoint and model never
    /// enter the `ProviderUpdateRequest` or any rendered state (DES-011 §3.9,
    /// §3.10, ARC-001, ARC-004, ARC-005). The lifecycle state is preserved by
    /// the service — a ready provider stays ready, so availability and the
    /// runtime binding are unchanged. Input is validated at the service
    /// boundary before any write; `nil` records no manual model, so
    /// discovery/cache supplies any catalog (DES-011 §3.10). Failures surface as
    /// they are — `ApplicationValidationError`, and the Domain `RepositoryError`
    /// and `CredentialStorageError` — never wrapped (DES-011 §3.6, DES-009
    /// §3.9).
    public func update(
        _ request: ProviderUpdateRequest,
        for identity: ProviderIdentity,
        endpoint: String,
        model: String?
    ) async throws -> ProviderConnection {
        let validationResult: ProviderConnectionTestResult?
        if let validationService {
            validationResult = try await validationService.test(
                ProviderConnectionTestRequest(
                    provider: identity,
                    endpoint: endpoint,
                    model: model
                )
            )
        } else {
            validationResult = nil
        }
        let connection = try await connectionService.update(
            request,
            for: identity,
            endpoint: endpoint,
            model: model
        )
        if let validationResult, let modelService {
            try await modelService.recordValidatedModels(
                validationResult.models,
                for: identity
            )
        }
        return connection
    }

    /// Stores `value` for `key` at `level`, replacing any previously stored
    /// value for the same key at the same level (DES-011 §3.5).
    ///
    /// Values are typed through the frozen `ConfigurationKey` and
    /// `ConfigurationLevel` vocabulary; raw or untyped values are never stored
    /// (DES-009 §3.6). Failures surface as the Domain `RepositoryError`, never
    /// wrapped (DES-011 §3.6).
    public func store<Value: Equatable & Sendable>(
        _ value: Value,
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        try await configurationService.store(value, for: key, at: level)
    }

    /// Returns the typed value stored for `key` at `level`, or `nil` when unset
    /// (DES-011 §3.5).
    public func value<Value: Equatable & Sendable>(
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws -> Value? {
        try await configurationService.value(for: key, at: level)
    }

    /// Returns the typed value for `key` resolved across levels per the
    /// resolution order of DES-009 §3.6, or `nil` when no level sets it
    /// (DES-011 §3.5).
    ///
    /// The resolution is the pure, deterministic order of the Domain — provider
    /// settings, then workspace overrides, then global defaults, then capability
    /// preferences; a higher-priority level always wins (ARC-004).
    public func resolved<Value: Equatable & Sendable>(
        for key: ConfigurationKey<Value>
    ) async throws -> Value? {
        try await configurationService.resolved(for: key)
    }

    /// Removes the value stored for `key` at `level` (DES-011 §3.5).
    ///
    /// Removing an unset key is not an error; the operation is idempotent
    /// (DES-009 §3.5).
    public func remove<Value: Equatable & Sendable>(
        _ key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        try await configurationService.remove(key, at: level)
    }
}
