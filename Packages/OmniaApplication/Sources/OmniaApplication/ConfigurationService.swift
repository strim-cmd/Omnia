import OmniaDomain

/// The configuration application service: typed settings read and write with
/// per-level resolution — the Settings module's application surface (DES-011
/// §3.5).
///
/// The service orchestrates the frozen `ConfigurationRepository` and the
/// `ConfigurationResolutionPolicy` (DES-009 §3.5, §3.6). It owns no business
/// rules and embeds no product decisions: values are typed, stored per level,
/// and resolved by the pure, deterministic resolution order of the Domain —
/// provider settings, then workspace overrides, then global defaults, then
/// capability preferences; a higher-priority level always wins (ARC-003,
/// ARC-004).
///
/// Values are typed at the boundary: a `ConfigurationKey<Value>` binds its
/// value to a type, so raw or untyped values are never stored (DES-009 §3.6,
/// DES-004). A configuration key with an empty name is rejected before any
/// domain operation (ARC-009, DES-011 §3.6). The service never stores
/// credentials; a stored value may hold only a `CredentialReference` pointer
/// (ARC-004, ARC-005).
///
/// Configuration failures surface as the Domain `RepositoryError`, never
/// wrapped (DES-009 §3.9). The repository and the resolution policy are
/// injected by the Composition Root; the service never references an
/// Infrastructure implementation (ARC-006, ARC-009).
public struct ConfigurationService: Sendable {
    private let configurationRepository: any ConfigurationRepository
    private let resolutionPolicy: ConfigurationResolutionPolicy

    /// Creates a configuration service over the given Domain contract and the
    /// resolution policy.
    public init(
        configurationRepository: any ConfigurationRepository,
        resolutionPolicy: ConfigurationResolutionPolicy
    ) {
        self.configurationRepository = configurationRepository
        self.resolutionPolicy = resolutionPolicy
    }

    /// Stores `value` for `key` at `level`, replacing any previously stored
    /// value for the same key at the same level (DES-011 §3.5).
    ///
    /// A key with an empty name is rejected before any domain operation
    /// (ARC-009, DES-011 §3.6).
    public func store<Value: Equatable & Sendable>(
        _ value: Value,
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        try validateKeyName(key)
        try await configurationRepository.store(value, for: key, at: level)
    }

    /// Returns the typed value stored for `key` at `level`, or `nil` when unset
    /// (DES-011 §3.5).
    public func value<Value: Equatable & Sendable>(
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws -> Value? {
        try validateKeyName(key)
        return try await configurationRepository.value(for: key, at: level)
    }

    /// Returns the typed value for `key` resolved across levels per the
    /// resolution order of DES-009 §3.6, or `nil` when no level sets it
    /// (DES-011 §3.5).
    ///
    /// The resolution is the pure, deterministic order of the Domain — provider
    /// settings, then workspace overrides, then global defaults, then capability
    /// preferences — applied by the `ConfigurationResolutionPolicy`; a
    /// higher-priority level always wins (ARC-004).
    public func resolved<Value: Equatable & Sendable>(
        for key: ConfigurationKey<Value>
    ) async throws -> Value? {
        try validateKeyName(key)
        var values: [ConfigurationLevel: [ConfigurationKey<Value>: Value]] = [:]
        for level in ConfigurationResolutionPolicy.resolutionOrder {
            if let value = try await configurationRepository.value(for: key, at: level) {
                values[level, default: [:]][key] = value
            }
        }
        return resolutionPolicy.resolve(key, in: values)
    }

    /// Removes the value stored for `key` at `level` (DES-011 §3.5).
    ///
    /// Removing an unset key is not an error; the operation is idempotent
    /// (DES-009 §3.5).
    public func remove<Value: Equatable & Sendable>(
        _ key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        try validateKeyName(key)
        try await configurationRepository.remove(key, at: level)
    }

    /// Validates the key name at the boundary (ARC-009, DES-011 §3.6).
    private func validateKeyName<Value: Equatable & Sendable>(
        _ key: ConfigurationKey<Value>
    ) throws {
        let trimmed = key.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ApplicationValidationError.invalid(reason: "The configuration key name is empty.")
        }
    }
}
