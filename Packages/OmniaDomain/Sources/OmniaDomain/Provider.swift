import OmniaFoundation

/// The failures a provider lifecycle can report (DES-009 §3.2).
public enum ProviderLifecycleError: Error, Equatable, Sendable {
    /// The requested transition is not declared legal (ARC-004).
    case invalidTransition(from: ProviderState, to: ProviderState)
    /// The provider is not known to the lifecycle service.
    case providerNotFound(identity: ProviderIdentity)
}

/// The Provider aggregate: the provider connection the user has configured,
/// enforcing its lifecycle and the invariants of its declared capabilities
/// (ARC-004, DES-009 §3.1, §3.4).
///
/// The aggregate owns its lifecycle on the Foundation `Lifecycle` primitive
/// (DES-007): the states and legal transitions are defined here (ARC-004); a
/// state changes only through a legal transition, and an illegal transition is
/// rejected with an explicit typed failure (DES-009 §3.2). The lifecycle
/// service (DES-009 §3.2) drives the aggregate through these transitions;
/// observation is one-way. The aggregate carries the declared capabilities,
/// metadata, limits, and versioning of its connection and never holds
/// credentials (ARC-004, ARC-005).
///
/// The aggregate is an entity: it has identity and continuity through its
/// lifecycle. The declared connection data is immutable; the lifecycle is the
/// only changing part.
public struct Provider: Sendable {
    /// The declared provider connection.
    public let connection: ProviderConnection

    private let lifecycle: Lifecycle<ProviderState>

    /// Creates a provider aggregate for `connection`, registered.
    public init(connection: ProviderConnection) {
        self.connection = connection
        self.lifecycle = Lifecycle(initialState: .registered, legalTransitions: Self.legalTransitions)
    }

    /// The provider's stable identity.
    public var identity: ProviderIdentity {
        connection.identity
    }

    /// The provider's current lifecycle state.
    public var state: ProviderState {
        lifecycle.currentState
    }

    /// Returns whether the provider declares it can deliver `capability`.
    ///
    /// The invariant is the declared capability set of the connection; it
    /// never changes once configured (ARC-004).
    public func canDeliver(_ capability: Capability) -> Bool {
        connection.capabilities.contains(capability)
    }

    /// Applies the transition to `state` when it is declared legal.
    ///
    /// Throws `ProviderLifecycleError.invalidTransition` when the transition is
    /// not legal; the state is then unchanged (DES-009 §3.2).
    public func transition(to state: ProviderState) throws {
        guard lifecycle.transition(to: state) != nil else {
            throw ProviderLifecycleError.invalidTransition(from: lifecycle.currentState, to: state)
        }
    }

    /// Registers `observer` to receive every future lifecycle event.
    ///
    /// Observation is one-way: the observer never alters a transition (DES-007).
    public func addObserver(_ observer: any LifecycleObserver<ProviderState>) {
        lifecycle.addObserver(observer)
    }

    /// The legal transitions of the provider lifecycle (ARC-004).
    private static let legalTransitions: Set<LifecycleTransition<ProviderState>> = [
        LifecycleTransition(from: .registered, to: .validated),
        LifecycleTransition(from: .validated, to: .initializing),
        LifecycleTransition(from: .initializing, to: .ready),
        LifecycleTransition(from: .initializing, to: .unavailable),
        LifecycleTransition(from: .ready, to: .unavailable),
        LifecycleTransition(from: .unavailable, to: .initializing),
        LifecycleTransition(from: .ready, to: .disabled),
        LifecycleTransition(from: .unavailable, to: .disabled),
        LifecycleTransition(from: .disabled, to: .initializing),
        LifecycleTransition(from: .ready, to: .removed),
        LifecycleTransition(from: .unavailable, to: .removed),
        LifecycleTransition(from: .disabled, to: .removed),
    ]
}
