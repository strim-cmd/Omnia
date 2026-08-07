import XCTest
@testable import OmniaDomain

private struct MockTextGeneration: TextGenerationContract {
    func generateText(from request: TextGenerationRequest) async throws -> TextGenerationResponse {
        TextGenerationResponse(text: request.prompt)
    }
}

private struct MockConversation: ConversationContract {
    func sendMessage(_ request: ConversationRequest) async throws -> ConversationResponse {
        ConversationResponse(message: Message(role: .assistant, content: "Reply"))
    }
}

private struct MockStreaming: StreamingContract {
    func stream(_ request: StreamingRequest) async throws -> AsyncThrowingStream<StreamingUpdate, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.contentDelta(identity: request.identity, content: "Hello"))
            continuation.yield(.completion(identity: request.identity, message: Message(role: .assistant, content: "Hello")))
            continuation.finish()
        }
    }
}

private struct MockInterruptedStreaming: StreamingContract {
    func stream(_ request: StreamingRequest) async throws -> AsyncThrowingStream<StreamingUpdate, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.contentDelta(identity: request.identity, content: "Hello"))
            continuation.yield(.interruption(identity: request.identity, partialContent: "Hello"))
            continuation.finish()
        }
    }
}

private struct FailingTextGeneration: TextGenerationContract {
    func generateText(from request: TextGenerationRequest) async throws -> TextGenerationResponse {
        throw CapabilityError.providerUnavailable
    }
}

private struct MockMultiCapability: TextGenerationContract, ConversationContract, StreamingContract {
    func generateText(from request: TextGenerationRequest) async throws -> TextGenerationResponse {
        TextGenerationResponse(text: request.prompt)
    }

    func sendMessage(_ request: ConversationRequest) async throws -> ConversationResponse {
        ConversationResponse(message: Message(role: .assistant, content: "Reply"))
    }

    func stream(_ request: StreamingRequest) async throws -> AsyncThrowingStream<StreamingUpdate, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

final class CapabilityContractTests: XCTestCase {

    private var identity: CapabilityRequestIdentity {
        CapabilityRequestIdentity()
    }

    private var model: ModelReference {
        ModelReference(name: "gpt-4o")
    }

    // MARK: Realized contracts

    func testRealizedContracts_ConformToTheCapabilityContract() {
        let contracts: [any CapabilityContract] = [
            MockTextGeneration(),
            MockConversation(),
            MockStreaming(),
        ]
        XCTAssertEqual(contracts.count, 3)
        XCTAssertTrue(contracts[0] is TextGenerationContract)
        XCTAssertTrue(contracts[1] is ConversationContract)
        XCTAssertTrue(contracts[2] is StreamingContract)
    }

    func testMultiCapabilityConformance_OneTypeDeliversMultipleCapabilities() {
        let contract: any CapabilityContract = MockMultiCapability()
        XCTAssertTrue(contract is TextGenerationContract)
        XCTAssertTrue(contract is ConversationContract)
        XCTAssertTrue(contract is StreamingContract)
    }

    // MARK: Realized set

    func testRealizedSet_ContainsExactlyTheCoreCapabilities() {
        XCTAssertEqual(Capability.realized, [.textGeneration, .conversation, .streaming])
        XCTAssertEqual(Capability.realized.count, 3)
    }

    func testRealizedSet_ExcludesExtensionPoints() {
        let extensionPoints: Set<Capability> = [
            .vision,
            .imageGeneration,
            .embeddings,
            .toolCalling,
            .structuredOutput,
            .audio,
            .reasoning,
        ]
        XCTAssertTrue(Capability.realized.isDisjoint(with: extensionPoints))
    }

    func testRealizedSet_MatchesTheNumberOFRealizedContracts() {
        XCTAssertEqual(Capability.realized.count, 3)
    }

    // MARK: Concrete methods

    func testGenerateText_ReturnsTheProducedText() async throws {
        let request = TextGenerationRequest(identity: identity, prompt: "Hello", model: model)
        let response = try await MockTextGeneration().generateText(from: request)
        XCTAssertEqual(response.text, "Hello")
    }

    func testSendMessage_ReturnsAssistantReplyThatAppendsToHistory() async throws {
        let request = ConversationRequest(
            identity: identity,
            history: [Message(role: .user, content: "Hello")],
            model: model
        )
        let response = try await MockConversation().sendMessage(request)
        XCTAssertEqual(response.message.role, .assistant)

        var extended = request.history
        extended.append(response.message)
        XCTAssertEqual(extended.count, 2)
        XCTAssertEqual(extended.last, response.message)
    }

    func testStream_DeliversDeltasAndEndsWithCompletion() async throws {
        let request = StreamingRequest(identity: identity, history: [], model: model)
        let stream = try await MockStreaming().stream(request)

        var events: [StreamingUpdate] = []
        for try await update in stream {
            events.append(update)
        }

        XCTAssertEqual(events.count, 2)
        guard case .contentDelta(_, let content) = events[0] else {
            return XCTFail("Expected a content delta")
        }
        XCTAssertEqual(content, "Hello")
        guard case .completion(_, let message) = events[1] else {
            return XCTFail("Expected a completion")
        }
        XCTAssertEqual(message, Message(role: .assistant, content: "Hello"))
    }

    func testStream_InterruptionCarriesPreservedPartialContent() async throws {
        let request = StreamingRequest(identity: identity, history: [], model: model)
        let stream = try await MockInterruptedStreaming().stream(request)

        var events: [StreamingUpdate] = []
        for try await update in stream {
            events.append(update)
        }

        XCTAssertEqual(events.count, 2)
        guard case .interruption(_, let partialContent) = events[1] else {
            return XCTFail("Expected an interruption")
        }
        XCTAssertEqual(partialContent, "Hello")
    }

    func testGenerateText_FailuresAreExpressedInCapabilityErrors() async {
        let request = TextGenerationRequest(identity: identity, prompt: "Hello", model: model)
        do {
            _ = try await FailingTextGeneration().generateText(from: request)
            XCTFail("Expected a capability error")
        } catch {
            XCTAssertEqual(error as? CapabilityError, .providerUnavailable)
        }
    }

    // MARK: Sendability

    func testSendability_ShareContractAcrossConcurrencyDomain() async {
        let contract = MockMultiCapability()
        let isConversation: Bool = await Task.detached {
            (contract as any CapabilityContract) is ConversationContract
        }.value
        XCTAssertTrue(isConversation)
    }

    func testSendability_InvokeContractMethodAcrossConcurrencyDomain() async throws {
        let request = TextGenerationRequest(identity: identity, prompt: "Hi", model: model)
        let text = try await Task.detached {
            try await MockTextGeneration().generateText(from: request).text
        }.value
        XCTAssertEqual(text, "Hi")
    }
}
