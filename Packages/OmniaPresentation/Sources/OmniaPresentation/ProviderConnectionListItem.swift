import OmniaApplication
import OmniaFoundation

/// A row of the settings provider-connection list: the identity, the declared
/// display name, the declared capabilities, limits, and version, and the
/// lifecycle state of a configured provider connection (DES-012 §3.1, Settings
/// module, ARC-007).
///
/// The row presents the generic connection state — identity, display name,
/// declared capabilities, limits, version, and lifecycle state — and never
/// changes the interface per provider or exposes provider-specific detail
/// (PRODUCT_PRINCIPLES — Provider Independence, ARC-004). It is expressed in the
/// frozen `ProviderIdentity`, `ProviderMetadata.displayName`,
/// `ProviderCapabilities`, `ProviderLimits`, `SemanticVersion`, and
/// `ProviderState` vocabulary of DES-009 §3.1–§3.2 and never carries a
/// credential; only the configured state is presented (ARC-001, ARC-005).
///
/// The value type is immutable, equal by content, `Equatable` and `Sendable`,
/// and owns no business logic (ARC-002, ARC-003).
public struct ProviderConnectionListItem: Equatable, Sendable {
    /// The provider connection's stable identity.
    public let identity: ProviderIdentity
    /// The declared display name of the provider connection.
    public let displayName: String
    /// The capabilities the provider connection declares it can deliver.
    public let capabilities: ProviderCapabilities
    /// The limits the provider connection declares.
    public let limits: ProviderLimits
    /// The version of the provider API the connection targets.
    public let version: SemanticVersion
    /// The lifecycle state of the provider connection.
    public let state: ProviderState

    /// Creates a provider connection list item with the given identity,
    /// display name, declared capabilities, limits, and version, and lifecycle
    /// state.
    public init(
        identity: ProviderIdentity,
        displayName: String,
        capabilities: ProviderCapabilities = ProviderCapabilities(capabilities: []),
        limits: ProviderLimits = ProviderLimits(),
        version: SemanticVersion = SemanticVersion(major: 0, minor: 0, patch: 0),
        state: ProviderState
    ) {
        self.identity = identity
        self.displayName = displayName
        self.capabilities = capabilities
        self.limits = limits
        self.version = version
        self.state = state
    }

    /// Creates a provider connection list item from a configured provider
    /// (DES-012 §3.1): the declared display name, capabilities, limits, and
    /// version of the connection and the provider's lifecycle state — the
    /// presentation-logic derivation of a provider row from a connection
    /// (ARC-002).
    public init(provider: Provider) {
        self.init(
            identity: provider.identity,
            displayName: provider.connection.metadata.displayName,
            capabilities: provider.connection.capabilities,
            limits: provider.connection.limits,
            version: provider.connection.version,
            state: provider.state
        )
    }
}
