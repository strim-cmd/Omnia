/// The typed configuration protocol: typed value access with defaults
/// (ARC-007, ARC-009, DES-009 §3.6).
///
/// Configuration is user-owned; the protocol holds values and defaults and
/// contains no business logic (ARC-003). Resolution across levels is the
/// responsibility of `ConfigurationResolutionPolicy`, never of this protocol.
public protocol ConfigurationProtocol: Sendable {
    /// Returns the configured value for `key`, or `nil` when unset.
    ///
    /// The conforming type owns how values are stored and retrieved.
    func value<Value: Equatable & Sendable>(for key: ConfigurationKey<Value>) -> Value?
}

public extension ConfigurationProtocol {
    /// Returns the configured value for `key`, falling back to `defaultValue`.
    ///
    /// The default applies only when the key is unset; a set value always
    /// wins over the default.
    func value<Value: Equatable & Sendable>(
        for key: ConfigurationKey<Value>,
        default defaultValue: Value
    ) -> Value {
        value(for: key) ?? defaultValue
    }
}
