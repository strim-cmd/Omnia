import XCTest
import OmniaDomain
@testable import OmniaInfrastructure

final class CapabilityMappingTests: XCTestCase {

    // MARK: - Fixtures

    private var identity: CapabilityRequestIdentity {
        CapabilityRequestIdentity()
    }

    private var model: ModelReference {
        ModelReference(name: "gpt-4o")
    }

    private var history: [Message] {
        [
            Message(role: .system, content: "You are concise."),
            Message(role: .user, content: "Hello"),
            Message(role: .assistant, content: "Hi!"),
        ]
    }

    // MARK: - Domain requests to wire requests

    func testTextGenerationRequest_MapsPromptToASingleUserMessage() {
        let wire = CapabilityMapping.request(
            from: TextGenerationRequest(identity: identity, prompt: "Write a haiku", model: model)
        )

        XCTAssertEqual(wire.model, "gpt-4o")
        XCTAssertFalse(wire.stream)
        XCTAssertEqual(wire.messages, [ChatMessage(role: "user", content: "Write a haiku")])
    }

    func testConversationRequest_MapsHistoryInOrderAndNeverStreams() throws {
        let wire = try CapabilityMapping.request(
            from: ConversationRequest(identity: identity, history: history, model: model)
        )

        XCTAssertEqual(wire.model, "gpt-4o")
        XCTAssertFalse(wire.stream)
        XCTAssertEqual(
            wire.messages,
            [
                ChatMessage(role: "system", content: "You are concise."),
                ChatMessage(role: "user", content: "Hello"),
                ChatMessage(role: "assistant", content: "Hi!"),
            ]
        )
    }

    func testStreamingRequest_MapsHistoryInOrderAndStreams() throws {
        let wire = try CapabilityMapping.request(
            from: StreamingRequest(identity: identity, history: history, model: model)
        )

        XCTAssertEqual(wire.model, "gpt-4o")
        XCTAssertTrue(wire.stream)
        XCTAssertEqual(wire.messages.count, history.count)
        XCTAssertEqual(wire.messages[1], ChatMessage(role: "user", content: "Hello"))
    }

    func testStreamingRequest_KeepsAnEmptyHistoryEmpty() throws {
        let wire = try CapabilityMapping.request(
            from: StreamingRequest(identity: identity, history: [], model: model)
        )

        XCTAssertTrue(wire.stream)
        XCTAssertTrue(wire.messages.isEmpty)
    }

    // MARK: - Wire responses to Domain responses

    func testTextResponse_UsesTheFirstChoiceAssistantContent() throws {
        let wire = ChatCompletionResponse(
            id: "chatcmpl-1",
            model: "gpt-4o",
            choices: [
                ChatCompletionChoice(index: 0, message: .assistant("First!"), finishReason: "stop"),
                ChatCompletionChoice(index: 1, message: .assistant("Ignored"), finishReason: nil),
            ],
            usage: nil
        )

        let response = try CapabilityMapping.textResponse(from: wire)

        XCTAssertEqual(response.text, "First!")
    }

    func testConversationResponse_UsesTheFirstChoiceAssistantContent() throws {
        let wire = ChatCompletionResponse(
            id: "chatcmpl-1",
            model: "gpt-4o",
            choices: [ChatCompletionChoice(index: 0, message: .assistant("Hi!"), finishReason: "stop")],
            usage: nil
        )

        let response = try CapabilityMapping.conversationResponse(from: wire)

        XCTAssertEqual(response.message, Message(role: .assistant, content: "Hi!"))
    }

    func testTextResponse_RejectsAResponseWithoutChoices() {
        let wire = ChatCompletionResponse(
            id: "chatcmpl-1",
            model: "gpt-4o",
            choices: [],
            usage: nil
        )

        XCTAssertThrowsError(try CapabilityMapping.textResponse(from: wire)) { error in
            XCTAssertEqual(error as? CapabilityError, .invalidResponse)
        }
    }

