import Foundation
import OmniaApplication
import XCTest
@testable import OmniaPresentation

private struct GenerationEvent: Sendable {
    let conversation: ConversationIdentity
    let state: ConversationScreenState
}

private final class GenerationEventProbe: @unchecked Sendable {
    let events: AsyncStream<GenerationEvent>
    private let continuation: AsyncStream<GenerationEvent>.Continuation

    init() {
        let pair = AsyncStream<GenerationEvent>.makeStream()
        events = pair.stream
        continuation = pair.continuation
    }

    func record(_ conversation: ConversationIdentity, _ state: ConversationScreenState) {
        continuation.yield(GenerationEvent(conversation: conversation, state: state))
    }
}

private final class CancellationProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var cancellationCount = 0
    private var waiters: [Int: [CheckedContinuation<Void, Never>]] = [:]

    func record(
        _ termination: AsyncThrowingStream<ConversationScreenState, any Error>.Continuation.Termination
    ) {
        guard case .cancelled = termination else { return }
        let satisfied = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
            cancellationCount += 1
            let current = cancellationCount
            var satisfied: [CheckedContinuation<Void, Never>] = []
            for target in waiters.keys.filter({ $0 <= current }) {
                satisfied += waiters.removeValue(forKey: target) ?? []
            }
            return satisfied
        }
        for continuation in satisfied {
            continuation.resume()
        }
    }

    var count: Int {
        lock.withLock { cancellationCount }
    }

    /// Awaits until at least `target` `.cancelled` terminations have been
    /// recorded. `discard`/`cancel` await the worker task (`Task.value`), but
    /// the stream's `onTermination(.cancelled)` can still be in flight when
    /// they return, so a bare `count` read is nondeterministic. This resumes
    /// immediately when the target is already satisfied.
    func waitForCancellations(_ target: Int) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let resumeNow = lock.withLock { () -> Bool in
                if cancellationCount >= target {
                    return true
                }
                waiters[target, default: []].append(continuation)
                return false
            }
            if resumeNow {
                continuation.resume()
            }
        }
    }
}

private final class InvocationProbe: @unchecked Sendable {
    let invocations: AsyncStream<Int>
    private let continuation: AsyncStream<Int>.Continuation
    private let lock = NSLock()
    private var invocationCount = 0

    init() {
        let pair = AsyncStream<Int>.makeStream()
        invocations = pair.stream
        continuation = pair.continuation
    }

    func record() {
        let count = lock.withLock {
            invocationCount += 1
            return invocationCount
        }
        continuation.yield(count)
    }

    var count: Int {
        lock.withLock { invocationCount }
    }
}

private final class ControlledGeneration: @unchecked Sendable {
    let stream: AsyncThrowingStream<ConversationScreenState, any Error>
    private let continuation: AsyncThrowingStream<ConversationScreenState, any Error>.Continuation
    let cancellations = CancellationProbe()

    init() {
        let pair = AsyncThrowingStream<ConversationScreenState, any Error>.makeStream()
        stream = pair.stream
        continuation = pair.continuation
        let cancellations = cancellations
        continuation.onTermination = { termination in
            cancellations.record(termination)
        }
    }

    func yield(_ state: ConversationScreenState) {
        continuation.yield(state)
    }

    func finish() {
        continuation.finish()
    }
}

private func generationState(
    _ partial: String,
    messages: [MessagePresentation] = []
) -> ConversationScreenState {
    ConversationScreenState(
        messages: messages,
        streamingCondition: .active(partialContent: partial)
    )
}

private func completedState(
    _ content: String,
    messages: [MessagePresentation] = []
) -> ConversationScreenState {
    ConversationScreenState(
        messages: messages + [
            MessagePresentation(message: Message(role: .assistant, content: content)),
        ],
        streamingCondition: .complete
    )
}

private func nextEvent(
    from iterator: inout AsyncStream<GenerationEvent>.Iterator
) async throws -> GenerationEvent {
    let event = await iterator.next()
    return try XCTUnwrap(event)
}

final class ConversationGenerationCoordinatorTests: XCTestCase {
    private let events = GenerationEventProbe()
    private lazy var observer: ConversationGenerationCoordinator.StateObserver = {
        [events] conversation, state in
            events.record(conversation, state)
        }

    func testGeneratingA_LoadingBDoesNotCancelA() async throws {
        let coordinator = ConversationGenerationCoordinator()
        let conversationA = ConversationIdentity()
        let conversationB = ConversationIdentity()
        let sourceA = ControlledGeneration()
        var iterator = events.events.makeAsyncIterator()

        let started = await coordinator.start(
            for: conversationA,
            initialState: generationState(""),
            makeStream: { sourceA.stream },
            observer: observer
        )
        XCTAssertNotNil(started)
        _ = try await nextEvent(from: &iterator)

        _ = await coordinator.state(
            for: conversationB,
            loading: ConversationScreenState(messages: [])
        )

        let isGeneratingA = await coordinator.isGenerating(conversationA)
        XCTAssertTrue(isGeneratingA)
        XCTAssertEqual(sourceA.cancellations.count, 0)
        sourceA.finish()
    }

