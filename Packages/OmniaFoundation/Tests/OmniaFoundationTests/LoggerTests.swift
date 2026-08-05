import Foundation
import XCTest
@testable import OmniaFoundation

/// A recording logger double that captures every delivered event.
final class RecordingLogger: Logger, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [LogEvent] = []

    func log(_ event: LogEvent) {
        lock.lock()
        defer { lock.unlock() }
        stored.append(event)
    }

    var recorded: [LogEvent] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

/// A minimal consumer that records diagnostics through an injected logger.
private struct Consumer {
    let logger: Logger

    func record(_ event: LogEvent) {
        logger.log(event)
    }
}

final class LoggerTests: XCTestCase {
    private let clock = TestClock(startingAt: .seconds(1_000))
    private let context = LogContext("tests")

    private func event(
        level: LogLevel = .info,
        message: String = "message",
        metadata: LogMetadata = LogMetadata()
    ) -> LogEvent {
        LogEvent(
            level: level,
            message: message,
            metadata: metadata,
            timestamp: clock.now(),
            context: context
        )
    }

    // MARK: Level propagation

    func testLevel_IsDeliveredUnchanged() {
        let logger = RecordingLogger()
        logger.log(event(level: .warning))
        XCTAssertEqual(logger.recorded.first?.level, .warning)
    }

    func testLevel_OrdersDeterministically() {
        let ordered: [LogLevel] = [.trace, .debug, .info, .notice, .warning, .error, .critical]
        for pair in zip(ordered, ordered.dropFirst()) {
            XCTAssertLessThan(pair.0, pair.1)
        }
        XCTAssertEqual(LogLevel.info, LogLevel.info)
        XCTAssertNotEqual(LogLevel.info, LogLevel.error)
    }

    func testLevel_FixedSetIsDomainAgnostic() {
        XCTAssertEqual(LogLevel.allCases.count, 7)
    }

    // MARK: Metadata propagation

    func testMetadata_IsDeliveredAndPreserved() throws {
        let logger = RecordingLogger()
        let metadata = LogMetadata(["request_id": "abc-123", "attempt": "3"])
        logger.log(event(metadata: metadata))
        let recorded = try XCTUnwrap(logger.recorded.first)
        XCTAssertEqual(recorded.metadata, metadata)
        XCTAssertEqual(recorded.metadata.count, 2)
        XCTAssertEqual(recorded.metadata["request_id"], "abc-123")
        XCTAssertEqual(recorded.metadata["attempt"], "3")
    }

    func testMetadata_IsOptionalAndEmptyByDefault() throws {
        let logger = RecordingLogger()
        logger.log(event())
        XCTAssertEqual(try XCTUnwrap(logger.recorded.first).metadata.count, 0)
    }

    // MARK: Deterministic timestamps

    func testTimestamp_ComesFromInjectedClock() throws {
        let logger = RecordingLogger()
        let expected = clock.now()
        logger.log(event())
        XCTAssertEqual(try XCTUnwrap(logger.recorded.first).timestamp, expected)
    }

    func testTimestamp_IsExactAndReproducible() {
        let logger = RecordingLogger()
        clock.set(to: Instant(offset: .seconds(5_000)))
        logger.log(event())
        logger.log(event())
        let expected = [Instant(offset: .seconds(5_000)), Instant(offset: .seconds(5_000))]
        XCTAssertEqual(logger.recorded.map(\.timestamp), expected)
    }

    // MARK: Context propagation

    func testContext_IsDeliveredUnchanged() {
        let logger = RecordingLogger()
        logger.log(event(message: "signed in", metadata: LogMetadata(["user": "42"])))
        XCTAssertEqual(logger.recorded.first?.context, context)
        XCTAssertEqual(logger.recorded.first?.context.name, "tests")
        XCTAssertNotEqual(logger.recorded.first?.context, LogContext("authentication"))
    }

