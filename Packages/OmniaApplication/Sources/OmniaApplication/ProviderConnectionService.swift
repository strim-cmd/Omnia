import OmniaDomain

/// The provider connection application service: configure, list, and remove
/// provider connections — the provider flows of the Settings module (DES-011
/// §3.4).
///
/// The service orchestrates the frozen `ProviderRepository`, the
/// `CredentialStorageProtocol`, and the `ConfigurationRepository` for the
/// credential reference (DES-009 §3.5, §3.6, §3.7). It owns no business rules:
/// the provider aggregate and its lifecycle are the Domain's (ARC-002,
/// ADR-0001), and the service only sequences the operations.
///
/// The credential is stored by reference through the Domain credential storage
/// and never persists in, or enters any representation of, the connection, the
/// repository, or the configuration beyond the pointer (ARC-001, ARC-005). The
/// reference is recorded as a configuration value at the provider-settings
/// level, keeping the pointer separate from the data it protects (DES-009
/// §3.6, ARC-005). The service never resolves or uses the credential itself;
/// resolution happens only when a request is built, in the layer that owns
/// transport (DES-010 §3.9.3, ARC-004).
///
/// Provider, credential, and configuration failures surface as their Domain
/// errors — `RepositoryError`, `CredentialStorageError` — never wrapped
/// (DES-009 §3.9). The collaborators are injected by the Composition Root; the
/// service never references an Infrastructure implementation (ARC-006,
/// ARC-009).
public struct ProviderConnectionService: Sendable {
    private let providerRepository: any ProviderRepository
    private let credentialStorage: any CredentialStorageProtocol
    private let configurationRepository: any ConfigurationRepository

    /// Creates a provider connection service over the given Domain contracts.
    public init(
        providerRepository: any ProviderRepository,
        credentialStorage: any CredentialStorageProtocol,
        configurationRepository: any ConfigurationRepository
    ) {
        self.providerRepository = providerRepository
        self.credentialStorage = credentialStorage
        self.configurationRepository = configurationRepository
    }

    /// Configures a new provider connection for `request` (DES-011 §3.4).
    ///
    /// The connection is created with a fresh `ProviderIdentity` from the
    /// Foundation `Identifier` primitive (DES-002), persisted, the credential is
    /// stored by reference through the Domain credential storage, and the
    /// reference is recorded as a configuration value at the provider-settings
    /// level. Input is validated at the boundary before any domain operation
    /// (ARC-009): an empty display name, an empty capability set, and an empty
    /// credential are rejected with the typed application error of DES-011 §3.6.
    ///
    /// Provider, credential, and configuration failures surface as their Domain
    /// errors, never wrapped (DES-009 §3.9).
    public func configure(
        _ request: ConfigureProviderRequest
    ) async throws -> ProviderConnection {
        try validate(request)
        let identity = ProviderIdentity()
        let reference = CredentialReference()
        let connection = ProviderConnection(
            identity: identity,
            capabilities: request.capabilities,
            metadata: ProviderMetadata(displayName: request.displayName),
            limits: request.limits,
            version: request.version
        )
        try await providerRepository.save(Provider(connection: connection))
        try await credentialStorage.store(request.credential, for: reference)
        try await configurationRepository.store(
            reference,
            for: Self.credentialReferenceKey(for: identity),
            at: .providerSettings
        )
        return connection
    }

    /// Returns the configured providers in identity order (DES-011 §3.4).
    public func allProviders() async throws -> [Provider] {
        try await providerRepository.allProviders().sorted {
            $0.identity.canonicalString < $1.identity.canonicalString
        }
    }

    /// Removes the provider connection with `identity` and its stored credential
    /// (user ownership, ARC-005, DES-011 §3.4).
    ///
    /// The recorded credential reference is read from the provider-settings
    /// configuration, the stored credential is removed, the provider connection
    /// is deleted, and the recorded reference is removed. Removing a provider
    /// that is not stored is not an error; the operation is idempotent (DES-009
    /// §3.5).
    public func remove(_ identity: ProviderIdentity) async throws {
        let key = Self.credentialReferenceKey(for: identity)
        if let reference = try await configurationRepository.value(for: key, at: .providerSettings) {
            try await credentialStorage.removeCredential(for: reference)
        }
        try await providerRepository.delete(identity)
        try await configurationRepository.remove(key, at: .providerSettings)
    }

    /// The provider-settings configuration key that records the credential
    /// reference of a provider connection, scoped by the provider identity so
    /// each connection's pointer stays separate from the others (DES-009 §3.6,
    /// ARC-005).
    private static func credentialReferenceKey(
        for identity: ProviderIdentity
    ) -> ConfigurationKey<CredentialReference> {
        ConfigurationKey<CredentialReference>("providerCredential.\(identity.canonicalString)")
    }

    /// Validates `request` at the boundary (ARC-009, DES-011 §3.6).
    private func validate(_ request: ConfigureProviderRequest) throws {
        let trimmedName = request.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ApplicationValidationError.invalid(reason: "The display name is empty.")
        }
        guard !request.capabilities.capabilities.isEmpty else {
            throw ApplicationValidationError.invalid(
                reason: "The provider must declare at least one capability."
            )
        }
        let secretIsEmpty = request.credential.withValue { $0.isEmpty }
        guard !secretIsEmpty else {
            throw ApplicationValidationError.invalid(reason: "The credential is empty.")
        }
    }
}