    func testReturningToA_PreservesPartialAndFinalState() async throws {
        let coordinator = ConversationGenerationCoordinator()
        let conversationA = ConversationIdentity()
        let sourceA = ControlledGeneration()
        var iterator = events.events.makeAsyncIterator()

        _ = await coordinator.start(
            for: conversationA,
            initialState: generationState(""),
            makeStream: { sourceA.stream },
            observer: observer
        )
        _ = try await nextEvent(from: &iterator)

        let partial = generationState("Partial")
        sourceA.yield(partial)
        _ = try await nextEvent(from: &iterator)
        let returnedPartial = await coordinator.state(
            for: conversationA,
            loading: ConversationScreenState(messages: [])
        )
        XCTAssertEqual(returnedPartial, partial)

        let final = completedState("Partial")
        sourceA.yield(final)
        _ = try await nextEvent(from: &iterator)
        let returnedFinal = await coordinator.state(
            for: conversationA,
            loading: ConversationScreenState(messages: [])
        )
        XCTAssertEqual(returnedFinal, final)
        let isGeneratingA = await coordinator.isGenerating(conversationA)
        XCTAssertFalse(isGeneratingA)
        sourceA.finish()
    }

    func testAChunksNeverUpdateB() async throws {
        let coordinator = ConversationGenerationCoordinator()
        let conversationA = ConversationIdentity()
        let conversationB = ConversationIdentity()
        let sourceA = ControlledGeneration()
        let stateB = generationState("B")
        var iterator = events.events.makeAsyncIterator()

        _ = await coordinator.state(for: conversationB, loading: stateB)
        _ = await coordinator.start(
            for: conversationA,
            initialState: generationState(""),
            makeStream: { sourceA.stream },
            observer: observer
        )
        _ = try await nextEvent(from: &iterator)
        sourceA.yield(generationState("A-only"))
        let event = try await nextEvent(from: &iterator)

        XCTAssertEqual(event.conversation, conversationA)
        let returnedB = await coordinator.state(
            for: conversationB,
            loading: .init(messages: [])
        )
        XCTAssertEqual(returnedB, stateB)
        sourceA.finish()
    }

    func testExplicitStopCancelsOnlyRequestedConversation() async throws {
        let coordinator = ConversationGenerationCoordinator()
        let conversationA = ConversationIdentity()
        let conversationB = ConversationIdentity()
        let sourceA = ControlledGeneration()
        let sourceB = ControlledGeneration()
        var iterator = events.events.makeAsyncIterator()

        _ = await coordinator.start(
            for: conversationA,
            initialState: generationState("A"),
            makeStream: { sourceA.stream },
            observer: observer
        )
        _ = try await nextEvent(from: &iterator)
        _ = await coordinator.start(
            for: conversationB,
            initialState: generationState("B"),
            makeStream: { sourceB.stream },
            observer: observer
        )
        _ = try await nextEvent(from: &iterator)

        let didCancelA = await coordinator.cancel(conversationA)
        XCTAssertTrue(didCancelA)
        let interrupted = try await nextEvent(from: &iterator)

        XCTAssertEqual(interrupted.conversation, conversationA)
        XCTAssertEqual(
            interrupted.state.streamingCondition,
            .interrupted(partialContent: "A")
        )
        let isGeneratingA = await coordinator.isGenerating(conversationA)
        let isGeneratingB = await coordinator.isGenerating(conversationB)
        XCTAssertFalse(isGeneratingA)
        XCTAssertTrue(isGeneratingB)
        await sourceA.cancellations.waitForCancellations(1)
        XCTAssertEqual(sourceA.cancellations.count, 1)
        XCTAssertEqual(sourceB.cancellations.count, 0)
        sourceB.finish()
    }

    func testNavigationAndInactiveStateAccessDoNotRequestCancellation() async throws {
        let coordinator = ConversationGenerationCoordinator()
        let conversationA = ConversationIdentity()
        let sourceA = ControlledGeneration()
        var iterator = events.events.makeAsyncIterator()

        _ = await coordinator.start(
            for: conversationA,
            initialState: generationState(""),
            makeStream: { sourceA.stream },
            observer: observer
        )
        _ = try await nextEvent(from: &iterator)

        for _ in 0..<3 {
            _ = await coordinator.state(
                for: ConversationIdentity(),
                loading: ConversationScreenState(messages: [])
            )
        }

        sourceA.yield(generationState("still running"))
        let event = try await nextEvent(from: &iterator)
        XCTAssertEqual(event.state.streamingCondition, .active(partialContent: "still running"))
        let isGeneratingA = await coordinator.isGenerating(conversationA)
        XCTAssertTrue(isGeneratingA)
        XCTAssertEqual(sourceA.cancellations.count, 0)
        sourceA.finish()
    }