    // MARK: Concurrent use

    func testConcurrentUse_RecordsWithoutLossOrDuplication() async {
        let logger = RecordingLogger()
        let clock = self.clock
        let context = self.context
        let count = 100
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<count {
                group.addTask {
                    logger.log(LogEvent(
                        level: .debug,
                        message: "task-\(index)",
                        timestamp: clock.now(),
                        context: context
                    ))
                }
            }
            await group.waitForAll()
        }
        let recorded = logger.recorded
        XCTAssertEqual(recorded.count, count)
        XCTAssertEqual(Set(recorded.map(\.message)), Set((0..<count).map { "task-\($0)" }))
    }

    func testConcurrentUse_RecordsEventsIntact() async {
        let logger = RecordingLogger()
        let clock = self.clock
        let context = self.context
        let expectedTimestamp = clock.now()
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask {
                    logger.log(LogEvent(
                        level: .info,
                        message: "event-\(index)",
                        metadata: LogMetadata(["index": "\(index)"]),
                        timestamp: expectedTimestamp,
                        context: context
                    ))
                }
            }
            await group.waitForAll()
        }
        let recorded = logger.recorded
        XCTAssertEqual(recorded.count, 20)
        XCTAssertTrue(recorded.allSatisfy { $0.context == context })
        XCTAssertTrue(recorded.allSatisfy { $0.timestamp == expectedTimestamp })
        XCTAssertTrue(recorded.allSatisfy { $0.metadata.count == 1 })
    }

    // MARK: Structured event preservation

    func testEvent_PreservesFullStructure() throws {
        let logger = RecordingLogger()
        let metadata = LogMetadata(["key": "value"])
        let expected = LogEvent(
            level: .error,
            message: "boom",
            metadata: metadata,
            timestamp: clock.now(),
            context: LogContext("domain")
        )
        logger.log(expected)
        let recorded = try XCTUnwrap(logger.recorded.first)
        XCTAssertEqual(recorded, expected)
        XCTAssertEqual(recorded.level, .error)
        XCTAssertEqual(recorded.message, "boom")
        XCTAssertEqual(recorded.metadata, metadata)
        XCTAssertEqual(recorded.timestamp, expected.timestamp)
        XCTAssertEqual(recorded.context, LogContext("domain"))
    }

    func testEvent_IsAValue() {
        let first = event()
        let second = event()
        XCTAssertEqual(first, second)
        var copy = first
        copy = LogEvent(level: .critical, message: "changed", timestamp: first.timestamp, context: first.context)
        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, copy)
    }

    // MARK: Sensitive value redaction

    func testRedaction_DescriptionRevealsNothing() {
        let token = Sensitive("super-secret-token")
        XCTAssertEqual("\(token)", "<redacted>")
        XCTAssertFalse("\(token)".contains("super-secret-token"))
    }

    func testRedaction_DebugDescriptionRevealsNothing() {
        let token = Sensitive("super-secret-token")
        XCTAssertEqual(String(reflecting: token), "<redacted>")
        XCTAssertFalse(String(reflecting: token).contains("super-secret-token"))
    }

    func testRedaction_InterpolationRevealsNothing() {
        let content = Sensitive("conversation-content")
        let interpolated = "event: \(content)"
        XCTAssertEqual(interpolated, "event: <redacted>")
        XCTAssertFalse(interpolated.contains("conversation-content"))
    }

    func testRedaction_RedactionIsDeterministicAcrossValues() {
        XCTAssertEqual("\(Sensitive("a"))", "\(Sensitive("b"))")
    }

    // MARK: Injection

    func testInjection_ConsumerLogsThroughInjectedLogger() {
        let logger = RecordingLogger()
        let consumer = Consumer(logger: logger)
        consumer.record(event())
        XCTAssertEqual(logger.recorded.count, 1)
        XCTAssertEqual(logger.recorded.first?.level, .info)
    }
}
