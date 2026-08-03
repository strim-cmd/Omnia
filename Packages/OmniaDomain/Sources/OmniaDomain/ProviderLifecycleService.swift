import OmniaFoundation

/// The domain service that owns the provider lifecycle state machine
/// (ARC-004, DES-009 §3.2).
///
/// The service manages the providers known to the application and drives each
/// provider's lifecycle on the Foundation `Lifecycle` primitive (DES-007): the
/// states and legal transitions are defined by the Provider module, and a
/// state transition is the only way a provider changes status (ARC-004). An
/// illegal transition is rejected with an explicit typed failure and leaves
/// the provider unchanged; a transition of an unknown provider is likewise an
/// explicit typed failure (DES-007).
///
/// The service holds no persistence; the registry is the set of providers known
/// to the running application. Persistence belongs to the repository contracts
/// and OmniaInfrastructure (DES-009 §3.5).
public actor ProviderLifecycleService {
    private var providers: [ProviderIdentity: Provider]

    /// Creates a lifecycle service with no known providers.
    public init() {
        self.providers = [:]
    }

    /// Registers `connection` and returns its identity.
    ///
    /// The provider enters the lifecycle in the `registered` state; a
    /// registration replaces any previously registered provider with the same
    /// identity.
    @discardableResult
    public func register(_ connection: ProviderConnection) -> ProviderIdentity {
        let provider = Provider(connection: connection)
        providers[provider.identity] = provider
        return provider.identity
    }

    /// Returns the provider with `identity`, or `nil` when unknown.
    public func provider(with identity: ProviderIdentity) -> Provider? {
        providers[identity]
    }

    /// The current lifecycle state of the provider with `identity`, or `nil`
    /// when unknown.
    public func state(of identity: ProviderIdentity) -> ProviderState? {
        providers[identity]?.state
    }

    /// Applies the transition to `state` for the provider with `identity`.
    ///
    /// Throws `ProviderLifecycleError.providerNotFound` when the provider is
    /// unknown, or `ProviderLifecycleError.invalidTransition` when the
    /// transition is not legal; the provider's state is unchanged in either
    /// case (DES-007, ARC-004).
    public func transition(_ identity: ProviderIdentity, to state: ProviderState) throws {
        guard let provider = providers[identity] else {
            throw ProviderLifecycleError.providerNotFound(identity: identity)
        }
        try provider.transition(to: state)
    }

    /// Returns the identities of the providers known to the service.
    public func allProviders() -> [ProviderIdentity] {
        Array(providers.keys)
    }

    /// Returns the identities of the providers that are ready and can deliver
    /// `capability` (ARC-004 Provider Lifecycle, Capability Discovery).
    public func providersReady(capableOf capability: Capability) -> [ProviderIdentity] {
        providers.values
            .filter { $0.state == .ready && $0.canDeliver(capability) }
            .map(\.identity)
    }
}
