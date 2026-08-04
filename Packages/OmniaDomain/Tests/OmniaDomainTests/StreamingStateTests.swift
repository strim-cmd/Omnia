import XCTest
@testable import OmniaDomain

final class StreamingStateTests: XCTestCase {

    // MARK: Creation

    func testCreation_StartsActiveWithEmptyContent() {
        let state = StreamingState.active(partialContent: "")
        XCTAssertFalse(state.isTerminal)
        XCTAssertEqual(state.partialContent, "")
    }

    // MARK: active → active

    func testAppending_GrowsAccumulatedContent() throws {
        var state = StreamingState.active(partialContent: "")
        state = try state.appending("Hello")
        state = try state.appending(" world")
        XCTAssertEqual(state.partialContent, "Hello world")
    }

    func testAppending_PreservesPriorContent() throws {
        let state = StreamingState.active(partialContent: "Hello")
        let appended = try state.appending(" world")
        XCTAssertEqual(appended.partialContent, "Hello world")
    }

    func testAppending_EmptyDeltaKeepsContent() throws {
        let state = StreamingState.active(partialContent: "Hello")
        let appended = try state.appending("")
        XCTAssertEqual(appended.partialContent, "Hello")
    }

    func testAppending_NeverResetsAccumulatedContent() throws {
        let state = StreamingState.active(partialContent: "A")
        let appended = try state.appending("B")
        XCTAssertEqual(appended, .active(partialContent: "AB"))
    }

    // MARK: active → complete

