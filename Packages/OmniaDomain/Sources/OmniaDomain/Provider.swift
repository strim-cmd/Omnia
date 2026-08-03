import OmniaFoundation

/// A provider connection the user has configured (ARC-004, DES-009 §3.1).
///
/// A provider is an external service that can deliver capabilities. The model
/// records what the provider declares — identity, capabilities, metadata,
/// limits, and versioning. Live availability is discovered and reported by the
/// Infrastructure layer, never by the Domain (ARC-004 Capability Discovery,
/// DES-009 §3.1). Authentication is realized by credential reference; the
/// model MUST NOT contain credentials (ARC-004, ARC-005).
///
/// Immutable and equal by content; a change produces a new value, never an
/// in-place mutation (ARC-001, ARC-003).
public struct Provider: Equatable, Sendable {
    /// The provider's stable identity within the application.
    public let identity: ProviderIdentity
    /// The capabilities the provider declares it can deliver.
    public let capabilities: ProviderCapabilities
    /// Descriptive information about the provider.
    public let metadata: ProviderMetadata
    /// The usage limits the provider enforces.
    public let limits: ProviderLimits
    /// The version of the provider's interface.
    public let version: SemanticVersion

    /// Creates a provider model.
    public init(
        identity: ProviderIdentity,
        capabilities: ProviderCapabilities,
        metadata: ProviderMetadata,
        limits: ProviderLimits,
        version: SemanticVersion
    ) {
        self.identity = identity
        self.capabilities = capabilities
        self.metadata = metadata
        self.limits = limits
        self.version = version
    }
}
