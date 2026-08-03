import Foundation
import XCTest
@testable import OmniaFoundation

/// A controllable clock double for deterministic tests.
///
/// The clock keeps two independent domains: the current time (wall-clock
/// position, adjustable) and the measured elapsed time (monotonic position,
/// never affected by adjustments to the current time).
final class TestClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Duration
    private var elapsed: Duration

    init(startingAt start: Duration = .zero) {
        self.current = start
        self.elapsed = .zero
    }

    func now() -> Instant {
        lock.lock()
        defer { lock.unlock() }
        return Instant(offset: current)
    }

    func measure<Result>(_ body: () async throws -> Result) async throws -> (Result, Duration) {
        let start = readElapsed()
        let result = try await body()
        let end = readElapsed()
        return (result, end - start)
    }

    func sleep(for duration: Duration) async throws {
        guard duration > .zero else { return }
        advance(by: duration)
    }

    func sleep(until instant: Instant) async throws {
        let delta = delta(from: instant)
        guard delta > .zero else { return }
        advance(by: delta)
    }

    func advance(by duration: Duration) {
        lock.lock()
        defer { lock.unlock() }
        current += duration
        elapsed += duration
    }

    func set(to instant: Instant) {
        lock.lock()
        defer { lock.unlock() }
        current = instant.offset
    }

    private func delta(from instant: Instant) -> Duration {
        lock.lock()
        defer { lock.unlock() }
        return instant.offset - current
    }

    private func readElapsed() -> Duration {
        lock.lock()
        defer { lock.unlock() }
        return elapsed
    }
}

final class ClockTests: XCTestCase {

    // MARK: Deterministic time

    func testDeterministicTime_ControlledClockNeedsNoRealTime() {
        let clock = TestClock(startingAt: .seconds(1_000))
        XCTAssertEqual(clock.now(), Instant(offset: .seconds(1_000)))
    }

    // MARK: Manual advancement

    func testAdvance_ChangesCurrentTimeByExactAmount() {
        let clock = TestClock()
        clock.advance(by: .seconds(5))
        XCTAssertEqual(clock.now(), Instant(offset: .seconds(5)))
    }

    func testAdvance_ChangesMeasurementByExactAmount() async throws {
        let clock = TestClock()
        let (_, elapsed) = try await clock.measure {
            clock.advance(by: .seconds(5))
        }
        XCTAssertEqual(elapsed, .seconds(5))
    }

    func testAdvance_SettingToKnownInstantProducesThatInstant() {
        let clock = TestClock()
        clock.set(to: Instant(offset: .seconds(42)))
        XCTAssertEqual(clock.now(), Instant(offset: .seconds(42)))
    }

    // MARK: Sleep behaviour

    func testSleep_AdvancesTimeDeterministicallyWithoutBlocking() async throws {
        let clock = TestClock()
        try await clock.sleep(for: .seconds(7))
        XCTAssertEqual(clock.now(), Instant(offset: .seconds(7)))
    }

    func testSleep_ZeroDurationIsWellDefined() async throws {
        let clock = TestClock()
        let before = clock.now()
        try await clock.sleep(for: .zero)
        XCTAssertEqual(clock.now(), before)
    }

    func testSleep_NegativeDurationIsWellDefined() async throws {
        let clock = TestClock()
        let before = clock.now()
        try await clock.sleep(for: .seconds(-3))
        XCTAssertEqual(clock.now(), before)
    }

    func testSleep_UntilFutureInstantAdvancesToIt() async throws {
        let clock = TestClock()
        let target = clock.now().advanced(by: .seconds(10))
        try await clock.sleep(until: target)
        XCTAssertEqual(clock.now(), target)
    }

    func testSleep_UntilPastInstantCompletesImmediately() async throws {
        let clock = TestClock()
        let before = clock.now()
        let past = clock.now().advanced(by: .seconds(-5))
        try await clock.sleep(until: past)
        XCTAssertEqual(clock.now(), before)
    }

    // MARK: Elapsed measurement

    func testMeasurement_ElapsedEqualsDurationAdvancedBetweenReads() async throws {
        let clock = TestClock()
        let (_, elapsed) = try await clock.measure {
            clock.advance(by: .seconds(3))
        }
        XCTAssertEqual(elapsed, .seconds(3))
    }

    func testMeasurement_ReturnsOperationResult() async throws {
        let clock = TestClock()
        let (value, elapsed) = try await clock.measure {
            clock.advance(by: .seconds(2))
            return 42
        }
        XCTAssertEqual(value, 42)
        XCTAssertEqual(elapsed, .seconds(2))
    }

    // MARK: Measurement stability

    func testMeasurement_AdjustingCurrentTimeDoesNotChangeElapsed() async throws {
        let clock = TestClock()
        let (_, elapsed) = try await clock.measure {
            clock.advance(by: .seconds(2))
            clock.set(to: Instant(offset: .seconds(60)))
        }
        XCTAssertEqual(elapsed, .seconds(2))
    }

    // MARK: Time comparison

    func testTimeComparison_InstantsOrderDeterministically() {
        let earlier = Instant(offset: .seconds(1))
        let middle = Instant(offset: .seconds(2))
        let later = Instant(offset: .seconds(3))
        XCTAssertLessThan(earlier, middle)
        XCTAssertLessThan(middle, later)
        XCTAssertGreaterThan(later, earlier)
        XCTAssertEqual(middle, Instant(offset: .seconds(2)))
        XCTAssertNotEqual(earlier, later)
    }

    func testTimeComparison_DurationsOrderConsistently() async throws {
        let clock = TestClock()
        let (_, short) = try await clock.measure { clock.advance(by: .seconds(1)) }
        let (_, long) = try await clock.measure { clock.advance(by: .seconds(5)) }
        XCTAssertLessThan(short, long)
        XCTAssertEqual(short, .seconds(1))
        XCTAssertEqual(long, .seconds(5))
    }

    // MARK: Concurrent use

    func testConcurrentUse_SharedClockReadsConsistently() async {
        let clock = TestClock(startingAt: .seconds(100))
        let expected = clock.now()
        let reads: [Instant] = await withTaskGroup(of: Instant.self) { group in
            for _ in 0..<100 {
                group.addTask { clock.now() }
            }
            var collected: [Instant] = []
            for await read in group {
                collected.append(read)
            }
            return collected
        }
        XCTAssertEqual(reads.count, 100)
        XCTAssertTrue(reads.allSatisfy { $0 == expected })
    }

    func testConcurrentUse_ReadsIntroduceNoMutation() {
        let clock = TestClock(startingAt: .seconds(100))
        let before = clock.now()
        _ = clock.now()
        _ = clock.now()
        XCTAssertEqual(clock.now(), before)
    }

    // MARK: Value semantics

    func testValueSemantics_InstantsAreImmutableValues() {
        let clock = TestClock()
        let original = clock.now()
        var copy = original
        copy = copy.advanced(by: .seconds(5))
        XCTAssertEqual(original, clock.now())
        XCTAssertEqual(copy, Instant(offset: .seconds(5)))
        XCTAssertNotEqual(original, copy)
    }

    func testValueSemantics_DurationsAreImmutableValues() {
        let original = Duration.seconds(3)
        var copy = original
        copy += .seconds(1)
        XCTAssertEqual(original, .seconds(3))
        XCTAssertEqual(copy, .seconds(4))
    }
}