    func testCompleting_ProducesTerminalCompleteCarryingAssembledAssistantMessage() throws {
        let state = try StreamingState.active(partialContent: "Hello")
            .appending(" world")
            .completing()
        XCTAssertTrue(state.isTerminal)
        guard case .complete(let message) = state else {
            return XCTFail("Expected a completion")
        }
        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "Hello world")
    }

    func testCompleting_EmptyStreamCompletesWithEmptyAssistantMessage() throws {
        let state = try StreamingState.active(partialContent: "").completing()
        guard case .complete(let message) = state else {
            return XCTFail("Expected a completion")
        }
        XCTAssertEqual(message.content, "")
    }

    // MARK: active → interrupted

    func testInterrupting_ProducesTerminalInterruptedPreservingPartialContentAsIncomplete() throws {
        let state = try StreamingState.active(partialContent: "Hello")
            .appending(" wor")
            .interrupting()
        XCTAssertTrue(state.isTerminal)
        guard case .interrupted(let partialContent) = state else {
            return XCTFail("Expected an interruption")
        }
        XCTAssertEqual(partialContent, "Hello wor")
    }

    func testInterrupting_NeverSilentlyDiscardsPartialContent() throws {
        let state = try StreamingState.active(partialContent: "preserved").interrupting()
        XCTAssertEqual(state.partialContent, "preserved")
    }

    func testInterruption_ResumptionStartsFromPreservedPartialContent() throws {
        let interrupted = try StreamingState.active(partialContent: "")
            .appending("partial")
            .interrupting()
        guard case .interrupted(let preserved) = interrupted else {
            return XCTFail("Expected an interruption")
        }
        let resumed = StreamingState.active(partialContent: preserved)
        XCTAssertEqual(resumed.partialContent, "partial")
    }

    // MARK: Terminal states

    func testActive_IsNotTerminal() {
        XCTAssertFalse(StreamingState.active(partialContent: "").isTerminal)
    }

    func testComplete_IsTerminal() throws {
        XCTAssertTrue(try StreamingState.active(partialContent: "").completing().isTerminal)
    }

    func testInterrupted_IsTerminal() throws {
        XCTAssertTrue(try StreamingState.active(partialContent: "").interrupting().isTerminal)
    }

    func testAppending_FromCompleteThrowsNotActive() throws {
        let state = try StreamingState.active(partialContent: "").completing()
        XCTAssertThrowsError(try state.appending("more")) { error in
            XCTAssertEqual(error as? StreamingStateError, .notActive)
        }
    }

    func testAppending_FromInterruptedThrowsNotActive() throws {
        let state = try StreamingState.active(partialContent: "part").interrupting()
        XCTAssertThrowsError(try state.appending("more")) { error in
            XCTAssertEqual(error as? StreamingStateError, .notActive)
        }
    }

    func testCompleting_FromCompleteThrowsNotActive() throws {
        let state = try StreamingState.active(partialContent: "").completing()
        XCTAssertThrowsError(try state.completing()) { error in
            XCTAssertEqual(error as? StreamingStateError, .notActive)
        }
    }

    func testCompleting_FromInterruptedThrowsNotActive() throws {
        let state = try StreamingState.active(partialContent: "part").interrupting()
        XCTAssertThrowsError(try state.completing()) { error in
            XCTAssertEqual(error as? StreamingStateError, .notActive)
        }
    }

    func testInterrupting_FromCompleteThrowsNotActive() throws {
        let state = try StreamingState.active(partialContent: "").completing()
        XCTAssertThrowsError(try state.interrupting()) { error in
            XCTAssertEqual(error as? StreamingStateError, .notActive)
        }
    }

    func testInterrupting_FromInterruptedThrowsNotActive() throws {
        let state = try StreamingState.active(partialContent: "part").interrupting()
        XCTAssertThrowsError(try state.interrupting()) { error in
            XCTAssertEqual(error as? StreamingStateError, .notActive)
        }
    }

    // MARK: Partial content

    func testPartialContent_ActivePreservesReceivedContent() {
        XCTAssertEqual(StreamingState.active(partialContent: "abc").partialContent, "abc")
    }

    func testPartialContent_InterruptedPreservesReceivedContent() throws {
        let state = try StreamingState.active(partialContent: "abc").interrupting()
        XCTAssertEqual(state.partialContent, "abc")
    }

    func testPartialContent_CompleteHasNone() throws {
        let state = try StreamingState.active(partialContent: "abc").completing()
        XCTAssertNil(state.partialContent)
    }

    // MARK: Lifecycle consistency with the Conversation aggregate

    func testLifecycle_CompletionMessageAppendsToConversationHistory() throws {
        let state = try StreamingState.active(partialContent: "")
            .appending("Hello")
            .appending(" world")
            .completing()
        guard case .complete(let message) = state else {
            return XCTFail("Expected a completion")
        }

        var conversation = Conversation(identity: ConversationIdentity())
        try conversation.append(message)
        XCTAssertEqual(conversation.history.count, 1)
        XCTAssertEqual(conversation.history.last, message)
        XCTAssertEqual(conversation.history.last?.role, .assistant)
    }

    // MARK: Equality

    func testEquality_DependsOnStateAndContent() throws {
        XCTAssertEqual(
            StreamingState.active(partialContent: "abc"),
            StreamingState.active(partialContent: "abc")
        )
        XCTAssertNotEqual(
            StreamingState.active(partialContent: "abc"),
            StreamingState.active(partialContent: "ab")
        )
        XCTAssertNotEqual(
            StreamingState.active(partialContent: "abc"),
            StreamingState.interrupted(partialContent: "abc")
        )
        XCTAssertEqual(
            StreamingState.complete(message: Message(role: .assistant, content: "abc")),
            StreamingState.complete(message: Message(role: .assistant, content: "abc"))
        )
        XCTAssertNotEqual(
            StreamingState.complete(message: Message(role: .assistant, content: "abc")),
            StreamingState.interrupted(partialContent: "abc")
        )
    }

    // MARK: Sendability

    func testSendability_ShareAcrossConcurrencyDomain() async throws {
        let state = try StreamingState.active(partialContent: "Hello").interrupting()
        let returned = await Task.detached {
            state
        }.value
        XCTAssertEqual(returned, state)
    }
}
