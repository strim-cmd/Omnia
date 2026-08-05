import Foundation
import XCTest
@testable import OmniaFoundation

/// A declared set of states for a test-specific lifecycle.
private enum MachineState: LifecycleState {
    case idle
    case running
    case paused
    case stopped
    case failed
}

/// The legal transitions declared for the test lifecycle.
private let legalTransitions: Set<LifecycleTransition<MachineState>> = [
    LifecycleTransition(from: .idle, to: .running),
    LifecycleTransition(from: .running, to: .paused),
    LifecycleTransition(from: .running, to: .stopped),
    LifecycleTransition(from: .running, to: .failed),
    LifecycleTransition(from: .paused, to: .running),
    LifecycleTransition(from: .paused, to: .stopped),
    LifecycleTransition(from: .stopped, to: .idle),
    LifecycleTransition(from: .failed, to: .idle),
]

/// A test lifecycle built from the declared states and legal transitions.
private func makeMachine(initial: MachineState = .idle) -> Lifecycle<MachineState> {
    Lifecycle(initialState: initial, legalTransitions: legalTransitions)
}

/// A test observer that records every received event, in order.
private final class RecordingObserver: LifecycleObserver, @unchecked Sendable {
    typealias State = MachineState

    private let lock = NSLock()
    private var recorded: [LifecycleEvent<MachineState>] = []

    func lifecycleDidTransition(_ event: LifecycleEvent<MachineState>) {
        lock.lock()
        defer { lock.unlock() }
        recorded.append(event)
    }

    var events: [LifecycleEvent<MachineState>] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }
}

final class LifecycleTests: XCTestCase {

    // MARK: Initial state

    func testInitialState_ReportsDeclaredInitialState() {
        let machine = makeMachine(initial: .idle)
        XCTAssertEqual(machine.currentState, .idle)
    }

    func testInitialState_CanStartInAnyDeclaredState() {
        let machine = makeMachine(initial: .running)
        XCTAssertEqual(machine.currentState, .running)
    }

    // MARK: Legal transitions

    func testTransition_LegalTransitionChangesStateAndReturnsEvent() {
        let machine = makeMachine()
        let event = machine.transition(to: .running)
        XCTAssertEqual(machine.currentState, .running)
        XCTAssertEqual(event, LifecycleEvent(previousState: .idle, newState: .running))
    }

    func testTransition_SequenceMovesThroughDeclaredOrder() {
        let machine = makeMachine()
        XCTAssertNotNil(machine.transition(to: .running))
        XCTAssertNotNil(machine.transition(to: .paused))
        XCTAssertNotNil(machine.transition(to: .running))
        XCTAssertNotNil(machine.transition(to: .stopped))
        XCTAssertNotNil(machine.transition(to: .idle))
        XCTAssertEqual(machine.currentState, .idle)
    }

    func testTransition_RejectedTransitionLeavesStateUnchanged() {
        let machine = makeMachine()
        XCTAssertNil(machine.transition(to: .stopped))
        XCTAssertEqual(machine.currentState, .idle)
    }

    func testTransition_LegalityIsCheckedAgainstCurrentState() {
        let machine = makeMachine()
        XCTAssertNotNil(machine.transition(to: .running))
        XCTAssertNil(machine.transition(to: .idle))
        XCTAssertEqual(machine.currentState, .running)
    }

    func testTransition_SelfTransitionIsRejectedUnlessDeclared() {
        let machine = makeMachine()
        XCTAssertNotNil(machine.transition(to: .running))
        XCTAssertNil(machine.transition(to: .running))
        XCTAssertEqual(machine.currentState, .running)
    }

    func testTransition_ReturnedEventMatchesRecordedEvent() {
        let machine = makeMachine()
        let observer = RecordingObserver()
        machine.addObserver(observer)
        let returned = machine.transition(to: .running)
        XCTAssertEqual(returned, observer.events.first)
        XCTAssertEqual(observer.events.count, 1)
    }

    // MARK: Observation

    func testObservation_EveryObserverReceivesEveryEmittedEvent() {
        let machine = makeMachine()
        let first = RecordingObserver()
        let second = RecordingObserver()
        let third = RecordingObserver()
        machine.addObserver(first)
        machine.addObserver(second)
        machine.addObserver(third)
        machine.transition(to: .running)
        machine.transition(to: .paused)
        machine.transition(to: .running)
        XCTAssertEqual(first.events.count, 3)
        XCTAssertEqual(second.events.count, 3)
        XCTAssertEqual(third.events.count, 3)
    }

    func testObservation_EventsAreIdenticalToEveryObserver() {
        let machine = makeMachine()
        let first = RecordingObserver()
        let second = RecordingObserver()
        machine.addObserver(first)
        machine.addObserver(second)
        machine.transition(to: .running)
        machine.transition(to: .paused)
        XCTAssertEqual(first.events, second.events)
    }

