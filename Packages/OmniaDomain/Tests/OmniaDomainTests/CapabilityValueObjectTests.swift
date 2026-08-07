import XCTest
@testable import OmniaDomain

final class CapabilityValueObjectTests: XCTestCase {

    private var identity: CapabilityRequestIdentity {
        CapabilityRequestIdentity()
    }

    private var model: ModelReference {
        ModelReference(name: "gpt-4o")
    }

    private var history: [Message] {
        [
            Message(role: .system, content: "You are a helpful assistant."),
            Message(role: .user, content: "Hello"),
        ]
    }

    // MARK: Text generation request

    func testTextGenerationRequest_CreationExposesIdentityPromptAndModel() {
        let identity = self.identity
        let request = TextGenerationRequest(identity: identity, prompt: "Hello", model: model)
        XCTAssertEqual(request.identity, identity)
        XCTAssertEqual(request.prompt, "Hello")
        XCTAssertEqual(request.model, model)
    }

    func testTextGenerationRequest_EqualityDependsOnAllFields() {
        let identity = self.identity
        let a = TextGenerationRequest(identity: identity, prompt: "Hello", model: model)
        let b = TextGenerationRequest(identity: identity, prompt: "Hello", model: model)
        XCTAssertEqual(a, b)

        let differentIdentity = TextGenerationRequest(identity: CapabilityRequestIdentity(), prompt: "Hello", model: model)
        XCTAssertNotEqual(a, differentIdentity)

        let differentPrompt = TextGenerationRequest(identity: identity, prompt: "Hi", model: model)
        XCTAssertNotEqual(a, differentPrompt)

        let differentModel = TextGenerationRequest(identity: identity, prompt: "Hello", model: ModelReference(name: "gpt-4o-mini"))
        XCTAssertNotEqual(a, differentModel)
    }

    func testTextGenerationRequest_ImmutabilityFieldsNeverChange() {
        let request = TextGenerationRequest(identity: identity, prompt: "Hello", model: model)
        XCTAssertEqual(request.identity, request.identity)
        XCTAssertEqual(request.prompt, "Hello")
        XCTAssertEqual(request.model, model)
    }

    // MARK: Text generation response

    func testTextGenerationResponse_CreationExposesText() {
        let response = TextGenerationResponse(text: "Hello there!")
        XCTAssertEqual(response.text, "Hello there!")
    }

    func testTextGenerationResponse_EqualityDependsOnText() {
        XCTAssertEqual(TextGenerationResponse(text: "Hi"), TextGenerationResponse(text: "Hi"))
        XCTAssertNotEqual(TextGenerationResponse(text: "Hi"), TextGenerationResponse(text: "Hello"))
    }

    // MARK: Conversation request

    func testConversationRequest_CreationExposesIdentityHistoryAndModel() {
        let identity = self.identity
        let request = ConversationRequest(identity: identity, history: history, model: model)
        XCTAssertEqual(request.identity, identity)
        XCTAssertEqual(request.history, history)
        XCTAssertEqual(request.model, model)
    }

    func testConversationRequest_EqualityDependsOnAllFields() {
        let identity = self.identity
        let a = ConversationRequest(identity: identity, history: history, model: model)
        let b = ConversationRequest(identity: identity, history: history, model: model)
        XCTAssertEqual(a, b)

        let differentIdentity = ConversationRequest(identity: CapabilityRequestIdentity(), history: history, model: model)
        XCTAssertNotEqual(a, differentIdentity)

        let differentHistory = ConversationRequest(identity: identity, history: [Message(role: .user, content: "Hi")], model: model)
        XCTAssertNotEqual(a, differentHistory)

        let differentModel = ConversationRequest(identity: identity, history: history, model: ModelReference(name: "gpt-4o-mini"))
        XCTAssertNotEqual(a, differentModel)
    }

    func testConversationRequest_HistoryOrderIsPreserved() {
        let request = ConversationRequest(identity: identity, history: history, model: model)
        XCTAssertEqual(request.history, history)
        XCTAssertEqual(request.history.count, 2)
        XCTAssertEqual(request.history[0].content, "You are a helpful assistant.")
        XCTAssertEqual(request.history[1].content, "Hello")
    }

    // MARK: Conversation response

    func testConversationResponse_CreationExposesMessage() {
        let message = Message(role: .assistant, content: "Hi!")
        let response = ConversationResponse(message: message)
        XCTAssertEqual(response.message, message)
    }

    func testConversationResponse_EqualityDependsOnMessage() {
        let assistant = Message(role: .assistant, content: "Hi!")
        XCTAssertEqual(ConversationResponse(message: assistant), ConversationResponse(message: assistant))
        XCTAssertNotEqual(
            ConversationResponse(message: assistant),
            ConversationResponse(message: Message(role: .assistant, content: "Hello"))
        )
    }

    func testConversationResponse_ReplyAppendsToHistory() {
        var extended = history
        let response = ConversationResponse(message: Message(role: .assistant, content: "Hi!"))
        extended.append(response.message)
        XCTAssertEqual(extended.count, 3)
        XCTAssertEqual(extended.last, Message(role: .assistant, content: "Hi!"))
    }

    // MARK: Streaming request

