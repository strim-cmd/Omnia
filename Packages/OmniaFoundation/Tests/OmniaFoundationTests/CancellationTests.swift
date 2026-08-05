import Foundation
import XCTest
@testable import OmniaFoundation

/// A controllable manual cancellation source double.
///
/// The source owns a shared, lock-guarded signal. Every observation derived
/// from the source reads the same signal, so any number of observers receive
/// the same one-way request.
final class TestCancellationSource: CancellationSource, @unchecked Sendable {
    private let signal = Signal()

    func request() {
        signal.request()
    }

    var observation: any CancellationObservation {
        signal.observation
    }

    final class Signal: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false

        func request() {
            lock.lock()
            defer { lock.unlock() }
            cancelled = true
        }

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }

        var observation: Observation {
            Observation(signal: self)
        }

        struct Observation: CancellationObservation {
            let signal: Signal
            var isCancelled: Bool { signal.isCancelled }
        }
    }
}

/// A cooperative flow that checks the observation at each safe point.
///
/// Returns the cancelled outcome when cancellation is requested, the failed
/// outcome when the step `failAtStep` is reached, and `nil` when the flow
/// completes without stopping.
private func performFlow(
    steps: Int,
    failAtStep: Int? = nil,
    observation: any CancellationObservation
) -> CancelledOutcome? {
    for step in 0..<steps {
        if observation.isCancelled {
            return .cancelled
        }
        if step == failAtStep {
            return .failed
        }
    }
    return nil
}

/// A flow that never checks the observation and is therefore never
/// interrupted.
private func runBlind(steps: Int, failAtStep: Int? = nil) -> CancelledOutcome? {
    for step in 0..<steps {
        if step == failAtStep {
            return .failed
        }
    }
    return nil
}

final class CancellationTests: XCTestCase {

    // MARK: Initial non-cancelled state

    func testInitialState_ObservationReportsNotCancelledBeforeRequest() {
        let source = TestCancellationSource()
        XCTAssertFalse(source.observation.isCancelled)
    }

    // MARK: Cancellation propagation

    func testPropagation_RequestMakesObservationReportCancelled() {
        let source = TestCancellationSource()
        let observation = source.observation
        source.request()
        XCTAssertTrue(observation.isCancelled)
    }

    func testPropagation_RequestIsObservedRepeatedlyWithoutTiming() {
        let source = TestCancellationSource()
        let observation = source.observation
        source.request()
        for _ in 0..<100 {
            XCTAssertTrue(observation.isCancelled)
        }
    }

    // MARK: Idempotent cancellation

    func testIdempotency_RepeatedRequestsLeaveObservationCancelled() {
        let source = TestCancellationSource()
        let observation = source.observation
        source.request()
        source.request()
        source.request()
        XCTAssertTrue(observation.isCancelled)
    }

    func testOneWay_RequestIsNeverRevokedAndReachesLaterObservations() {
        let source = TestCancellationSource()
        source.request()
        XCTAssertTrue(source.observation.isCancelled)
    }

    // MARK: Observation of cancellation

    func testMultipleObservers_AllReceiveTheSameSignal() {
        let source = TestCancellationSource()
        let observations = (0..<20).map { _ in source.observation }
        XCTAssertTrue(observations.allSatisfy { !$0.isCancelled })
        source.request()
        XCTAssertTrue(observations.allSatisfy { $0.isCancelled })
    }

    // MARK: Cooperative stop

    func testCooperative_FlowStopsAtItsSafePointWhenCancelled() {
        let source = TestCancellationSource()
        let observation = source.observation
        source.request()
        XCTAssertEqual(performFlow(steps: 10, observation: observation), .cancelled)
    }

    func testCooperative_FlowThatNeverChecksIsNotInterrupted() {
        let source = TestCancellationSource()
        source.request()
        XCTAssertEqual(runBlind(steps: 10), nil)
    }

    // MARK: Deterministic behaviour

    func testDeterministic_RequestThenCheckAlwaysReportsCancelled() {
        let source = TestCancellationSource()
        let observation = source.observation
        source.request()
        XCTAssertTrue(observation.isCancelled)
        XCTAssertTrue(observation.isCancelled)
    }

    // MARK: Cancellation distinct from failure

    func testDistinctOutcomes_CancelledFlowIsNeverReportedAsFailure() {
        let source = TestCancellationSource()
        let observation = source.observation
        source.request()
        XCTAssertEqual(performFlow(steps: 10, observation: observation), .cancelled)
        XCTAssertNotEqual(performFlow(steps: 10, observation: observation), .failed)
    }

    func testDistinctOutcomes_FailedFlowIsNeverReportedAsCancelled() {
        let source = TestCancellationSource()
        let observation = source.observation
        XCTAssertEqual(performFlow(steps: 10, failAtStep: 3, observation: observation), .failed)
        XCTAssertNotEqual(performFlow(steps: 10, failAtStep: 3, observation: observation), .cancelled)
    }

    func testDistinctOutcomes_UncheckedFailureIsNeverReportedAsCancelled() {
        let source = TestCancellationSource()
        source.request()
        XCTAssertEqual(runBlind(steps: 10, failAtStep: 3), .failed)
    }

    func testDistinctOutcomes_OutcomesAreNeverConflated() {
        XCTAssertNotEqual(CancelledOutcome.cancelled, CancelledOutcome.failed)
    }

    // MARK: Concurrent cancellation

    func testConcurrent_SharedObservationReadsConsistently() async {
        let source = TestCancellationSource()
        let observation = source.observation
        let reads: [Bool] = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<100 {
                group.addTask { observation.isCancelled }
            }
            var collected: [Bool] = []
            for await read in group {
                collected.append(read)
            }
            return collected
        }
        XCTAssertEqual(reads.count, 100)
        XCTAssertTrue(reads.allSatisfy { !$0 })
    }

    func testConcurrent_RequestIsObservedByEveryObserver() async {
        let source = TestCancellationSource()
        let observations = (0..<20).map { _ in source.observation }
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { source.request() }
            }
            await group.waitForAll()
        }
        XCTAssertTrue(observations.allSatisfy { $0.isCancelled })
    }

    // MARK: Infrastructure independence

    func testInfrastructureIndependence_ObservationIsSynchronous() {
        let source = TestCancellationSource()
        let observation = source.observation
        source.request()
        XCTAssertTrue(observation.isCancelled)
    }

    // MARK: Injection into consumers

    func testInjection_ConsumerReceivesObservationByComposition() {
        let source = TestCancellationSource()
        let observation = source.observation
        XCTAssertEqual(performFlow(steps: 5, observation: observation), nil)
        source.request()
        XCTAssertEqual(performFlow(steps: 5, observation: observation), .cancelled)
    }
}
