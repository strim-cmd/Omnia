import OmniaDomain

/// The user-visible state of one provider's model catalog.
public enum ProviderModelCatalogStatus: Equatable, Sendable {
    case loading
    case loaded
    case empty
    case configuredFallback
    case cached
    case unavailable(ModelCatalogError)
    case stale(ModelCatalogError)
    case failed(ModelCatalogError)
}

/// A deterministic snapshot of one provider's models and catalog condition.
public struct ProviderModelCatalog: Equatable, Sendable {
    public let provider: ProviderIdentity
    public let models: [ModelDescriptor]
    public let status: ProviderModelCatalogStatus

    public init(
        provider: ProviderIdentity,
        models: [ModelDescriptor],
        status: ProviderModelCatalogStatus
    ) {
        self.provider = provider
        self.models = models
        self.status = status
    }
}

/// Owns model discovery cache, configured fallback, model capability overrides,
/// and the coherent global default provider/model selection.
public actor ProviderModelService {
    private let configurationService: ConfigurationService
    private let lifecycleService: ProviderLifecycleService
    private let configuredModel: @Sendable (ProviderIdentity) async throws -> ModelReference?
    private let discoverModels: @Sendable (ProviderIdentity) async throws -> [ModelReference]

    public static let defaultSelectionKey =
        ConfigurationKey<ProviderModelSelection>("models.defaultSelection")

    public init(
        configurationService: ConfigurationService,
        lifecycleService: ProviderLifecycleService,
        configuredModel: @escaping @Sendable (ProviderIdentity) async throws -> ModelReference?,
        discoverModels: @escaping @Sendable (ProviderIdentity) async throws -> [ModelReference]
    ) {
        self.configurationService = configurationService
        self.lifecycleService = lifecycleService
        self.configuredModel = configuredModel
        self.discoverModels = discoverModels
    }

    public static func cachedModelsKey(
        for provider: ProviderIdentity
    ) -> ConfigurationKey<[ModelReference]> {
        ConfigurationKey("models.cache.\(provider.canonicalString)")
    }

    public static func capabilityOverrideKey(
        for selection: ProviderModelSelection
    ) -> ConfigurationKey<ModelCapabilityProfile> {
        ConfigurationKey(
            "models.capabilities.\(selection.provider.canonicalString).\(safeKeyComponent(selection.model.name))"
        )
    }

    /// Encodes provider-returned model names into a path-safe, collision-free
    /// component before they reach the file-backed configuration repository.
    private static func safeKeyComponent(_ value: String) -> String {
        value.utf8.map { byte in
            let hexadecimal = String(byte, radix: 16)
            return hexadecimal.count == 1 ? "0\(hexadecimal)" : hexadecimal
        }.joined()
    }

    /// Returns a cached/configured snapshot without network access.
    public func cachedCatalog(
        for provider: ProviderIdentity
    ) async throws -> ProviderModelCatalog {
        let cached = try await configurationService.value(
            for: Self.cachedModelsKey(for: provider),
            at: .providerSettings
        ) ?? []
        let fallback = try await configuredModel(provider)
        let references = Self.merging(cached, fallback: fallback)
        let descriptors = try await descriptors(
            references,
            provider: provider,
            discovered: Set(cached)
        )
        let status: ProviderModelCatalogStatus
        if !cached.isEmpty {
            status = .cached
        } else if fallback != nil {
            status = .configuredFallback
        } else {
            status = .empty
        }
        return ProviderModelCatalog(provider: provider, models: descriptors, status: status)
    }

    /// Refreshes through the generic discovery path. A failure preserves cached
    /// or configured models and reports stale/unavailable rather than erasing a
    /// valid saved selection.
    public func refreshCatalog(
        for provider: ProviderIdentity
    ) async throws -> ProviderModelCatalog {
        let cached = try await configurationService.value(
            for: Self.cachedModelsKey(for: provider),
            at: .providerSettings
        ) ?? []
        let fallback = try await configuredModel(provider)
        do {
            let discovered = Self.normalized(try await discoverModels(provider))
            try await configurationService.store(
                discovered,
                for: Self.cachedModelsKey(for: provider),
                at: .providerSettings
            )
            let references = Self.merging(discovered, fallback: fallback)
            return ProviderModelCatalog(
                provider: provider,
                models: try await descriptors(
                    references,
                    provider: provider,
                    discovered: Set(discovered)
                ),
                status: discovered.isEmpty ? .empty : .loaded
            )
        } catch let error as ModelCatalogError {
            let references = Self.merging(cached, fallback: fallback)
            let status: ProviderModelCatalogStatus
            if !cached.isEmpty {
                status = .stale(error)
            } else if fallback != nil {
                status = .unavailable(error)
            } else {
                status = .failed(error)
            }
            return ProviderModelCatalog(
                provider: provider,
                models: try await descriptors(
                    references,
                    provider: provider,
                    discovered: Set(cached)
                ),
                status: status
            )
        }
    }

    /// Models selection may route to without initiating network work.
    public func offeredModels(for provider: ProviderIdentity) async -> [ModelReference] {
        do {
            return try await cachedCatalog(for: provider).models.map(\.selection.model)
        } catch {
            return []
        }
    }

    /// Seeds the provider-scoped cache from a successful real connection test.
    /// This closes the validation-to-refresh gap without treating the list as
    /// capability metadata: the records establish model identity only.
    public func recordValidatedModels(
        _ models: [ModelReference],
        for provider: ProviderIdentity
    ) async throws {
        try await configurationService.store(
            Self.normalized(models),
            for: Self.cachedModelsKey(for: provider),
            at: .providerSettings
        )
    }

    public func defaultSelection() async throws -> ProviderModelSelection? {
        try await configurationService.value(
            for: Self.defaultSelectionKey,
            at: .globalDefault
        )
    }

    public func setDefaultSelection(
        _ selection: ProviderModelSelection?
    ) async throws {
        guard let selection else {
            try await configurationService.remove(
                Self.defaultSelectionKey,
                at: .globalDefault
            )
            return
        }
        guard await isAvailable(selection) else {
            throw CapabilityError.modelUnavailable(model: selection.model)
        }
        try await configurationService.store(
            selection,
            for: Self.defaultSelectionKey,
            at: .globalDefault
        )
    }

    /// Only a valid default is inherited by a newly created conversation.
    public func validDefaultSelection() async throws -> ProviderModelSelection? {
        guard let selection = try await defaultSelection() else { return nil }
        return await isAvailable(selection) ? selection : nil
    }

    public func isAvailable(_ selection: ProviderModelSelection) async -> Bool {
        guard await lifecycleService.state(of: selection.provider) == .ready else {
            return false
        }
        return await offeredModels(for: selection.provider).contains(selection.model)
    }

    /// Persists explicit model-specific facts separately from discovered and
    /// provider-wide capabilities.
    public func setCapabilityOverride(
        _ profile: ModelCapabilityProfile?,
        for selection: ProviderModelSelection
    ) async throws {
        let key = Self.capabilityOverrideKey(for: selection)
        if let profile {
            try await configurationService.store(profile, for: key, at: .providerSettings)
        } else {
            try await configurationService.remove(key, at: .providerSettings)
        }
    }

    public func effectiveSupport(
        for capability: Capability,
        selection: ProviderModelSelection,
        providerCapabilities: ProviderCapabilities
    ) async throws -> ModelCapabilitySupport {
        guard providerCapabilities.contains(capability) else {
            return .unsupported
        }
        let override = try await configurationService.value(
            for: Self.capabilityOverrideKey(for: selection),
            at: .providerSettings
        )
        if let override {
            return override.support(for: capability)
        }
        // Generic model lists do not establish multimodal input support.
        if capability == .vision || capability == .documentInput {
            return .unknown
        }
        return .supported
    }

    private func descriptors(
        _ references: [ModelReference],
        provider: ProviderIdentity,
        discovered: Set<ModelReference>
    ) async throws -> [ModelDescriptor] {
        var result: [ModelDescriptor] = []
        result.reserveCapacity(references.count)
        for reference in references {
            let selection = ProviderModelSelection(provider: provider, model: reference)
            let override = try await configurationService.value(
                for: Self.capabilityOverrideKey(for: selection),
                at: .providerSettings
            )
            result.append(
                ModelDescriptor(
                    selection: selection,
                    capabilities: override ?? ModelCapabilityProfile(),
                    source: override != nil
                        ? .userDeclared
                        : (discovered.contains(reference) ? .discovered : .configuredFallback)
                )
            )
        }
        return result
    }

    private static func normalized(_ models: [ModelReference]) -> [ModelReference] {
        let names = models
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(names)).sorted().map(ModelReference.init(name:))
    }

    private static func merging(
        _ discovered: [ModelReference],
        fallback: ModelReference?
    ) -> [ModelReference] {
        var result = normalized(discovered)
        if let fallback, !result.contains(fallback) {
            result.append(fallback)
        }
        return result
    }
}
