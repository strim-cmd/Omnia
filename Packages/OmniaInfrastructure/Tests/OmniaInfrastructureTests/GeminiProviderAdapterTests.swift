import Foundation
import XCTest
import OmniaDomain
@testable import OmniaInfrastructure

final class GeminiProviderAdapterTests: XCTestCase {

    // MARK: - Test doubles

    private final class FakeTransport: ProviderTransport, @unchecked Sendable {
        private let lock = NSLock()
        private var recordedRequests: [ProviderHTTPRequest] = []
        let sendResult: Result<Data, ProviderTransportError>
        let streamChunks: [Data]
        let streamError: ProviderTransportError?

        init(
            sendResult: Result<Data, ProviderTransportError> = .success(GeminiProviderAdapterTests.modelListJSON),
            streamChunks: [Data] = [],
            streamError: ProviderTransportError? = nil
        ) {
            self.sendResult = sendResult
            self.streamChunks = streamChunks
            self.streamError = streamError
        }

        var requests: [ProviderHTTPRequest] {
            lock.withLock { recordedRequests }
        }

        func send(_ request: ProviderHTTPRequest) async throws -> ProviderHTTPResponse {
            lock.withLock {
                recordedRequests.append(request)
            }
            return try ProviderHTTPResponse(body: sendResult.get())
        }

        func stream(_ request: ProviderHTTPRequest) -> AsyncThrowingStream<Data, any Error> {
            lock.withLock {
                recordedRequests.append(request)
            }
            return AsyncThrowingStream { continuation in
                for chunk in streamChunks {
                    continuation.yield(chunk)
                }
                if let streamError {
                    continuation.finish(throwing: streamError)
                } else {
                    continuation.finish()
                }
            }
        }
    }

    private final class FakeStreamingTransport: ProviderTransport, @unchecked Sendable {
        enum Terminal {
            case finish
            case throwError(any Error & Sendable)
            case awaitCancellationThenThrow(any Error & Sendable)
        }

        private let lock = NSLock()
        private var recordedRequests: [ProviderHTTPRequest] = []
        private var producedTasks: [Task<Void, Never>] = []
        private var cancellationObserved = false
        private let chunks: [Data]
        private let terminal: Terminal
        private let cancellationContinuation: AsyncStream<Void>.Continuation
        let cancellationStream: AsyncStream<Void>

        init(chunks: [Data], terminal: Terminal) {
            self.chunks = chunks
            self.terminal = terminal
            let signal = AsyncStream.makeStream(of: Void.self)
            self.cancellationStream = signal.stream
            self.cancellationContinuation = signal.continuation
        }

        var requests: [ProviderHTTPRequest] {
            lock.withLock { recordedRequests }
        }

        var didObserveCancellation: Bool {
            lock.withLock { cancellationObserved }
        }

        func send(_ request: ProviderHTTPRequest) async throws -> ProviderHTTPResponse {
            lock.withLock {
                recordedRequests.append(request)
            }
            return ProviderHTTPResponse(body: Data())
        }

        func stream(_ request: ProviderHTTPRequest) -> AsyncThrowingStream<Data, any Error> {
            lock.withLock {
                recordedRequests.append(request)
            }
            let signalContinuation = cancellationContinuation
            return AsyncThrowingStream { continuation in
                let task = Task {
                    for chunk in chunks {
                        continuation.yield(chunk)
                    }
                    switch terminal {
                    case .finish:
                        continuation.finish()
                    case .throwError(let error):
                        continuation.finish(throwing: error)
                    case .awaitCancellationThenThrow(let error):
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .milliseconds(5))
                        }
                        lock.withLock { cancellationObserved = true }
                        signalContinuation.yield(())
                        signalContinuation.finish()
                        continuation.finish(throwing: error)
                    }
                }
                lock.withLock {
                    producedTasks.append(task)
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }

        func cancelStream() {
            lock.withLock { producedTasks }.forEach { $0.cancel() }
        }
    }

    // MARK: - Fixtures

    private let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta")!

    private func makeAdapter(
        transport: any ProviderTransport,
        secret: String = "gemini-adapter-secret"
    ) async throws -> (GeminiProviderAdapter, CredentialReference) {
        let storage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let reference = CredentialReference()
        try await storage.store(Credential(secret: secret), for: reference)
        let client = GeminiClient(transport: transport, credentialStorage: storage)
        return (
            GeminiProviderAdapter(client: client, endpoint: endpoint, credential: reference),
            reference
        )
    }

