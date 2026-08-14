import OmniaDomain

/// The provider connection application service: configure, list, remove, update
/// the declaration of, and record the OpenAI-compatible endpoint and optional
/// model of provider connections — the provider flows of the Settings module
/// (DES-011 §3.4, §3.9, §3.10).
///
/// The service orchestrates the frozen `ProviderRepository`, the
/// `CredentialStorageProtocol`, and the `ConfigurationRepository` for the
/// credential reference (DES-009 §3.5, §3.6, §3.7). It owns no business rules:
/// the provider aggregate and its lifecycle are the Domain's (ARC-002,
/// ADR-0001), and the service only sequences the operations.
///
/// The service also wires the lifecycle: a connection configured during a
/// running session is registered in the `ProviderLifecycleService` and
/// transitioned to ready, and the ready state is persisted back — so the
/// persisted provider state the settings and conversation surfaces read agrees
/// with the runtime lifecycle that actually serves requests, and a provider
/// that is actually available renders available without waiting for the next
/// `prepare()` (DES-013 §3.3). The lifecycle service is delivered by the
/// Composition Root and is the same instance the runtime provider binding and
/// selection read.
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
    private let lifecycleService: ProviderLifecycleService

    /// Creates a provider connection service over the given Domain contracts
    /// and the lifecycle service its configured connections are wired into.
    public init(
        providerRepository: any ProviderRepository,
        credentialStorage: any CredentialStorageProtocol,
        configurationRepository: any ConfigurationRepository,
        lifecycleService: ProviderLifecycleService
    ) {
        self.providerRepository = providerRepository
        self.credentialStorage = credentialStorage
        self.configurationRepository = configurationRepository
        self.lifecycleService = lifecycleService
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
    /// The connection is wired into the running session: it is registered in the
    /// lifecycle service and transitioned to ready, and the ready state is
    /// persisted back to the repository — so the provider is immediately
    /// servable by selection and the runtime binding, and the settings and
    /// conversation surfaces render it available without waiting for the next
    /// `prepare()` (DES-013 §3.3). The transition chain is the same legal chain
    /// `prepare()` drives, idempotent across relaunch.
    ///
    /// Provider, credential, and configuration failures surface as their Domain
    /// errors, never wrapped (DES-009 §3.9).
    public func configure(
        _ request: ConfigureProviderRequest
    ) async throws -> ProviderConnection {
        try await configureValidated(request, endpoint: nil, model: nil)
    }

    /// Configures a new provider connection for `request` and records its
    /// OpenAI-compatible endpoint — the endpoint collection of the connection
    /// form (DES-011 §3.9, PRESENTATION API §3.4).
    ///
    /// The endpoint is validated at the boundary with the same rule as
    /// `updateEndpoint(_:for:)` before any domain operation (ARC-009), so a
    /// malformed endpoint is rejected before any write; the validated endpoint
    /// is then recorded through `updateEndpoint(_:for:)`, keyed by the fresh
    /// connection identity. The endpoint never enters the
    /// `ConfigureProviderRequest` or any Domain aggregate (DES-011 §3.9,
    /// ARC-004).
    public func configure(
        _ request: ConfigureProviderRequest,
        endpoint: String
    ) async throws -> ProviderConnection {
        let endpoint = try Self.validatedEndpoint(endpoint)
        return try await configureValidated(request, endpoint: endpoint, model: nil)
    }

    /// Configures a new provider connection for `request`, records its
    /// OpenAI-compatible endpoint, and records its optional model — the model
    /// and endpoint collection of the connection form (DES-011 §3.9, §3.10,
    /// PRESENTATION API §3.4).
    ///
    /// The endpoint is validated with the same rule as
    /// `updateEndpoint(_:for:)`, and `model` — when given — is validated with
    /// the same rule as `updateModel(_:for:)`, both before any domain operation
    /// (ARC-009); the validated endpoint and model are then recorded through
    /// `updateEndpoint(_:for:)` and `updateModel(_:for:)`, keyed by the fresh
    /// connection identity. `nil` records no manual model; discovery/cache may
    /// still supply a catalog. The endpoint and model never enter the
    /// `ConfigureProviderRequest` or any Domain aggregate (DES-011 §3.9, §3.10,
    /// ARC-004).
    public func configure(
        _ request: ConfigureProviderRequest,
        endpoint: String,
        model: String?
    ) async throws -> ProviderConnection {
        let endpoint = try Self.validatedEndpoint(endpoint)
        let validatedModel = try model.map(Self.validatedModel)
        return try await configureValidated(
            request,
            endpoint: endpoint,
            model: validatedModel
        )
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
    /// is deleted, and the recorded reference, endpoint, and model are removed.
    /// Removing a provider that is not stored is not an error; the operation is
    /// idempotent (DES-009 §3.5).
    public func remove(_ identity: ProviderIdentity) async throws {
        let key = Self.credentialReferenceKey(for: identity)
        let provider = try await providerRepository.provider(with: identity)
        let reference = try await configurationRepository.value(
            for: key,
            at: .providerSettings
        )
        let endpoint = try await configurationRepository.value(
            for: Self.endpointKey(for: identity),
            at: .providerSettings
        )
        let model = try await configurationRepository.value(
            for: Self.modelKey(for: identity),
            at: .providerSettings
        )
        let credential: Credential?
        if let reference {
            do {
                credential = try await credentialStorage.credential(for: reference)
            } catch CredentialStorageError.credentialNotFound {
                // A dangling reference must not make provider removal a dead
                // end. The secure-storage contract makes removal idempotent,
                // so continue and clear the remaining metadata/reference.
                credential = nil
            }
        } else {
            credential = nil
        }

        do {
            if let reference {
                try await credentialStorage.removeCredential(for: reference)
            }
            try await providerRepository.delete(identity)
            try await configurationRepository.remove(key, at: .providerSettings)
            try await configurationRepository.remove(
                Self.endpointKey(for: identity),
                at: .providerSettings
            )
            try await configurationRepository.remove(
                Self.modelKey(for: identity),
                at: .providerSettings
            )
            await lifecycleService.unregister(identity)
        } catch {
            // Restore the complete connection snapshot if a later delete step
            // fails. Raw credential material remains transient and redacted.
            if let provider { try? await providerRepository.save(provider) }
            if let endpoint {
                try? await configurationRepository.store(
                    endpoint,
                    for: Self.endpointKey(for: identity),
                    at: .providerSettings
                )
            }
            if let model {
                try? await configurationRepository.store(
                    model,
                    for: Self.modelKey(for: identity),
                    at: .providerSettings
                )
            }
            if let reference {
                try? await configurationRepository.store(
                    reference,
                    for: key,
                    at: .providerSettings
                )
                if let credential {
                    try? await credentialStorage.store(credential, for: reference)
                }
            }
            throw error
        }
    }

    /// Updates the declaration of the provider connection with `identity` —
    /// the unified provider-edit flow of the providers surface (DES-011 §3.1):
    /// the connection's declared display name, capabilities, limits, and
    /// version are replaced with `request`'s, and its OpenAI-compatible
    /// endpoint and optional model are recorded — mirroring the connection form
    /// (DES-011 §3.9, §3.10).
    ///
    /// The connection declaration is user-owned connection configuration
    /// (ARC-005) and the lifecycle state is preserved: the persisted provider
    /// keeps its current state (a ready provider stays ready), and the lifecycle
    /// service's provider is replaced with the edited connection in the same
    /// state, so selection and the runtime binding keep serving it. The
    /// credential is never touched — editing a connection never requires
    /// re-entering the secret, and the stored credential is kept by reference
    /// (ARC-001, ARC-005).
    ///
    /// Input is validated at the boundary before any write (ARC-009): an empty
    /// display name and an empty capability set are rejected; the endpoint is
    /// validated with the same rule as `updateEndpoint(_:for:)`; and `model` —
    /// when given — with the same rule as `updateModel(_:for:)`. `nil` (or an
    /// empty trimmed) model records no manual model, removing any previously
    /// recorded one. Updating a
    /// connection that is not stored is rejected with the typed application
    /// error of DES-011 §3.6.
    public func update(
        _ request: ProviderUpdateRequest,
        for identity: ProviderIdentity,
        endpoint: String,
        model: String?
    ) async throws -> ProviderConnection {
        try Self.validateUpdate(request)
        let validatedEndpoint = try Self.validatedEndpoint(endpoint)
        let validatedModel = try model.map(Self.validatedModel)
        guard let existing = try await providerRepository.provider(with: identity) else {
            throw ApplicationValidationError.invalid(
                reason: "The provider connection does not exist."
            )
        }
        let connection = ProviderConnection(
            identity: identity,
            capabilities: request.capabilities,
            metadata: ProviderMetadata(displayName: request.displayName),
            limits: request.limits,
            version: request.version
        )
        try await providerRepository.save(existing.replacingConnection(connection))
        await lifecycleService.update(connection)
        try await updateEndpoint(validatedEndpoint, for: identity)
        if let validatedModel {
            try await updateModel(validatedModel, for: identity)
        } else {
            try await configurationRepository.remove(
                Self.modelKey(for: identity),
                at: .providerSettings
            )
        }
        return connection
    }

    /// The provider-settings configuration key that records the credential
    /// reference of a provider connection, scoped by the provider identity so
    /// each connection's pointer stays separate from the others (DES-009 §3.6,
    /// ARC-005).
    ///
    /// The key is public because it is shared with the Composition Root's
    /// runtime adapter binding, which reads the same documented key the
    /// settings surface writes — the writer and the reader never diverge
    /// (DES-011 §3.4, DES-013 §3.3, DES-004).
    public static func credentialReferenceKey(
        for identity: ProviderIdentity
    ) -> ConfigurationKey<CredentialReference> {
        ConfigurationKey<CredentialReference>("providerCredential.\(identity.canonicalString)")
    }

    /// The provider-settings configuration key that records the OpenAI-compatible
    /// endpoint of a provider connection, scoped by the provider identity — the
    /// documented key the settings surface writes and the Composition Root's
    /// runtime adapter binding reads, so the writer and the reader never diverge
    /// (DES-011 §3.9, DES-013 §3.3, DES-004).
    public static func endpointKey(
        for identity: ProviderIdentity
    ) -> ConfigurationKey<String> {
        ConfigurationKey<String>("providerEndpoint.\(identity.canonicalString)")
    }

    /// The provider-settings configuration key that records the OpenAI-compatible
    /// model (the OmniRoute combo, or any provider model name) of a provider
    /// connection, scoped by the provider identity — the documented key the
    /// settings surface writes and the Composition Root's runtime adapter
    /// binding reads, so the writer and the reader never diverge (DES-011
    /// §3.10, DES-013 §3.3, DES-004). A provider with no recorded model relies
    /// on its discovered or cached catalog.
    public static func modelKey(
        for identity: ProviderIdentity
    ) -> ConfigurationKey<String> {
        ConfigurationKey<String>("providerModel.\(identity.canonicalString)")
    }

    /// Records the provider connection's OpenAI-compatible endpoint as a typed
    /// configuration value at the provider-settings level, keyed by the provider
    /// identity (DES-011 §3.9).
    ///
    /// The endpoint is validated at the boundary before any storage (ARC-009): a
    /// non-empty, absolute, `http` or `https` URL string is required, and a
    /// malformed endpoint is rejected with the typed application error of DES-011
    /// §3.6. The endpoint is connection configuration the user owns (ARC-005); it
    /// never enters the `ProviderConnection` or `Provider` aggregate (DES-009
    /// §3.1), and the service never builds a transport or an adapter — the address
    /// is resolved by the Composition Root when a request is built, in the layer
    /// that owns transport (DES-010 §3.9.3, DES-013 §3.3, ARC-004).
    public func updateEndpoint(
        _ endpoint: String,
        for identity: ProviderIdentity
    ) async throws {
        let trimmed = try Self.validatedEndpoint(endpoint)
        try await configurationRepository.store(
            trimmed,
            for: Self.endpointKey(for: identity),
            at: .providerSettings
        )
    }

    /// Records the provider connection's OpenAI-compatible model as a typed
    /// configuration value at the provider-settings level, keyed by the provider
    /// identity (DES-011 §3.10).
    ///
    /// The model is validated at the boundary before any storage (ARC-009): a
    /// non-empty trimmed string is required, and an empty model is rejected with
    /// the typed application error of DES-011 §3.6. The model is connection
    /// configuration the user owns (ARC-005); it never enters the
    /// `ProviderConnection` or `Provider` aggregate (DES-009 §3.1), and the
    /// service never builds a transport or an adapter — the model is resolved by
    /// the Composition Root when a request is built, in the layer that owns
    /// transport (DES-010 §3.9.3, DES-013 §3.3, ARC-004).
    public func updateModel(
        _ model: String,
        for identity: ProviderIdentity
    ) async throws {
        let trimmed = try Self.validatedModel(model)
        try await configurationRepository.store(
            trimmed,
            for: Self.modelKey(for: identity),
            at: .providerSettings
        )
    }

    /// Returns the recorded OpenAI-compatible model of the provider connection
    /// with `identity`, or `nil` when none is recorded (DES-011 §3.10).
    public func model(
        for identity: ProviderIdentity
    ) async throws -> String? {
        try await configurationRepository.value(
            for: Self.modelKey(for: identity),
            at: .providerSettings
        )
    }

    /// Validates an endpoint at the boundary (ARC-009, DES-011 §3.9): the
    /// trimmed string must be a non-empty absolute `http` or `https` URL,
    /// returned for storage; a malformed endpoint is rejected with the typed
    /// application error of DES-011 §3.6. The same rule guards
    /// `updateEndpoint(_:for:)` and the endpoint-collecting `configure(_:endpoint:)`.
    private static func validatedEndpoint(_ endpoint: String) throws -> String {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ApplicationValidationError.invalid(reason: "The endpoint is empty.")
        }
        guard let separator = trimmed.firstRange(of: "://") else {
            throw ApplicationValidationError.invalid(
                reason: "The endpoint must be an absolute http or https URL."
            )
        }
        let scheme = trimmed[..<separator.lowerBound].lowercased()
        let authority = trimmed[separator.upperBound...]
        guard !scheme.isEmpty, scheme == "http" || scheme == "https", !authority.isEmpty else {
            throw ApplicationValidationError.invalid(
                reason: "The endpoint must be an absolute http or https URL."
            )
        }
        return trimmed
    }

    /// Validates a model at the boundary (ARC-009, DES-011 §3.10): the trimmed
    /// string must be non-empty, returned for storage; an empty model is
    /// rejected with the typed application error of DES-011 §3.6. The same rule
    /// guards `updateModel(_:for:)` and the model-collecting
    /// `configure(_:endpoint:model:)`.
    private static func validatedModel(_ model: String) throws -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ApplicationValidationError.invalid(reason: "The model is empty.")
        }
        return trimmed
    }

    /// Returns the recorded OpenAI-compatible endpoint of the provider connection
    /// with `identity`, or `nil` when none is recorded (DES-011 §3.9).
    public func endpoint(
        for identity: ProviderIdentity
    ) async throws -> String? {
        try await configurationRepository.value(
            for: Self.endpointKey(for: identity),
            at: .providerSettings
        )
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

    /// Validates an update request at the boundary (ARC-009, DES-011 §3.6):
    /// the display name must be non-empty and the capability set non-empty —
    /// the connection declaration must remain complete. The credential is never
    /// validated here: editing a connection never requires re-entering it
    /// (ARC-001, ARC-005).
    private static func validateUpdate(_ request: ProviderUpdateRequest) throws {
        let trimmedName = request.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ApplicationValidationError.invalid(reason: "The display name is empty.")
        }
        guard !request.capabilities.capabilities.isEmpty else {
            throw ApplicationValidationError.invalid(
                reason: "The provider must declare at least one capability."
            )
        }
    }

    /// Persists a validated provider declaration, secret reference, optional
    /// endpoint/model, and ready lifecycle as one rollback-safe application
    /// operation. A failed step cannot leave a selectable provider or an
    /// unreferenced credential behind.
    private func configureValidated(
        _ request: ConfigureProviderRequest,
        endpoint: String?,
        model: String?
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
        var providerStored = false
        var credentialStored = false
        do {
            try await providerRepository.save(Provider(connection: connection))
            providerStored = true
            try await credentialStorage.store(request.credential, for: reference)
            credentialStored = true
            try await configurationRepository.store(
                reference,
                for: Self.credentialReferenceKey(for: identity),
                at: .providerSettings
            )
            if let endpoint {
                try await configurationRepository.store(
                    endpoint,
                    for: Self.endpointKey(for: identity),
                    at: .providerSettings
                )
            }
            if let model {
                try await configurationRepository.store(
                    model,
                    for: Self.modelKey(for: identity),
                    at: .providerSettings
                )
            }
            try await makeReady(connection)
            return connection
        } catch {
            await lifecycleService.unregister(identity)
            try? await configurationRepository.remove(
                Self.modelKey(for: identity),
                at: .providerSettings
            )
            try? await configurationRepository.remove(
                Self.endpointKey(for: identity),
                at: .providerSettings
            )
            try? await configurationRepository.remove(
                Self.credentialReferenceKey(for: identity),
                at: .providerSettings
            )
            if credentialStored {
                try? await credentialStorage.removeCredential(for: reference)
            }
            if providerStored {
                try? await providerRepository.delete(identity)
            }
            throw error
        }
    }

    /// Wires a freshly configured connection into the running session (DES-013
    /// §3.3): it is registered in the lifecycle service and transitioned through
    /// the legal chain to ready, and the ready state is persisted back to the
    /// repository — the same idempotent chain `prepare()` drives, so a provider
    /// that is actually available renders available immediately, not only after
    /// the next launch.
    private func makeReady(_ connection: ProviderConnection) async throws {
        let identity = await lifecycleService.register(connection)
        try await lifecycleService.transition(identity, to: .validated)
        try await lifecycleService.transition(identity, to: .initializing)
        try await lifecycleService.transition(identity, to: .ready)
        if let readyProvider = await lifecycleService.provider(with: identity) {
            try await providerRepository.save(readyProvider)
        }
    }
}