    func testObservation_EventsDeliveredInOrder() {
        let machine = makeMachine()
        let observer = RecordingObserver()
        machine.addObserver(observer)
        machine.transition(to: .running)
        machine.transition(to: .paused)
        machine.transition(to: .stopped)
        XCTAssertEqual(observer.events, [
            LifecycleEvent(previousState: .idle, newState: .running),
            LifecycleEvent(previousState: .running, newState: .paused),
            LifecycleEvent(previousState: .paused, newState: .stopped),
        ])
    }

    func testObservation_EventCarriesPreviousAndNewStates() {
        let machine = makeMachine()
        let observer = RecordingObserver()
        machine.addObserver(observer)
        machine.transition(to: .running)
        machine.transition(to: .paused)
        let event = observer.events[1]
        XCTAssertEqual(event.previousState, .running)
        XCTAssertEqual(event.newState, .paused)
    }

    func testObservation_RegisteredObserverReceivesOnlyFutureEvents() {
        let machine = makeMachine()
        machine.transition(to: .running)
        let observer = RecordingObserver()
        machine.addObserver(observer)
        machine.transition(to: .paused)
        XCTAssertEqual(observer.events.count, 1)
        XCTAssertEqual(observer.events.first, LifecycleEvent(previousState: .running, newState: .paused))
    }

    func testObservation_RejectedTransitionProducesNoEventForAnyObserver() {
        let machine = makeMachine()
        let observer = RecordingObserver()
        machine.addObserver(observer)
        XCTAssertNil(machine.transition(to: .stopped))
        XCTAssertTrue(observer.events.isEmpty)
    }

    // MARK: Event value semantics

    func testEvent_IsAnImmutableValue() {
        let original = LifecycleEvent<MachineState>(previousState: .idle, newState: .running)
        var copy = original
        copy = LifecycleEvent<MachineState>(previousState: .running, newState: .paused)
        XCTAssertEqual(original, LifecycleEvent(previousState: .idle, newState: .running))
        XCTAssertEqual(copy, LifecycleEvent(previousState: .running, newState: .paused))
        XCTAssertNotEqual(original, copy)
    }

    func testEvent_EventsWithSameContentAreEqual() {
        let a = LifecycleEvent<MachineState>(previousState: .idle, newState: .running)
        let b = LifecycleEvent<MachineState>(previousState: .idle, newState: .running)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, LifecycleEvent(previousState: .idle, newState: .stopped))
    }

    // MARK: Transition declaration

    func testTransition_DeclaredSetMembershipIsDeterministic() {
        let declared = Set(legalTransitions)
        XCTAssertTrue(declared.contains(LifecycleTransition(from: .idle, to: .running)))
        XCTAssertTrue(declared.contains(LifecycleTransition(from: .paused, to: .stopped)))
        XCTAssertFalse(declared.contains(LifecycleTransition(from: .idle, to: .stopped)))
        XCTAssertFalse(declared.contains(LifecycleTransition(from: .running, to: .idle)))
    }

    // MARK: Deterministic behaviour

    func testDeterministic_SameSequenceYieldsSameFinalStateAndEvents() {
        let first = makeMachine()
        let second = makeMachine()
        let firstObserver = RecordingObserver()
        let secondObserver = RecordingObserver()
        first.addObserver(firstObserver)
        second.addObserver(secondObserver)

        let sequence: [MachineState] = [.running, .paused, .running, .stopped, .idle, .running]
        for target in sequence {
            XCTAssertNotNil(first.transition(to: target))
            XCTAssertNotNil(second.transition(to: target))
        }

        XCTAssertEqual(first.currentState, second.currentState)
        XCTAssertEqual(firstObserver.events, secondObserver.events)
    }

    func testTransition_IsSynchronousAndImmediate() {
        let machine = makeMachine()
        let result = machine.transition(to: .running)
        XCTAssertEqual(machine.currentState, .running)
        XCTAssertNotNil(result)
    }

    // MARK: Concurrent use

    func testConcurrent_ConcurrentTransitionsSerializeExactly() async {
        let machine = makeMachine()
        let accepted: [Bool] = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<100 {
                group.addTask { machine.transition(to: .running) != nil }
            }
            var collected: [Bool] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }
        XCTAssertEqual(accepted.filter { $0 }.count, 1)
        XCTAssertEqual(machine.currentState, .running)
    }

    func testConcurrent_ReadsAreConsistentAfterTransition() async {
        let machine = makeMachine()
        machine.transition(to: .running)
        let reads: [MachineState] = await withTaskGroup(of: MachineState.self) { group in
            for _ in 0..<100 {
                group.addTask { machine.currentState }
            }
            var collected: [MachineState] = []
            for await read in group {
                collected.append(read)
            }
            return collected
        }
        XCTAssertEqual(reads.count, 100)
        XCTAssertTrue(reads.allSatisfy { $0 == .running })
    }

    // MARK: Sendability

    func testSendability_ShareAcrossConcurrencyDomain() async {
        let machine = makeMachine()
        let finalState = await Task.detached {
            machine.transition(to: .running)
            machine.transition(to: .paused)
            return machine.currentState
        }.value
        XCTAssertEqual(finalState, .paused)
    }
}
