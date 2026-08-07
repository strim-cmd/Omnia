/// The level at which a configuration value applies (ARC-004).
///
/// Configuration is resolved across levels in a fixed order: provider
/// settings, then workspace overrides, then global defaults, then capability
/// preferences (ARC-004, ARC-007). The order itself is the Configuration
/// Resolution Policy and is not a property of this value object.
public enum ConfigurationLevel: Equatable, Hashable, Sendable {
    /// Settings intrinsic to a provider connection.
    case providerSettings
    /// Provider settings adjusted for a specific workspace.
    case workspaceOverride
    /// Fallback values applied when nothing else is set.
    case globalDefault
    /// Per-capability preferences for how a provider is used.
    case capabilityPreference
}