    private var conversationRequest: ConversationRequest {
        ConversationRequest(
            identity: CapabilityRequestIdentity(),
            history: [
                Message(role: .system, content: "You are concise."),
                Message(role: .user, content: "Hello"),
                Message(role: .assistant, content: "Hi!"),
            ],
            model: ModelReference(name: "gemini-2.5-flash")
        )
    }

    private var streamingRequest: StreamingRequest {
        StreamingRequest(
            identity: CapabilityRequestIdentity(),
            history: [
                Message(role: .system, content: "You are concise."),
                Message(role: .user, content: "Hello"),
            ],
            model: ModelReference(name: "gemini-2.5-flash")
        )
    }

    private static let modelListJSON = Data(
        "{\"models\":[{\"name\":\"models/gemini-2.5-flash\"}]}".utf8
    )

    private static func generateResponseJSON(text: String) -> Data {
        Data(
            """
            {"candidates":[{"content":{"parts":[{"text":"\(text)"}],"role":"model"}}]}
            """.utf8
        )
    }

    private static func streamEventData(content: String) -> Data {
        Data(
            "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"\(content)\"}],\"role\":\"model\"}}]}\n\n".utf8
        )
    }

    // MARK: - Capability conformance

    func testAdapter_ClaimsOnlyTheCapabilitiesItDelivers() async throws {
        let (adapter, _) = try await makeAdapter(transport: FakeTransport())
        let erased: any CapabilityContract = adapter

        XCTAssertNotNil(erased as? any TextGenerationContract)
        XCTAssertNotNil(erased as? any ConversationContract)
        XCTAssertNotNil(erased as? any StreamingContract)
    }

    func testPublicInitializer_ClaimsOnlyTheCapabilitiesItDelivers() {
        let storage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let adapter = GeminiProviderAdapter(
            endpoint: endpoint,
            credential: CredentialReference(),
            credentialStorage: storage
        )
        let erased: any CapabilityContract = adapter

        XCTAssertNotNil(erased as? any TextGenerationContract)
        XCTAssertNotNil(erased as? any ConversationContract)
        XCTAssertNotNil(erased as? any StreamingContract)
    }

    func testPublicInitializer_ReportsUnavailableWithoutNetworkWhenNoCredentialIsStored() async {
        let storage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let adapter = GeminiProviderAdapter(
            endpoint: endpoint,
            credential: CredentialReference(),
            credentialStorage: storage
        )

        let available = await adapter.isAvailable()

        XCTAssertFalse(available)
    }

    // MARK: - Availability

    func testIsAvailable_ReportsTrueWhenTheEndpointAnswers() async throws {
        let transport = FakeTransport()
        let (adapter, _) = try await makeAdapter(transport: transport)

        let available = await adapter.isAvailable()

        XCTAssertTrue(available)
    }

    func testIsAvailable_ProbesTheModelsEndpointWithTheStoredCredential() async throws {
        let transport = FakeTransport()
        let (adapter, _) = try await makeAdapter(transport: transport, secret: "gemini-probe-secret")

        _ = await adapter.isAvailable()

        let sent = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(
            sent.url,
            URL(string: "https://generativelanguage.googleapis.com/v1beta/models")
        )
        XCTAssertEqual(sent.method, "GET")
        XCTAssertEqual(sent.headers["x-goog-api-key"], "gemini-probe-secret")
        XCTAssertNil(sent.body)
    }

    func testIsAvailable_ReportsFalseOnHttpStatus() async throws {
        let transport = FakeTransport(sendResult: .failure(.httpStatus(401)))
        let (adapter, _) = try await makeAdapter(transport: transport)

        let available = await adapter.isAvailable()

        XCTAssertFalse(available)
    }

    func testIsAvailable_ReportsFalseWithoutAStoredCredential() async throws {
        let storage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let client = GeminiClient(transport: FakeTransport(), credentialStorage: storage)
        let adapter = GeminiProviderAdapter(
            client: client,
            endpoint: endpoint,
            credential: CredentialReference()
        )

        let available = await adapter.isAvailable()

        XCTAssertFalse(available)
    }

