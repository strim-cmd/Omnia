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

    func testFailure_UnexpectedErrorIsNeverSilent() {
        let state = ConversationScreenState(
            messages: [presentation("Partial reply")],
            failure: .unexpected
        )
        XCTAssertEqual(state.failure, .unexpected)
        XCTAssertTrue(state.hasError)
        XCTAssertEqual(state.messages, [presentation("Partial reply")])
    }

    func testFailure_DistinctFailuresAreNotEqual() {
        let unexpected = ConversationScreenState(messages: [], failure: .unexpected)
        XCTAssertNotEqual(
            unexpected.failure,
            ConversationScreenState(messages: [], failure: .capability(.invalidResponse)).failure
        )
        XCTAssertNotEqual(unexpected, ConversationScreenState(messages: []))
    }

    // MARK: Draft rehydration (UX audit U4)

    func testReplacingDraft_UpdatesDraftAndPreservesContent() {
        let state = ConversationScreenState(
            messages: [presentation("Reply")],
            streamingCondition: .active(partialContent: "Part"),
            failure: .capability(.invalidResponse)
        )
        let replaced = state.replacingDraft("In progress")
        XCTAssertEqual(replaced.draft, "In progress")
        XCTAssertEqual(replaced.messages, [presentation("Reply")])
        XCTAssertEqual(replaced.streamingCondition, .active(partialContent: "Part"))
        XCTAssertEqual(replaced.failure, .capability(.invalidResponse))
        XCTAssertEqual(state.draft, "")
    }

    func testReplacingDraft_EmptyDraftClearsPrevious() {
        let state = ConversationScreenState(messages: [], draft: "Draft")
        let replaced = state.replacingDraft("")
        XCTAssertEqual(replaced.draft, "")
        XCTAssertEqual(replaced.messages, [])
    }

    // MARK: Streaming condition transition (UX audit A4)

    func testReplacingStreamingCondition_ActiveToInterruptedPreservesContent() {
        let state = ConversationScreenState(
            messages: [presentation("Reply")],
            draft: "In progress",
            streamingCondition: .active(partialContent: "Partial"),
            failure: .capability(.invalidResponse)
        )
        let replaced = state.replacingStreamingCondition(.interrupted(partialContent: "Partial"))
        XCTAssertEqual(replaced.streamingCondition, .interrupted(partialContent: "Partial"))
        XCTAssertEqual(replaced.messages, [presentation("Reply")])
        XCTAssertEqual(replaced.draft, "In progress")
        XCTAssertEqual(replaced.failure, .capability(.invalidResponse))
        XCTAssertEqual(state.streamingCondition, .active(partialContent: "Partial"))
    }

    func testReplacingStreamingCondition_ToActive() {
        let state = ConversationScreenState(
            messages: [],
            streamingCondition: .interrupted(partialContent: "Partial")
        )
        let replaced = state.replacingStreamingCondition(.active(partialContent: "Partial"))
        XCTAssertEqual(replaced.streamingCondition, .active(partialContent: "Partial"))
    }

    func testReplacingStreamingCondition_ClearsCondition() {
        let state = ConversationScreenState(
            messages: [presentation("Reply")],
            streamingCondition: .active(partialContent: "Partial")
        )
        let replaced = state.replacingStreamingCondition(nil)
        XCTAssertNil(replaced.streamingCondition)
        XCTAssertEqual(replaced.messages, [presentation("Reply")])
    }

    // MARK: Provider selection (UX audit V2)

    func testProviderSelection_DefaultsToNil() {
        let state = ConversationScreenState(messages: [])
        XCTAssertNil(state.providerSelection)
    }

    func testReplacingProviderSelection_UpdatesSelectionAndPreservesContent() {
        let item = ProviderConnectionListItem(identity: ProviderIdentity(), displayName: "Alpha", state: .ready)
        let selection = ConversationScreenState.ProviderSelection(providers: [item], selected: nil)
        let state = ConversationScreenState(
            messages: [presentation("Reply")],
            draft: "In progress",
            streamingCondition: .active(partialContent: "Part"),
            failure: .capability(.invalidResponse)
        )
        let replaced = state.replacingProviderSelection(selection)
        XCTAssertEqual(replaced.providerSelection, selection)
        XCTAssertEqual(replaced.messages, [presentation("Reply")])
        XCTAssertEqual(replaced.draft, "In progress")
        XCTAssertEqual(replaced.streamingCondition, .active(partialContent: "Part"))
        XCTAssertEqual(replaced.failure, .capability(.invalidResponse))
        XCTAssertNil(state.providerSelection)
    }

    func testReplacingProviderSelection_ClearsSelection() {
        let item = ProviderConnectionListItem(identity: ProviderIdentity(), displayName: "Alpha", state: .ready)
        let state = ConversationScreenState(
            messages: [],
            providerSelection: .init(providers: [item])
        )
        XCTAssertNil(state.replacingProviderSelection(nil).providerSelection)
    }

    func testReplacingDraft_PreservesProviderSelection() {
        let item = ProviderConnectionListItem(identity: ProviderIdentity(), displayName: "Alpha", state: .ready)
        let selection = ConversationScreenState.ProviderSelection(providers: [item])
        let state = ConversationScreenState(messages: [], providerSelection: selection)
        XCTAssertEqual(state.replacingDraft("Draft").providerSelection, selection)
    }

    func testReplacingStreamingCondition_PreservesProviderSelection() {
        let item = ProviderConnectionListItem(identity: ProviderIdentity(), displayName: "Alpha", state: .ready)
        let selection = ConversationScreenState.ProviderSelection(providers: [item])
        let state = ConversationScreenState(messages: [], providerSelection: selection)
        XCTAssertEqual(
            state.replacingStreamingCondition(.active(partialContent: "Part")).providerSelection,
            selection
        )
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

    func testEquality_DifferentProviderSelectionIsNotEqual() {
        let item = ProviderConnectionListItem(identity: ProviderIdentity(), displayName: "Alpha", state: .ready)
        let a = ConversationScreenState(messages: [], providerSelection: .init(providers: [item]))
        XCTAssertNotEqual(a, ConversationScreenState(messages: []))
    }
}
