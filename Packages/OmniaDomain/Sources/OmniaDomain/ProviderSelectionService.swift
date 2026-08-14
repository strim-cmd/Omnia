/// The domain service that applies the provider selection strategy and returns
/// the selected provider and model (ARC-001, ARC-004, DES-009 §3.2).
///
/// The service gathers the ready providers able to deliver the required
/// capability from the `ProviderLifecycleService`, asks for each provider's
/// offered models, and delegates the decision to the pure
/// `ProviderSelectionPolicy`. The result is the selected provider and model,
/// or an explicit failure when no provider can deliver (ARC-004).
///
/// The offered models are provided by the caller through a dependency; the
/// service holds no provider- or model-specific knowledge (ARC-004, ARC-009).
public actor ProviderSelectionService {
    private let lifecycleService: ProviderLifecycleService
    private let policy: ProviderSelectionPolicy
    private let preferredModels: @Sendable (ProviderIdentity) async -> [ModelReference]

    /// Creates a selection service over `lifecycleService`, using `policy` and
    /// `preferredModels` to obtain the models each provider offers.
    public init(
        lifecycleService: ProviderLifecycleService,
        policy: ProviderSelectionPolicy = ProviderSelectionPolicy(),
        preferredModels: @escaping @Sendable (ProviderIdentity) async -> [ModelReference]
    ) {
        self.lifecycleService = lifecycleService
        self.policy = policy
        self.preferredModels = preferredModels
    }

    /// Selects a provider able to deliver `capability`.
    ///
    /// `userSelection`, `workspacePreference`, and `capabilityPreference` are
    /// honored in the documented priority; `nil` means the user or the current
    /// workspace expressed no choice (ARC-004).
    public func select(
        requiredCapability capability: Capability,
        explicitSelection: ProviderModelSelection? = nil,
        userSelection: ProviderIdentity? = nil,
        workspacePreference: ProviderIdentity? = nil,
        capabilityPreference: ProviderIdentity? = nil
    ) async -> ProviderSelectionResult {
        let identities = await lifecycleService.providersReady(capableOf: capability)
        var candidates: [ProviderCandidate] = []
        candidates.reserveCapacity(identities.count)
        for identity in identities {
            let models = await preferredModels(identity)
            candidates.append(ProviderCandidate(provider: identity, models: models))
        }
        return policy.select(
            candidates: candidates,
            explicitSelection: explicitSelection,
            userSelection: userSelection,
            workspacePreference: workspacePreference,
            capabilityPreference: capabilityPreference
        )
    }
}
