import Foundation
import XCTest
@testable import OmniaDomain

// Domain Sprint 2 verification (issue #70): the test matrix of DES-009 v0.3.0.
//
// Black-box: exercises only the public API of the capability extension — the
// value objects, the typed errors, the contract methods, and the streaming
// state machine — across the matrix of DES-009 §3.3 and §3.9.
private struct UnavailableTextGeneration: TextGenerationContract {
    func generateText(from request: TextGenerationRequest) async throws -> TextGenerationResponse {
        throw CapabilityError.providerUnavailable
    }
}

private struct InterruptedStreaming: StreamingContract {
    func stream(_ request: StreamingRequest) async throws -> AsyncThrowingStream<StreamingUpdate, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.contentDelta(identity: request.identity, content: "Hello"))
            continuation.yield(.interruption(identity: request.identity, partialContent: "Hello"))
            continuation.finish()
        }
    }
}

private struct CompletingStream: StreamingContract {
    func stream(_ request: StreamingRequest) async throws -> AsyncThrowingStream<StreamingUpdate, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.contentDelta(identity: request.identity, content: "Hello"))
            continuation.yield(.completion(identity: request.identity, message: Message(role: .assistant, content: "Hello")))
            continuation.finish()
        }
    }
}

final class DomainSprint2VerificationTests: XCTestCase {

    // MARK: Capability equivalence

    func testMatrix_CapabilityValuesAreEqualByContent() {
        let identity = CapabilityRequestIdentity()
        let model = ModelReference(name: "gpt-4o")
        let history = [Message(role: .user, content: "Hello")]

        let a = ConversationRequest(identity: identity, history: history, model: model)
        let b = ConversationRequest(identity: identity, history: history, model: model)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(
            a,
            ConversationRequest(identity: identity, history: [Message(role: .user, content: "Hi")], model: model)
        )

        let response = ConversationResponse(message: Message(role: .assistant, content: "Hi!"))
        XCTAssertEqual(response, ConversationResponse(message: Message(role: .assistant, content: "Hi!")))

        let delta = StreamingUpdate.contentDelta(identity: identity, content: "Hi")
        XCTAssertEqual(delta, StreamingUpdate.contentDelta(identity: identity, content: "Hi"))
        XCTAssertNotEqual(
            delta,
            StreamingUpdate.completion(identity: identity, message: Message(role: .assistant, content: "Hi"))
        )
    }

    func testMatrix_IdentitiesAreTypedAndNeverCollideAcrossConcepts() {
        let request = CapabilityRequestIdentity()
        let provider = ProviderIdentity()
        XCTAssertNotEqual(AnyHashable(request), AnyHashable(provider))
    }

    // MARK: Streaming state transitions

    func testMatrix_StreamingStateTransitionsFollowTheFrozenMachine() throws {
        let state = try StreamingState.active(partialContent: "")
            .appending("Hello")
            .appending(" world")
        XCTAssertFalse(state.isTerminal)
        XCTAssertEqual(state.partialContent, "Hello world")

        let complete = try state.completing()
        XCTAssertTrue(complete.isTerminal)
        XCTAssertThrowsError(try complete.appending("more")) { error in
            XCTAssertEqual(error as? StreamingStateError, .notActive)
        }

        let interrupted = try state.interrupting()
        XCTAssertTrue(interrupted.isTerminal)
        XCTAssertEqual(interrupted.partialContent, "Hello world")
    }

    // MARK: Availability

    func testMatrix_UnavailableCapabilitySurfacesATypedFailure() async {
        let request = TextGenerationRequest(
            identity: CapabilityRequestIdentity(),
            prompt: "Hello",
            model: ModelReference(name: "gpt-4o")
        )
        do {
            _ = try await UnavailableTextGeneration().generateText(from: request)
            XCTFail("Expected a capability error")
        } catch {
            XCTAssertEqual(error as? CapabilityError, .providerUnavailable)
        }
    }

    // MARK: Invalid-input handling

    func testMatrix_InvalidInputIsRejected() throws {
        for value in ["", "not-a-uuid", "550E8400-E29B-41D4-A716-44665544000", "550E8400E29B41D4A716446655440000"] {
            XCTAssertNil(CapabilityRequestIdentity(restoring: value), "Expected rejection of \(value)")
        }
        let malformedJSON = "\"not-a-uuid\""
        XCTAssertThrowsError(try JSONDecoder().decode(CapabilityRequestIdentity.self, from: Data(malformedJSON.utf8)))
    }

    // MARK: Interruption

    func testMatrix_InterruptionPreservesPartialContentEndToEnd() async throws {
        let identity = CapabilityRequestIdentity()
        let request = StreamingRequest(identity: identity, history: [], model: ModelReference(name: "gpt-4o"))
        let stream = try await InterruptedStreaming().stream(request)

        var updates: [StreamingUpdate] = []
        for try await update in stream {
            updates.append(update)
        }
        XCTAssertEqual(updates.count, 2)
        guard case .interruption(_, let partialContent) = updates[1] else {
            return XCTFail("Expected an interruption")
        }

        let state = try StreamingState.active(partialContent: "").appending(partialContent).interrupting()
        XCTAssertEqual(state.partialContent, "Hello")
        XCTAssertEqual(StreamingState.active(partialContent: partialContent).partialContent, "Hello")
    }

    // MARK: Completion

    func testMatrix_CompletionCarriesAssembledAssistantMessageEndToEnd() async throws {
        let identity = CapabilityRequestIdentity()
        let request = StreamingRequest(
            identity: identity,
            history: [Message(role: .user, content: "Hello")],
            model: ModelReference(name: "gpt-4o")
        )
        let stream = try await CompletingStream().stream(request)

        var updates: [StreamingUpdate] = []
        for try await update in stream {
            updates.append(update)
        }
        guard case .completion(_, let message) = updates.last else {
            return XCTFail("Expected a completion")
        }

        var conversation = Conversation(identity: ConversationIdentity())
        try conversation.append(message)
        XCTAssertEqual(conversation.history.last, message)
        XCTAssertEqual(conversation.history.last?.role, .assistant)
    }
}
