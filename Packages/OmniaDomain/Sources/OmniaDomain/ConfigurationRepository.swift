/// The repository contract for the configuration model (DES-009 §3.5–§3.6,
/// ARC-003 Repository).
///
/// The contract stores user-owned, typed configuration values per
/// `ConfigurationLevel` (provider settings, workspace overrides, global
/// defaults, capability preferences) and hides the storage implementation
/// (ARC-003). It owns no business rules: resolution across levels belongs to
/// `ConfigurationResolutionPolicy`, never to this contract (ARC-003, ARC-005).
///
/// Configuration values may hold `CredentialReference` pointers; the contract
/// stores configuration data only and never credentials or secrets themselves
/// (ARC-005).
///
/// Implementations belong to OmniaInfrastructure and are delivered by the
/// Composition Root; they are out of scope for this package (ARC-002, ARC-006,
/// ARC-009).
public protocol ConfigurationRepository: Sendable {
    /// Stores `value` for `key` at `level`, replacing any previously stored
    /// value for the same key at the same level.
    func store<Value: Equatable & Sendable>(
        _ value: Value,
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws

    /// Returns the value stored for `key` at `level`, or `nil` when unset.
    func value<Value: Equatable & Sendable>(
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws -> Value?

    /// Removes the value stored for `key` at `level`.
    ///
    /// Removing an unset key is not an error; the operation is idempotent.
    func remove<Value: Equatable & Sendable>(
        _ key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws
}