    // MARK: - Text generation

    func testGenerateText_ReturnsTheProducedText() async throws {
        let transport = FakeTransport(sendResult: .success(Self.generateResponseJSON(text: "Hello!")))
        let (adapter, _) = try await makeAdapter(transport: transport)

        let response = try await adapter.generateText(
            from: TextGenerationRequest(
                identity: CapabilityRequestIdentity(),
                prompt: "Say hi",
                model: ModelReference(name: "gemini-2.5-flash")
            )
        )

        XCTAssertEqual(response.text, "Hello!")
    }

    func testGenerateText_SendsAGenerateContentRequestWithThePrompt() async throws {
        let transport = FakeTransport(sendResult: .success(Self.generateResponseJSON(text: "Hello!")))
        let (adapter, _) = try await makeAdapter(transport: transport, secret: "gemini-gen-secret")

        _ = try await adapter.generateText(
            from: TextGenerationRequest(
                identity: CapabilityRequestIdentity(),
                prompt: "Write a haiku",
                model: ModelReference(name: "gemini-2.5-flash")
            )
        )

        let sent = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(
            sent.url,
            URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")
        )
        XCTAssertEqual(sent.method, "POST")
        XCTAssertEqual(sent.headers["Content-Type"], "application/json")
        XCTAssertEqual(sent.headers["x-goog-api-key"], "gemini-gen-secret")
        let body = try XCTUnwrap(sent.body)
        let decoded = try JSONDecoder().decode(GenerateContentRequest.self, from: body)
        XCTAssertEqual(decoded.contents, [GeminiContent(role: "user", parts: [GeminiPart(text: "Write a haiku")])])
        XCTAssertNil(decoded.systemInstruction)
    }

    func testGenerateText_StripsTheModelsPrefixFromTheRequestedModel() async throws {
        let transport = FakeTransport(sendResult: .success(Self.generateResponseJSON(text: "Hello!")))
        let (adapter, _) = try await makeAdapter(transport: transport)

        _ = try await adapter.generateText(
            from: TextGenerationRequest(
                identity: CapabilityRequestIdentity(),
                prompt: "Write a haiku",
                model: ModelReference(name: "models/gemini-2.5-flash")
            )
        )

        let sent = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(
            sent.url.absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
        )
        XCTAssertEqual(sent.method, "POST")
        XCTAssertEqual(sent.headers["x-goog-api-key"], "gemini-adapter-secret")
    }

