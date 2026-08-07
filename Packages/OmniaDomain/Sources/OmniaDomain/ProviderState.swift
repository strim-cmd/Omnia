import OmniaFoundation

/// The state a provider is in (ARC-004, DES-009 §3.1).
///
/// The states are defined by this package, never by the Foundation `Lifecycle`
/// primitive (DES-007). A provider changes status only through a legal
/// transition (ARC-004).
public enum ProviderState: LifecycleState {
    /// The provider is known to the application.
    case registered
    /// The provider's configuration is verified.
    case validated
    /// The provider is prepared for use.
    case initializing
    /// The provider is available for capabilities.
    case ready
    /// The provider cannot be used at this moment.
    case unavailable
    /// The user has turned the provider off.
    case disabled
    /// The provider no longer exists in the application.
    case removed
}
