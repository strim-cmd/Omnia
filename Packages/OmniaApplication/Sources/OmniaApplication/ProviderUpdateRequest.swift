import OmniaDomain
import OmniaFoundation

/// A request to update the declaration of a configured provider connection
/// (DES-011 §3.1): the user-edited display name, capabilities, limits, and
/// version of the connection.
///
/// The request carries no credential — editing a connection never requires
/// re-entering the secret, and the stored credential is kept by reference
/// (ARC-001, ARC-005). The endpoint and the optional model are edited through
/// the existing service surfaces (DES-011 §3.9, §3.10), not this request, so
/// the declaration and its recorded connection configuration stay separate.
///
/// Immutable and equal by content; a change produces a new value, never an
/// in-place mutation (ARC-003). It owns no business logic: input is validated
/// at the application boundary, by the provider connection service (ARC-009).
///
/// Owned by the Settings module (DES-011 §3.1).
public struct ProviderUpdateRequest: Equatable, Sendable {
    /// The name shown to the user for the provider connection.
    public let displayName: String
    /// The capabilities the provider can deliver.
    public let capabilities: ProviderCapabilities
    /// The limits the provider enforces.
    public let limits: ProviderLimits
    /// The version of the provider API the connection targets.
    public let version: SemanticVersion

    /// Creates a provider connection update request.
    public init(
        displayName: String,
        capabilities: ProviderCapabilities,
        limits: ProviderLimits,
        version: SemanticVersion
    ) {
        self.displayName = displayName
        self.capabilities = capabilities
        self.limits = limits
        self.version = version
    }
}