    func testGenerateText_SurfacesInvalidResponseWhenThePayloadCannotBeDecoded() async throws {
        let transport = FakeTransport(sendResult: .success(Data("[]".utf8)))
        let (adapter, _) = try await makeAdapter(transport: transport)

        do {
            _ = try await adapter.generateText(
                from: TextGenerationRequest(
                    identity: CapabilityRequestIdentity(),
                    prompt: "Say hi",
                    model: ModelReference(name: "gemini-2.5-flash")
                )
            )
            XCTFail("Expected invalidResponse")
        } catch let error as CapabilityError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testGenerateText_SurfacesInvalidResponseWhenTheResponseHasNoText() async throws {
        let payload = Data("{\"candidates\":[]}".utf8)
        let transport = FakeTransport(sendResult: .success(payload))
        let (adapter, _) = try await makeAdapter(transport: transport)

        do {
            _ = try await adapter.generateText(
                from: TextGenerationRequest(
                    identity: CapabilityRequestIdentity(),
                    prompt: "Say hi",
                    model: ModelReference(name: "gemini-2.5-flash")
                )
            )
            XCTFail("Expected invalidResponse")
        } catch let error as CapabilityError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testGenerateText_SurfacesServerFailureOnServerStatus() async throws {
        let transport = FakeTransport(sendResult: .failure(.httpStatus(503)))
        let (adapter, _) = try await makeAdapter(transport: transport)

        do {
            _ = try await adapter.generateText(
                from: TextGenerationRequest(
                    identity: CapabilityRequestIdentity(),
                    prompt: "Say hi",
                    model: ModelReference(name: "gemini-2.5-flash")
                )
            )
            XCTFail("Expected serverFailure")
        } catch let error as CapabilityError {
            XCTAssertEqual(error, .serverFailure)
        }
    }

    func testGenerateText_SurfacesNetworkUnavailableOnNetworkFailure() async throws {
        let transport = FakeTransport(sendResult: .failure(.networkFailure))
        let (adapter, _) = try await makeAdapter(transport: transport)

        do {
            _ = try await adapter.generateText(
                from: TextGenerationRequest(
                    identity: CapabilityRequestIdentity(),
                    prompt: "Say hi",
                    model: ModelReference(name: "gemini-2.5-flash")
                )
            )
            XCTFail("Expected networkUnavailable")
        } catch let error as CapabilityError {
            XCTAssertEqual(error, .networkUnavailable)
        }
    }

    func testGenerateText_SurfacesTheCredentialStorageErrorWithoutWrappingIt() async throws {
        let storage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let client = GeminiClient(transport: FakeTransport(), credentialStorage: storage)
        let adapter = GeminiProviderAdapter(
            client: client,
            endpoint: endpoint,
            credential: CredentialReference()
        )

        do {
            _ = try await adapter.generateText(
                from: TextGenerationRequest(
                    identity: CapabilityRequestIdentity(),
                    prompt: "Say hi",
                    model: ModelReference(name: "gemini-2.5-flash")
                )
            )
            XCTFail("Expected a credential error")
        } catch is CredentialStorageError {
            // expected
        }
    }

    func testGenerateText_ConfinesTheSecretToTheHeader() async throws {
        let transport = FakeTransport(sendResult: .success(Self.generateResponseJSON(text: "Hello!")))
        let (adapter, _) = try await makeAdapter(transport: transport, secret: "gemini-confined-secret")

        _ = try await adapter.generateText(
            from: TextGenerationRequest(
                identity: CapabilityRequestIdentity(),
                prompt: "Say hi",
                model: ModelReference(name: "gemini-2.5-flash")
            )
        )

        let sent = try XCTUnwrap(transport.requests.first)
        XCTAssertFalse(sent.url.absoluteString.contains("gemini-confined-secret"))
        let body = try XCTUnwrap(sent.body)
        XCTAssertFalse(String(data: body, encoding: .utf8)?.contains("gemini-confined-secret") ?? true)
    }

    // MARK: - Conversation

    func testSendMessage_ReturnsTheAssistantMessage() async throws {
        let transport = FakeTransport(sendResult: .success(Self.generateResponseJSON(text: "How can I help?")))
        let (adapter, _) = try await makeAdapter(transport: transport)

        let response = try await adapter.sendMessage(conversationRequest)

        XCTAssertEqual(response.message, Message(role: .assistant, content: "How can I help?"))
    }

    func testSendMessage_SendsAGenerateContentRequestWithTheHistory() async throws {
        let transport = FakeTransport(sendResult: .success(Self.generateResponseJSON(text: "Hi!")))
        let (adapter, _) = try await makeAdapter(transport: transport, secret: "gemini-conv-secret")

        _ = try await adapter.sendMessage(conversationRequest)

        let sent = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(
            sent.url,
            URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")
        )
        XCTAssertEqual(sent.method, "POST")
        XCTAssertEqual(sent.headers["x-goog-api-key"], "gemini-conv-secret")
        let body = try XCTUnwrap(sent.body)
        let decoded = try JSONDecoder().decode(GenerateContentRequest.self, from: body)
        XCTAssertEqual(decoded.systemInstruction, GeminiSystemInstruction(parts: [GeminiPart(text: "You are concise.")]))
        XCTAssertEqual(
            decoded.contents,
            [
                GeminiContent(role: "user", parts: [GeminiPart(text: "Hello")]),
                GeminiContent(role: "model", parts: [GeminiPart(text: "Hi!")]),
            ]
        )
    }

    func testSendMessage_SurfacesInvalidResponseWhenThePayloadCannotBeDecoded() async throws {
        let transport = FakeTransport(sendResult: .success(Data("[]".utf8)))
        let (adapter, _) = try await makeAdapter(transport: transport)

        do {
            _ = try await adapter.sendMessage(conversationRequest)
            XCTFail("Expected invalidResponse")
        } catch let error as CapabilityError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testSendMessage_SurfacesServerFailureOnServerStatus() async throws {
        let transport = FakeTransport(sendResult: .failure(.httpStatus(503)))
        let (adapter, _) = try await makeAdapter(transport: transport)

        do {
            _ = try await adapter.sendMessage(conversationRequest)
            XCTFail("Expected serverFailure")
        } catch let error as CapabilityError {
            XCTAssertEqual(error, .serverFailure)
        }
    }

    func testSendMessage_SurfacesTheCredentialStorageErrorWithoutWrappingIt() async throws {
        let storage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let client = GeminiClient(transport: FakeTransport(), credentialStorage: storage)
        let adapter = GeminiProviderAdapter(
            client: client,
            endpoint: endpoint,
            credential: CredentialReference()
        )

        do {
            _ = try await adapter.sendMessage(conversationRequest)
            XCTFail("Expected a credential error")
        } catch is CredentialStorageError {
            // expected
        }
    }

    // MARK: - Streaming

    func testStream_DeliversContentDeltasIncrementally() async throws {
        let transport = FakeStreamingTransport(
            chunks: [Self.streamEventData(content: "Hello"), Self.streamEventData(content: " world")],
            terminal: .finish
        )
        let (adapter, _) = try await makeAdapter(transport: transport)
        let request = streamingRequest

        let stream = try await adapter.stream(request)
        var events: [StreamingUpdate] = []
        for try await update in stream {
            events.append(update)
        }

        let deltas = events.compactMap { update -> String? in
            guard case .contentDelta(let identity, let content) = update else {
                return nil
            }
            XCTAssertEqual(identity, request.identity)
            return content
        }

        XCTAssertEqual(deltas, ["Hello", " world"])
    }

    func testStream_EndsWithCompletionCarryingTheAssembledMessage() async throws {
        let transport = FakeStreamingTransport(
            chunks: [Self.streamEventData(content: "Hello"), Self.streamEventData(content: " world")],
            terminal: .finish
        )
        let (adapter, _) = try await makeAdapter(transport: transport)
        let request = streamingRequest

        let stream = try await adapter.stream(request)
        var events: [StreamingUpdate] = []
        for try await update in stream {
            events.append(update)
        }

        XCTAssertEqual(events.count, 3)
        let lastEvent = try XCTUnwrap(events.last)
        guard case .completion(let identity, let message) = lastEvent else {
            return XCTFail("Expected a completion event")
        }
        XCTAssertEqual(identity, request.identity)
        XCTAssertEqual(message, Message(role: .assistant, content: "Hello world"))
    }

    func testStream_SendsAStreamingRequestWithHistoryAndConfinesTheSecret() async throws {
        let transport = FakeStreamingTransport(chunks: [], terminal: .finish)
        let (adapter, _) = try await makeAdapter(transport: transport, secret: "gemini-stream-secret")

        let stream = try await adapter.stream(streamingRequest)
        for try await _ in stream {}

        let sent = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(
            sent.url,
            URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse")
        )
        XCTAssertEqual(sent.method, "POST")
        XCTAssertEqual(sent.headers["x-goog-api-key"], "gemini-stream-secret")
        XCTAssertFalse(sent.url.absoluteString.contains("gemini-stream-secret"))
    }

    func testStream_DeliversInterruptionPreservingPartialContent() async throws {
        let transport = FakeStreamingTransport(
            chunks: [Self.streamEventData(content: "Hello"), Self.streamEventData(content: " world")],
            terminal: .awaitCancellationThenThrow(CancellationError())
        )
        let (adapter, _) = try await makeAdapter(transport: transport)
        let request = streamingRequest
        let stream = try await adapter.stream(request)

        let bothDeltasDelivered = AsyncStream<Void>.makeStream()
        let consumption = Task { () -> [StreamingUpdate] in
            var events: [StreamingUpdate] = []
            for try await update in stream {
                events.append(update)
                if events.count == 2 {
                    bothDeltasDelivered.continuation.yield(())
                    bothDeltasDelivered.continuation.finish()
                }
            }
            return events
        }

        _ = await bothDeltasDelivered.stream.first { _ in true }
        transport.cancelStream()
        _ = await transport.cancellationStream.first { _ in true }

        let events = try await consumption.value

        XCTAssertTrue(transport.didObserveCancellation)
        XCTAssertEqual(events.count, 3)
        let lastEvent = try XCTUnwrap(events.last)
        guard case .interruption(let identity, let partialContent) = lastEvent else {
            return XCTFail("Expected the stream to end with an interruption event")
        }
        XCTAssertEqual(identity, request.identity)
        XCTAssertEqual(partialContent, "Hello world")
    }

    func testStream_ThrowsStreamingInterruptedOnMidStreamFailure() async throws {
        let transport = FakeStreamingTransport(
            chunks: [Self.streamEventData(content: "Hello")],
            terminal: .throwError(ProviderTransportError.networkFailure)
        )
        let (adapter, _) = try await makeAdapter(transport: transport)
        let stream = try await adapter.stream(streamingRequest)

        var events: [StreamingUpdate] = []
        do {
            for try await update in stream {
                events.append(update)
            }
            XCTFail("Expected streamingInterrupted")
        } catch let error as CapabilityError {
            XCTAssertEqual(error, .streamingInterrupted(partialContent: "Hello"))
        }

        let deltas = events.compactMap { update -> String? in
            guard case .contentDelta(_, let content) = update else { return nil }
            return content
        }
        XCTAssertEqual(deltas, ["Hello"])
    }

    func testStream_MapsTransportCategoryBeforeAnyPartialContent() async throws {
        let cases: [(ProviderTransportError, CapabilityError)] = [
            (.networkFailure, .networkUnavailable),
            (.timedOut, .timedOut),
            (.httpStatus(401), .unauthorized),
            (.httpStatus(404), .invalidEndpoint),
            (.httpStatus(429), .rateLimited),
            (.httpStatus(503), .serverFailure),
            (.invalidResponse, .invalidResponse),
        ]
        for (transportError, expected) in cases {
            let transport = FakeStreamingTransport(
                chunks: [],
                terminal: .throwError(transportError)
            )
            let (adapter, _) = try await makeAdapter(transport: transport)
            let stream = try await adapter.stream(streamingRequest)
            do {
                for try await _ in stream {}
                XCTFail("Expected \(expected)")
            } catch let error as CapabilityError {
                XCTAssertEqual(error, expected)
            }
        }
    }

    func testStream_SurfacesTheCredentialStorageErrorWithoutWrappingIt() async throws {
        let storage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let client = GeminiClient(transport: FakeTransport(), credentialStorage: storage)
        let adapter = GeminiProviderAdapter(
            client: client,
            endpoint: endpoint,
            credential: CredentialReference()
        )

        do {
            _ = try await adapter.stream(streamingRequest)
            XCTFail("Expected a credential error")
        } catch is CredentialStorageError {
            // expected
        }
    }

    func testStream_PropagatesConsumerCancellationToTheTransport() async throws {
        let transport = FakeStreamingTransport(
            chunks: [Self.streamEventData(content: "Hello"), Self.streamEventData(content: " world")],
            terminal: .awaitCancellationThenThrow(CancellationError())
        )
        let (adapter, _) = try await makeAdapter(transport: transport)
        let stream = try await adapter.stream(streamingRequest)

        let firstDeltaDelivered = AsyncStream<Void>.makeStream()
        let consumption = Task { () -> [StreamingUpdate] in
            var events: [StreamingUpdate] = []
            for try await update in stream {
                events.append(update)
                if events.count == 1 {
                    firstDeltaDelivered.continuation.yield(())
                    firstDeltaDelivered.continuation.finish()
                }
            }
            return events
        }

        _ = await firstDeltaDelivered.stream.first { _ in true }
        consumption.cancel()
        _ = await transport.cancellationStream.first { _ in true }
        let events = try await consumption.value

        XCTAssertTrue(transport.didObserveCancellation)
        let firstEvent = try XCTUnwrap(events.first)
        guard case .contentDelta(_, let content) = firstEvent else {
            return XCTFail("Expected a content delta before cancellation")
        }
        XCTAssertEqual(content, "Hello")
    }

    // MARK: - Sharing across concurrency domains

    func testAdapter_IsShareableAcrossConcurrencyDomains() async throws {
        let (adapter, _) = try await makeAdapter(transport: FakeTransport())

        let shareable: any Sendable = adapter

        XCTAssertNotNil(shareable)
    }
}
