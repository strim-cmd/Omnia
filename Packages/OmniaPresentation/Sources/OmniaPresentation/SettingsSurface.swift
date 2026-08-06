import OmniaApplication
import OmniaFoundation

/// The settings presentation surface: provider connections and configuration —
/// configure, list, and remove provider connections over
/// `ProviderConnectionService`, and present typed configuration over
/// `ConfigurationService` as `SettingsState` (DES-012 §3.4, Settings module,
/// ARC-007).
///
/// The surface is the seam through which the frozen `ProviderConnectionService`
/// of DES-011 §3.4 and the frozen `ConfigurationService` of DES-011 §3.5 are
/// delivered to the settings surface (DES-012 §3.6, ARC-006). It receives them
/// through its public initializer, translates user intent — declaring a new
/// provider connection, removing one, and storing, reading, resolving, and
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

    /// Creates a settings surface over the given provider connection service
    /// and configuration service, delivered by the Composition Root (DES-012
    /// §3.6).
    public init(
        connectionService: ProviderConnectionService,
        configurationService: ConfigurationService
    ) {
        self.connectionService = connectionService
        self.configurationService = configurationService
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
        return SettingsState(
            connections: providers.map { ProviderConnectionListItem(provider: $0) },
            configuration: configuration
        )
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