    func testConversationResponse_RejectsAResponseWithoutAssistantContent() {
        let wire = ChatCompletionResponse(
            id: "chatcmpl-1",
            model: "gpt-4o",
            choices: [ChatCompletionChoice(index: 0, message: .noContent, finishReason: nil)],
            usage: nil
        )

        XCTAssertThrowsError(try CapabilityMapping.conversationResponse(from: wire)) { error in
            XCTAssertEqual(error as? CapabilityError, .invalidResponse)
        }
    }

    // MARK: - Wire chunks to Domain streaming updates

    func testChunkUpdate_MapsContentToAContentDeltaCarryingTheRequestIdentity() throws {
        let identity = self.identity
        let chunk = ChatCompletionChunk(
            id: "chatcmpl-3",
            model: "gpt-4o",
            choices: [ChatCompletionChunkChoice(index: 0, delta: .init(role: "assistant", content: "Hello"), finishReason: nil)]
        )

        let update = try XCTUnwrap(CapabilityMapping.update(from: chunk, identity: identity))

        XCTAssertEqual(update, .contentDelta(identity: identity, content: "Hello"))
    }

    func testChunkUpdate_ProducesNoContentDeltaForAFinishReasonOnlyChunk() {
        let chunk = ChatCompletionChunk(
            id: "chatcmpl-4",
            model: "gpt-4o",
            choices: [ChatCompletionChunkChoice(index: 0, delta: .init(role: nil, content: nil), finishReason: "stop")]
        )

        XCTAssertNil(CapabilityMapping.update(from: chunk, identity: identity))
    }

    func testChunkUpdate_KeepsAnEmptyContentDeltaAsContent() throws {
        let identity = self.identity
        let chunk = ChatCompletionChunk(
            id: "chatcmpl-5",
            model: "gpt-4o",
            choices: [ChatCompletionChunkChoice(index: 0, delta: .init(role: "assistant", content: ""), finishReason: nil)]
        )

        let update = try XCTUnwrap(CapabilityMapping.update(from: chunk, identity: identity))

        XCTAssertEqual(update, .contentDelta(identity: identity, content: ""))
    }

    // MARK: - Error translation

    func testErrorTranslation_InvalidRequestStaysInvalidRequest() {
        XCTAssertEqual(
            CapabilityMapping.capabilityError(from: .invalidRequest),
            .invalidRequest
        )
    }

    func testErrorTranslation_InvalidResponseStaysInvalidResponse() {
        XCTAssertEqual(
            CapabilityMapping.capabilityError(from: .invalidResponse),
            .invalidResponse
        )
    }

    func testErrorTranslation_HttpStatusRetainsActionableCategory() {
        let cases: [(Int, CapabilityError)] = [
            (400, .invalidRequest),
            (401, .unauthorized),
            (404, .invalidEndpoint),
            (408, .timedOut),
            (429, .rateLimited),
            (503, .serverFailure),
            (451, .providerUnavailable),
        ]
        for (code, expected) in cases {
            XCTAssertEqual(
                CapabilityMapping.capabilityError(from: .httpStatus(code)),
                expected,
                "Status \(code) should retain its safe category"
            )
        }
    }

    func testErrorTranslation_NetworkAndTimeoutStayDistinct() {
        XCTAssertEqual(
            CapabilityMapping.capabilityError(from: .networkFailure),
            .networkUnavailable
        )
        XCTAssertEqual(
            CapabilityMapping.capabilityError(from: .timedOut),
            .timedOut
        )
    }
}

private extension ChatCompletionResponseMessage {
    /// A helper fixture: an assistant message with `content`.
    static func assistant(_ content: String) -> ChatCompletionResponseMessage {
        ChatCompletionResponseMessage(role: "assistant", content: content)
    }

    /// A helper fixture: an assistant message without content.
    static var noContent: ChatCompletionResponseMessage {
        ChatCompletionResponseMessage(role: "assistant", content: nil)
    }
}
