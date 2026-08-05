import OmniaDomain
import OmniaFoundation

/// A request to configure a new provider connection (DES-011 §3.1).
///
/// The user's declaration of a provider connection and its credential. The
/// credential is handled by reference through the Domain credential contract
/// and never enters logs, analytics, or any representation beyond the secure
/// storage (ARC-001, ARC-005, DES-009 §3.7).
///
/// Immutable and equal by content; a change produces a new value, never an
/// in-place mutation (ARC-003). It owns no business logic: input is validated
/// at the application boundary, by the provider connection service (ARC-009).
///
/// Owned by the Settings module (DES-011 §3.1).
public struct ConfigureProviderRequest: Equatable, Sendable {
    /// The name shown to the user for the provider connection.
    public let displayName: String
    /// The capabilities the provider can deliver.
    public let capabilities: ProviderCapabilities
    /// The limits the provider enforces.
    public let limits: ProviderLimits
    /// The version of the provider API the connection targets.
    public let version: SemanticVersion
    /// The credential to store by reference for the connection.
    public let credential: Credential

    /// Creates a provider connection request.
    public init(
        displayName: String,
        capabilities: ProviderCapabilities,
        limits: ProviderLimits,
        version: SemanticVersion,
        credential: Credential
    ) {
        self.displayName = displayName
        self.capabilities = capabilities
        self.limits = limits
        self.version = version
        self.credential = credential
    }
}

extension ConfigureProviderRequest: CustomStringConvertible, CustomDebugStringConvertible {
    /// A description that never reveals the credential (ARC-005).
    public var description: String {
        "ConfigureProviderRequest(displayName: \(displayName), capabilities: \(capabilities), limits: \(limits), version: \(version), credential: <redacted>)"
    }

    /// A redacted debug description that never reveals the credential.
    public var debugDescription: String {
        description
    }
}