    func testRevisitingDoesNotDuplicateGeneration() async throws {
        let coordinator = ConversationGenerationCoordinator()
        let conversation = ConversationIdentity()
        let source = ControlledGeneration()
        let invocations = InvocationProbe()
        var iterator = events.events.makeAsyncIterator()
        var invocationIterator = invocations.invocations.makeAsyncIterator()
        let factory: ConversationGenerationCoordinator.StreamFactory = {
            invocations.record()
            return source.stream
        }

        let first = await coordinator.start(
            for: conversation,
            initialState: generationState(""),
            makeStream: factory,
            observer: observer
        )
        XCTAssertNotNil(first)
        _ = try await nextEvent(from: &iterator)
        let firstInvocation = await invocationIterator.next()
        XCTAssertEqual(firstInvocation, 1)
        let second = await coordinator.start(
            for: conversation,
            initialState: generationState("duplicate"),
            makeStream: factory,
            observer: observer
        )

        XCTAssertNil(second)
        XCTAssertEqual(invocations.count, 1)
        source.finish()
    }

    func testLateChunksAfterCancellationAreIgnored() async throws {
        let coordinator = ConversationGenerationCoordinator()
        let conversation = ConversationIdentity()
        let oldSource = ControlledGeneration()
        let newSource = ControlledGeneration()
        var iterator = events.events.makeAsyncIterator()

        _ = await coordinator.start(
            for: conversation,
            initialState: generationState("old"),
            makeStream: { oldSource.stream },
            observer: observer
        )
        _ = try await nextEvent(from: &iterator)
        let didCancel = await coordinator.cancel(conversation)
        XCTAssertTrue(didCancel)
        _ = try await nextEvent(from: &iterator)

        _ = await coordinator.start(
            for: conversation,
            initialState: generationState("new"),
            makeStream: { newSource.stream },
            observer: observer
        )
        _ = try await nextEvent(from: &iterator)
        oldSource.yield(generationState("late old chunk"))
        newSource.yield(generationState("new chunk"))
        _ = try await nextEvent(from: &iterator)

        let returned = await coordinator.state(
            for: conversation,
            loading: .init(messages: [])
        )
        XCTAssertEqual(returned, generationState("new chunk"))
        newSource.finish()
    }

    func testRapidABAUpdatesRemainIsolated() async throws {
        let coordinator = ConversationGenerationCoordinator()
        let conversationA = ConversationIdentity()
        let conversationB = ConversationIdentity()
        let sourceA = ControlledGeneration()
        let sourceB = ControlledGeneration()
        var iterator = events.events.makeAsyncIterator()

        _ = await coordinator.start(
            for: conversationA,
            initialState: generationState("A0"),
            makeStream: { sourceA.stream },
            observer: observer
        )
        _ = try await nextEvent(from: &iterator)
        _ = await coordinator.start(
            for: conversationB,
            initialState: generationState("B0"),
            makeStream: { sourceB.stream },
            observer: observer
        )
        _ = try await nextEvent(from: &iterator)

        sourceA.yield(generationState("A1"))
        _ = try await nextEvent(from: &iterator)
        sourceB.yield(generationState("B1"))
        _ = try await nextEvent(from: &iterator)
        sourceA.yield(generationState("A2"))
        _ = try await nextEvent(from: &iterator)

        let returnedA = await coordinator.state(
            for: conversationA,
            loading: .init(messages: [])
        )
        let returnedB = await coordinator.state(
            for: conversationB,
            loading: .init(messages: [])
        )
        XCTAssertEqual(returnedA, generationState("A2"))
        XCTAssertEqual(returnedB, generationState("B1"))
        let isGeneratingA = await coordinator.isGenerating(conversationA)
        let isGeneratingB = await coordinator.isGenerating(conversationB)
        XCTAssertTrue(isGeneratingA)
        XCTAssertTrue(isGeneratingB)
        sourceA.finish()
        sourceB.finish()
    }

    func testDiscardAll_AwaitsAndForgetsEveryActiveConversation() async throws {
        let coordinator = ConversationGenerationCoordinator()
        let conversationA = ConversationIdentity()
        let conversationB = ConversationIdentity()
        let sourceA = ControlledGeneration()
        let sourceB = ControlledGeneration()
        var iterator = events.events.makeAsyncIterator()

        _ = await coordinator.start(
            for: conversationA,
            initialState: generationState("A"),
            makeStream: { sourceA.stream },
            observer: observer
        )
        _ = try await nextEvent(from: &iterator)
        _ = await coordinator.start(
            for: conversationB,
            initialState: generationState("B"),
            makeStream: { sourceB.stream },
            observer: observer
        )
        _ = try await nextEvent(from: &iterator)

        await coordinator.discardAll()

        let generatingA = await coordinator.isGenerating(conversationA)
        let generatingB = await coordinator.isGenerating(conversationB)
        XCTAssertFalse(generatingA)
        XCTAssertFalse(generatingB)
        await sourceA.cancellations.waitForCancellations(1)
        await sourceB.cancellations.waitForCancellations(1)
        XCTAssertEqual(sourceA.cancellations.count, 1)
        XCTAssertEqual(sourceB.cancellations.count, 1)
    }
}
