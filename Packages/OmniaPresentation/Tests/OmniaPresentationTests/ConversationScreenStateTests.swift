import OmniaApplication
import XCTest
@testable import OmniaPresentation

final class ConversationScreenStateTests: XCTestCase {

    private func presentation(_ content: String) -> MessagePresentation {
        MessagePresentation(message: Message(role: .assistant, content: content))
    }

    // MARK: Creation

    func testCreation_ExposesHistoryAndDraft() {
        let message = presentation("Hello")
        let state = ConversationScreenState(
            messages: [message],
            draft: "Draft"
        )
        XCTAssertEqual(state.messages, [message])
        XCTAssertEqual(state.draft, "Draft")
        XCTAssertNil(state.streamingCondition)
        XCTAssertNil(state.failure)
        XCTAssertFalse(state.hasError)
    }

    func testDefaults_EmptyHistoryAndDraft() {
        let state = ConversationScreenState(messages: [])
        XCTAssertEqual(state.messages, [])
        XCTAssertEqual(state.draft, "")
        XCTAssertNil(state.streamingCondition)
    }

    // MARK: Streaming condition

    func testStreamingCondition_ActiveCarriesPartialContent() {
        let state = ConversationScreenState(
            messages: [],
            streamingCondition: .active(partialContent: "Part")
        )
        guard case .active(let partialContent) = state.streamingCondition else {
            return XCTFail("Expected an active streaming condition")
        }
        XCTAssertEqual(partialContent, "Part")
    }

    func testStreamingCondition_InterruptedPreservesPartialContent() {
        let state = ConversationScreenState(
            messages: [],
            streamingCondition: .interrupted(partialContent: "Partial reply")
        )
        guard case .interrupted(let partialContent) = state.streamingCondition else {
            return XCTFail("Expected an interrupted streaming condition")
        }
        XCTAssertEqual(partialContent, "Partial reply")
    }

    func testStreamingCondition_Complete() {
        let state = ConversationScreenState(
            messages: [presentation("Full reply")],
            streamingCondition: .complete
        )
        XCTAssertEqual(state.streamingCondition, .complete)
    }

    // MARK: Failure

    func testFailure_ApplicationValidationError() {
        let state = ConversationScreenState(
            messages: [],
            failure: .application(.invalid(reason: "empty input"))
        )
        XCTAssertEqual(
            state.failure,
            .application(.invalid(reason: "empty input"))
        )
    }

    func testFailure_CapabilityErrorCarriesPartialContent() {
        let state = ConversationScreenState(
            messages: [],
            failure: .capability(.streamingInterrupted(partialContent: "partial"))
        )
        XCTAssertEqual(
            state.failure,
            .capability(.streamingInterrupted(partialContent: "partial"))
        )
    }

    func testFailure_RepositoryAndCredentialStorageErrors() {
        let repository = ConversationScreenState(
            messages: [],
            failure: .repository(.storageUnavailable)
        )
        XCTAssertEqual(repository.failure, .repository(.storageUnavailable))
        XCTAssertTrue(repository.hasError)

        let credential = ConversationScreenState(
            messages: [],
            failure: .credentialStorage(.storageUnavailable)
        )
        XCTAssertEqual(credential.failure, .credentialStorage(.storageUnavailable))
    }

    // MARK: Equality

    func testEquality_SameContentIsEqual() {
        let a = ConversationScreenState(
            messages: [presentation("Hello")],
            draft: "Draft",
            streamingCondition: .complete
        )
        let b = ConversationScreenState(
            messages: [presentation("Hello")],
            draft: "Draft",
            streamingCondition: .complete
        )
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentDraftIsNotEqual() {
        let a = ConversationScreenState(messages: [], draft: "A")
        let b = ConversationScreenState(messages: [], draft: "B")
        XCTAssertNotEqual(a, b)
    }

    func testEquality_DifferentStreamingConditionIsNotEqual() {
        let a = ConversationScreenState(
            messages: [],
            streamingCondition: .active(partialContent: "a")
        )
        let b = ConversationScreenState(
            messages: [],
            streamingCondition: .active(partialContent: "b")
        )
        XCTAssertNotEqual(a, b)
    }
}
