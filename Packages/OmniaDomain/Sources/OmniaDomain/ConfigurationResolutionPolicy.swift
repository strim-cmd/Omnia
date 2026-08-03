/// The pure decision rule that resolves configuration levels in order
/// (ARC-004, ARC-003, DES-009 §3.6).
///
/// Configuration is resolved across levels in a fixed order: provider settings,
/// then workspace overrides, then global defaults, then capability preferences
/// (ARC-004, ARC-007). The policy is pure and deterministic: it depends on no
/// external state and returns the same result for the same input (ARC-003
/// Policy).
public struct ConfigurationResolutionPolicy: Sendable {
    /// The order in which configuration levels are resolved, highest priority
    /// first (ARC-004).
    public static let resolutionOrder: [ConfigurationLevel] = [
        .providerSettings,
        .workspaceOverride,
        .globalDefault,
        .capabilityPreference,
    ]

    /// Creates a configuration resolution policy.
    public init() {}

    /// Returns the value for `key` at the highest-priority level that sets it,
    /// or `nil` when no level sets it.
    ///
    /// `values` maps each level to its typed key-value pairs. A value at a
    /// higher-priority level always wins over a value at a lower-priority level.
    public func resolve<Value: Equatable & Sendable>(
        _ key: ConfigurationKey<Value>,
        in values: [ConfigurationLevel: [ConfigurationKey<Value>: Value]]
    ) -> Value? {
        for level in Self.resolutionOrder {
            if let value = values[level]?[key] {
                return value
            }
        }
        return nil
    }
}