    func testStreamingRequest_CreationExposesIdentityHistoryAndModel() {
        let identity = self.identity
        let request = StreamingRequest(identity: identity, history: history, model: model)
        XCTAssertEqual(request.identity, identity)
        XCTAssertEqual(request.history, history)
        XCTAssertEqual(request.model, model)
    }

    func testStreamingRequest_EqualityDependsOnAllFields() {
        let identity = self.identity
        let a = StreamingRequest(identity: identity, history: history, model: model)
        let b = StreamingRequest(identity: identity, history: history, model: model)
        XCTAssertEqual(a, b)

        let differentIdentity = StreamingRequest(identity: CapabilityRequestIdentity(), history: history, model: model)
        XCTAssertNotEqual(a, differentIdentity)

        let differentHistory = StreamingRequest(identity: identity, history: [], model: model)
        XCTAssertNotEqual(a, differentHistory)

        let differentModel = StreamingRequest(identity: identity, history: history, model: ModelReference(name: "gpt-4o-mini"))
        XCTAssertNotEqual(a, differentModel)
    }

    // MARK: Streaming update

    func testStreamingUpdate_ContentDeltaCarriesIdentityAndContent() {
        let identity = self.identity
        let update = StreamingUpdate.contentDelta(identity: identity, content: "Hello")
        guard case .contentDelta(let updateIdentity, let content) = update else {
            return XCTFail("Expected a content delta")
        }
        XCTAssertEqual(updateIdentity, identity)
        XCTAssertEqual(content, "Hello")
    }

    func testStreamingUpdate_CompletionCarriesIdentityAndAssembledMessage() {
        let identity = self.identity
        let message = Message(role: .assistant, content: "Hello there!")
        let update = StreamingUpdate.completion(identity: identity, message: message)
        guard case .completion(let updateIdentity, let completion) = update else {
            return XCTFail("Expected a completion")
        }
        XCTAssertEqual(updateIdentity, identity)
        XCTAssertEqual(completion, message)
    }

    func testStreamingUpdate_InterruptionCarriesIdentityAndPreservedPartialContent() {
        let identity = self.identity
        let update = StreamingUpdate.interruption(identity: identity, partialContent: "Hello")
        guard case .interruption(let updateIdentity, let partialContent) = update else {
            return XCTFail("Expected an interruption")
        }
        XCTAssertEqual(updateIdentity, identity)
        XCTAssertEqual(partialContent, "Hello")
    }

    func testStreamingUpdate_EqualityDependsOnCaseAndPayload() {
        let identity = self.identity
        XCTAssertEqual(
            StreamingUpdate.contentDelta(identity: identity, content: "Hi"),
            StreamingUpdate.contentDelta(identity: identity, content: "Hi")
        )
        XCTAssertNotEqual(
            StreamingUpdate.contentDelta(identity: identity, content: "Hi"),
            StreamingUpdate.contentDelta(identity: identity, content: "Hello")
        )
        XCTAssertNotEqual(
            StreamingUpdate.contentDelta(identity: identity, content: "Hi"),
            StreamingUpdate.completion(identity: identity, message: Message(role: .assistant, content: "Hi"))
        )
        XCTAssertNotEqual(
            StreamingUpdate.contentDelta(identity: identity, content: "Hi"),
            StreamingUpdate.interruption(identity: identity, partialContent: "Hi")
        )
        XCTAssertNotEqual(
            StreamingUpdate.contentDelta(identity: identity, content: "Hi"),
            StreamingUpdate.contentDelta(identity: CapabilityRequestIdentity(), content: "Hi")
        )
    }

    // MARK: Typed identity and model reference on Foundation primitives

    func testValueObjects_IdentityIsTypedNotARawValue() throws {
        let identity = CapabilityRequestIdentity()
        let provider = try XCTUnwrap(ProviderIdentity(restoring: identity.canonicalString))
        XCTAssertNotEqual(AnyHashable(identity), AnyHashable(provider))
    }

    func testValueObjects_IdentityUsesCanonicalSerializedForm() {
        let identity = self.identity
        XCTAssertEqual(identity.canonicalString.split(separator: "-").count, 5)
    }

    func testValueObjects_UseTypedModelReferencesNotRawNames() {
        XCTAssertEqual(model, ModelReference(name: "gpt-4o"))
        XCTAssertNotEqual(model, ModelReference(name: "gpt-4o-mini"))
    }

    // MARK: Sendability

    func testSendability_RequestsShareAcrossConcurrencyDomain() async {
        let identity = self.identity
        let model = self.model
        let textRequest = TextGenerationRequest(identity: identity, prompt: "Hello", model: model)
        let conversationRequest = ConversationRequest(identity: identity, history: history, model: model)
        let streamingRequest = StreamingRequest(identity: identity, history: history, model: model)

        let results = await Task.detached {
            (
                textRequest.identity == identity,
                conversationRequest.history.count,
                streamingRequest.model == model
            )
        }.value
        XCTAssertTrue(results.0)
        XCTAssertEqual(results.1, 2)
        XCTAssertTrue(results.2)
    }

    func testSendability_UpdatesShareAcrossConcurrencyDomain() async {
        let identity = self.identity
        let update = StreamingUpdate.contentDelta(identity: identity, content: "Hello")
        let returned = await Task.detached { update }.value
        XCTAssertEqual(returned, update)
    }
}
