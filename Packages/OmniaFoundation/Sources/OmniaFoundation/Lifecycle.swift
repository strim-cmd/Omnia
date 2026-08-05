import Foundation

/// A named, distinct condition a component can be in.
///
/// The owning module declares the states of its specific lifecycle by
/// conforming a state type to this protocol. The set is explicit, finite, and
/// typed; the abstraction provides the mechanism, never the states (DES-007,
/// DES-001 §3.2).
public protocol LifecycleState: Sendable, Hashable {}

/// A defined, legal movement from one state to another.
///
/// A transition is the only way a state changes. Transitions are declared by
/// the owning module as the set of legal movements; a movement that is not
/// declared legal is illegal and is rejected (DES-007).
public struct LifecycleTransition<State: LifecycleState>: Sendable, Equatable, Hashable {
    /// The state the transition moves from.
    public let from: State
    /// The state the transition moves to.
    public let to: State

    /// Creates a legal movement from `from` to `to`.
    public init(from: State, to: State) {
        self.from = from
        self.to = to
    }
}

/// An immutable record of a transition: the previous state and the new state.
///
/// An event is a value; it reveals the transition and nothing else, and it
/// carries no product meaning. Every observer receives the same event, intact
/// (DES-007).
public struct LifecycleEvent<State: LifecycleState>: Sendable, Equatable {
    /// The state the lifecycle was in before the transition.
    public let previousState: State
    /// The state the lifecycle is in after the transition.
    public let newState: State

    /// Creates an event recording a transition from `previousState` to `newState`.
    public init(previousState: State, newState: State) {
        self.previousState = previousState
        self.newState = newState
    }
}

/// A consumer notified when a transition occurs.
///
/// An observer receives every emitted event, in order, and never influences
/// the lifecycle: observation is one-way, and an observer cannot drive, veto,
/// or alter a transition (DES-007).
public protocol LifecycleObserver<State>: Sendable {
    /// The lifecycle state the observer observes.
    associatedtype State: LifecycleState

    /// Receives `event`, an immutable record of a transition.
    func lifecycleDidTransition(_ event: LifecycleEvent<State>)
}

/// A generic state-transition primitive for a long-lived component.
///
/// The lifecycle tracks the component's current state, accepts only legal
/// transitions, and emits an immutable event to every observer for every
/// transition. It encodes no specific lifecycle: the owning module declares
/// the states and the legal transitions (DES-001 §3.2). The owner drives the
/// lifecycle; observers only receive events (DES-007).
public final class Lifecycle<State: LifecycleState>: @unchecked Sendable {
    private let lock = NSLock()
    private var state: State
    private let legalTransitions: Set<LifecycleTransition<State>>
    private var observers: [any LifecycleObserver<State>] = []

    /// Creates a lifecycle starting in `initialState` with the declared legal
    /// transitions `legalTransitions`.
    ///
    /// Only the owning module constructs a lifecycle and drives its component
    /// through legal transitions (DES-007).
    public init(
        initialState: State,
        legalTransitions: Set<LifecycleTransition<State>>
    ) {
        self.state = initialState
        self.legalTransitions = legalTransitions
    }

    /// The component's current state.
    ///
    /// The state changes only through a legal transition.
    public var currentState: State {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    /// Registers `observer` to receive every future emitted event.
    ///
    /// Observation is one-way: the observer receives events and never alters
    /// a transition. Events emitted before registration are not delivered.
    public func addObserver(_ observer: any LifecycleObserver<State>) {
        lock.lock()
        defer { lock.unlock() }
        observers.append(observer)
    }

    /// Applies the transition from the current state to `newState` when it is
    /// declared legal.
    ///
    /// Returns the emitted event when the transition is accepted; returns
    /// `nil` when the transition is rejected. A rejected transition leaves the
    /// current state unchanged and emits no event. Transitions are
    /// deterministic: the same transition from the same state always produces
    /// the same outcome (DES-007).
    @discardableResult
    public func transition(to newState: State) -> LifecycleEvent<State>? {
        lock.lock()
        let transition = LifecycleTransition(from: state, to: newState)
        guard legalTransitions.contains(transition) else {
            lock.unlock()
            return nil
        }
        let event = LifecycleEvent(previousState: state, newState: newState)
        state = newState
        let recipients = observers
        lock.unlock()

        for observer in recipients {
            observer.lifecycleDidTransition(event)
        }
        return event
    }
}
