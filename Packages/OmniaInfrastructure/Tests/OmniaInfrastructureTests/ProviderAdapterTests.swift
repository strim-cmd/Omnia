import Foundation
import XCTest
import OmniaDomain
@testable import OmniaInfrastructure

final class ProviderAdapterTests: XCTestCase {

    // MARK: - Test doubles

    private final class FakeTransport: ProviderTransport, @unchecked Sendable {
        private let lock = NSLock()
        private var recordedRequests: [ProviderHTTPRequest] = []
        let sendResult: Result<Data, ProviderTransportError>

        init(sendResult: Result<Data, ProviderTransportError> = .success(Data("[]".utf8))) {
            self.sendResult = sendResult
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
            return AsyncThrowingStream { $0.finish() }
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

    private let endpoint = URL(string: "https://api.example.com/v1")!

    private func makeAdapter(
        transport: any ProviderTransport,
        secret: String = "sk-adapter-secret"
    ) async throws -> (OpenAICompatibleProviderAdapter, CredentialReference) {
        let storage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let reference = CredentialReference()
        try await storage.store(Credential(secret: secret), for: reference)
        let client = OpenAICompatibleClient(transport: transport, credentialStorage: storage)
        return (
            OpenAICompatibleProviderAdapter(client: client, endpoint: endpoint, credential: reference),
            reference
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
        let adapter = OpenAICompatibleProviderAdapter(
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
        let adapter = OpenAICompatibleProviderAdapter(
            endpoint: endpoint,
            credential: CredentialReference(),
            credentialStorage: storage
        )

        let available = await adapter.isAvailable()

        XCTAssertFalse(available)
    }

    // MARK: - Availability probe

    func testIsAvailable_ReportsTrueWhenTheEndpointAnswers() async throws {
        let transport = FakeTransport(sendResult: .success(Self.modelListJSON))
        let (adapter, _) = try await makeAdapter(transport: transport)

        let available = await adapter.isAvailable()

        XCTAssertTrue(available)
    }

    func testIsAvailable_ProbesTheModelsEndpointWithTheStoredCredential() async throws {
        let transport = FakeTransport()
        let (adapter, _) = try await makeAdapter(transport: transport, secret: "sk-probe-secret")

        _ = await adapter.isAvailable()

        let sent = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(sent.url, URL(string: "https://api.example.com/v1/models"))
        XCTAssertEqual(sent.method, "GET")
        XCTAssertEqual(sent.headers["Authorization"], "Bearer sk-probe-secret")
        XCTAssertEqual(sent.headers.count, 1)
        XCTAssertNil(sent.body)
    }

    func testIsAvailable_ReportsFalseOnHttpStatus() async throws {
        let transport = FakeTransport(sendResult: .failure(.httpStatus(401)))
        let (adapter, _) = try await makeAdapter(transport: transport)

        let available = await adapter.isAvailable()

        XCTAssertFalse(available)
    }

    func testIsAvailable_ReportsFalseOnNetworkFailure() async throws {
        let transport = FakeTransport(sendResult: .failure(.networkFailure))
        let (adapter, _) = try await makeAdapter(transport: transport)

        let available = await adapter.isAvailable()

        XCTAssertFalse(available)
    }

    func testIsAvailable_ReportsFalseWithoutAStoredCredential() async throws {
        let storage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let client = OpenAICompatibleClient(
            transport: FakeTransport(),
            credentialStorage: storage
        )
        let adapter = OpenAICompatibleProviderAdapter(
            client: client,
            endpoint: endpoint,
            credential: CredentialReference()
        )

        let available = await adapter.isAvailable()

        XCTAssertFalse(available)
    }

    // MARK: - Text generation capability

    func testGenerateText_ReturnsTheProducedText() async throws {
        let transport = FakeTransport(sendResult: .success(Self.textResponseJSON(text: "Hello!")))
        let (adapter, _) = try await makeAdapter(transport: transport)

        let response = try await adapter.generateText(
            from: TextGenerationRequest(
                identity: CapabilityRequestIdentity(),
                prompt: "Say hi",
                model: ModelReference(name: "gpt-4o")
            )
        )

        XCTAssertEqual(response.text, "Hello!")
    }

    func testGenerateText_SendsANonStreamingChatCompletionsRequestWithThePrompt() async throws {
        let transport = FakeTransport(sendResult: .success(Self.textResponseJSON(text: "Hello!")))
        let (adapter, _) = try await makeAdapter(transport: transport, secret: "sk-gen-secret")

        _ = try await adapter.generateText(
            from: TextGenerationRequest(
                identity: CapabilityRequestIdentity(),
                prompt: "Write a haiku",
                model: ModelReference(name: "gpt-4o")
            )
        )

        let sent = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(sent.url, URL(string: "https://api.example.com/v1/chat/completions"))
        XCTAssertEqual(sent.method, "POST")
        XCTAssertEqual(sent.headers["Authorization"], "Bearer sk-gen-secret")

        let body = try JSONDecoder().decode(ChatCompletionRequest.self, from: try XCTUnwrap(sent.body))
        XCTAssertEqual(body.model, "gpt-4o")
        XCTAssertFalse(body.stream)
        XCTAssertEqual(body.messages, [ChatMessage(role: "user", content: "Write a haiku")])
    }

    func testGenerateText_SurfacesInvalidResponseWhenThePayloadCannotBeDecoded() async throws {
        let transport = FakeTransport(sendResult: .success(Data("not-json".utf8)))
        let (adapter, _) = try await makeAdapter(transport: transport)

        do {
            _ = try await adapter.generateText(
                from: TextGenerationRequest(
                    identity: CapabilityRequestIdentity(),
                    prompt: "Hi",
                    model: ModelReference(name: "gpt-4o")
                )
            )
            XCTFail("Expected CapabilityError.invalidResponse")
        } catch CapabilityError.invalidResponse {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGenerateText_SurfacesInvalidResponseWhenTheResponseHasNoChoice() async throws {
        let transport = FakeTransport(sendResult: .success(Data(#"{"id":"chatcmpl-1","model":"gpt-4o","choices":[]}"#.utf8)))
        let (adapter, _) = try await makeAdapter(transport: transport)

        do {
            _ = try await adapter.generateText(
                from: TextGenerationRequest(
                    identity: CapabilityRequestIdentity(),
                    prompt: "Hi",
                    model: ModelReference(name: "gpt-4o")
                )
            )
            XCTFail("Expected CapabilityError.invalidResponse")
        } catch CapabilityError.invalidResponse {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGenerateText_SurfacesServerFailureOnServerStatus() async throws {
        let transport = FakeTransport(sendResult: .failure(.httpStatus(503)))
        let (adapter, _) = try await makeAdapter(transport: transport)

        do {
            _ = try await adapter.generateText(
                from: TextGenerationRequest(
                    identity: CapabilityRequestIdentity(),
                    prompt: "Hi",
                    model: ModelReference(name: "gpt-4o")
                )
            )
            XCTFail("Expected CapabilityError.serverFailure")
        } catch CapabilityError.serverFailure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGenerateText_SurfacesNetworkUnavailableOnNetworkFailure() async throws {
        let transport = FakeTransport(sendResult: .failure(.networkFailure))
        let (adapter, _) = try await makeAdapter(transport: transport)

        do {
            _ = try await adapter.generateText(
                from: TextGenerationRequest(
                    identity: CapabilityRequestIdentity(),
                    prompt: "Hi",
                    model: ModelReference(name: "gpt-4o")
                )
            )
            XCTFail("Expected CapabilityError.networkUnavailable")
        } catch CapabilityError.networkUnavailable {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGenerateText_SurfacesTheCredentialStorageErrorWithoutWrappingIt() async throws {
        let storage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let client = OpenAICompatibleClient(transport: FakeTransport(), credentialStorage: storage)
        let adapter = OpenAICompatibleProviderAdapter(
            client: client,
            endpoint: endpoint,
            credential: CredentialReference()
        )

        do {
            _ = try await adapter.generateText(
                from: TextGenerationRequest(
                    identity: CapabilityRequestIdentity(),
                    prompt: "Hi",
                    model: ModelReference(name: "gpt-4o")
                )
            )
            XCTFail("Expected CredentialStorageError.credentialNotFound")
        } catch CredentialStorageError.credentialNotFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGenerateText_ConfinesTheSecretToTheAuthorizationHeader() async throws {
        let transport = FakeTransport(sendResult: .success(Self.textResponseJSON(text: "Hello!")))
        let (adapter, _) = try await makeAdapter(transport: transport, secret: "sk-confined-secret")

        _ = try await adapter.generateText(
            from: TextGenerationRequest(
                identity: CapabilityRequestIdentity(),
                prompt: "Hi",
                model: ModelReference(name: "gpt-4o")
            )
        )

        let sent = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(sent.headers["Authorization"], "Bearer sk-confined-secret")
        XCTAssertFalse(sent.url.absoluteString.contains("sk-confined-secret"))
        XCTAssertFalse(String(decoding: sent.body ?? Data(), as: UTF8.self).contains("sk-confined-secret"))
    }

    // MARK: - Conversation capability

    private var conversationRequest: ConversationRequest {
        ConversationRequest(
            identity: CapabilityRequestIdentity(),
            history: [
                Message(role: .system, content: "You are concise."),
                Message(role: .user, content: "Hello"),
                Message(role: .assistant, content: "Hi!"),
            ],
            model: ModelReference(name: "gpt-4o")
        )
    }

    func testSendMessage_ReturnsTheAssistantMessage() async throws {
        let transport = FakeTransport(sendResult: .success(Self.textResponseJSON(text: "How can I help?")))
        let (adapter, _) = try await makeAdapter(transport: transport)

        let response = try await adapter.sendMessage(conversationRequest)

        XCTAssertEqual(response.message, Message(role: .assistant, content: "How can I help?"))
    }

    func testSendMessage_SendsANonStreamingChatCompletionsRequestWithTheHistory() async throws {
        let transport = FakeTransport(sendResult: .success(Self.textResponseJSON(text: "Hi!")))
        let (adapter, _) = try await makeAdapter(transport: transport, secret: "sk-conv-secret")

        _ = try await adapter.sendMessage(conversationRequest)

        let sent = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(sent.url, URL(string: "https://api.example.com/v1/chat/completions"))
        XCTAssertEqual(sent.method, "POST")
        XCTAssertEqual(sent.headers["Authorization"], "Bearer sk-conv-secret")

        let body = try JSONDecoder().decode(ChatCompletionRequest.self, from: try XCTUnwrap(sent.body))
        XCTAssertEqual(body.model, "gpt-4o")
        XCTAssertFalse(body.stream)
        XCTAssertEqual(
            body.messages,
            [
                ChatMessage(role: "system", content: "You are concise."),
                ChatMessage(role: "user", content: "Hello"),
                ChatMessage(role: "assistant", content: "Hi!"),
            ]
        )
    }

    func testSendMessage_SurfacesInvalidResponseWhenThePayloadCannotBeDecoded() async throws {
        let transport = FakeTransport(sendResult: .success(Data("not-json".utf8)))
        let (adapter, _) = try await makeAdapter(transport: transport)

        do {
            _ = try await adapter.sendMessage(conversationRequest)
            XCTFail("Expected CapabilityError.invalidResponse")
        } catch CapabilityError.invalidResponse {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendMessage_SurfacesInvalidResponseWhenTheResponseHasNoChoice() async throws {
        let transport = FakeTransport(sendResult: .success(Data(#"{"id":"chatcmpl-1","model":"gpt-4o","choices":[]}"#.utf8)))
        let (adapter, _) = try await makeAdapter(transport: transport)

        do {
            _ = try await adapter.sendMessage(conversationRequest)
            XCTFail("Expected CapabilityError.invalidResponse")
        } catch CapabilityError.invalidResponse {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendMessage_SurfacesServerFailureOnServerStatus() async throws {
        let transport = FakeTransport(sendResult: .failure(.httpStatus(503)))
        let (adapter, _) = try await makeAdapter(transport: transport)

        do {
            _ = try await adapter.sendMessage(conversationRequest)
            XCTFail("Expected CapabilityError.serverFailure")
        } catch CapabilityError.serverFailure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendMessage_SurfacesNetworkUnavailableOnNetworkFailure() async throws {
        let transport = FakeTransport(sendResult: .failure(.networkFailure))
        let (adapter, _) = try await makeAdapter(transport: transport)

        do {
            _ = try await adapter.sendMessage(conversationRequest)
            XCTFail("Expected CapabilityError.networkUnavailable")
        } catch CapabilityError.networkUnavailable {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendMessage_SurfacesTheCredentialStorageErrorWithoutWrappingIt() async throws {
        let storage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let client = OpenAICompatibleClient(transport: FakeTransport(), credentialStorage: storage)
        let adapter = OpenAICompatibleProviderAdapter(
            client: client,
            endpoint: endpoint,
            credential: CredentialReference()
        )

        do {
            _ = try await adapter.sendMessage(conversationRequest)
            XCTFail("Expected CredentialStorageError.credentialNotFound")
        } catch CredentialStorageError.credentialNotFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendMessage_ConfinesTheSecretToTheAuthorizationHeader() async throws {
        let transport = FakeTransport(sendResult: .success(Self.textResponseJSON(text: "Hi!")))
        let (adapter, _) = try await makeAdapter(transport: transport, secret: "sk-conv-confined")

        _ = try await adapter.sendMessage(conversationRequest)

        let sent = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(sent.headers["Authorization"], "Bearer sk-conv-confined")
        XCTAssertFalse(sent.url.absoluteString.contains("sk-conv-confined"))
        XCTAssertFalse(String(decoding: sent.body ?? Data(), as: UTF8.self).contains("sk-conv-confined"))
    }

    // MARK: - Streaming capability

    private var streamingRequest: StreamingRequest {
        StreamingRequest(
            identity: CapabilityRequestIdentity(),
            history: [
                Message(role: .system, content: "You are concise."),
                Message(role: .user, content: "Hello"),
            ],
            model: ModelReference(name: "gpt-4o")
        )
    }

    func testStream_DeliversContentDeltasIncrementally() async throws {
        let transport = FakeStreamingTransport(
            chunks: [Self.streamChunkData(content: "Hello"), Self.streamChunkData(content: " world")],
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
            chunks: [Self.streamChunkData(content: "Hello"), Self.streamChunkData(content: " world")],
            terminal: .finish
        )
        let (adapter, _) = try await makeAdapter(transport: transport)
        let request = streamingRequest

        let stream = try await adapter.stream(request)
        var events: [StreamingUpdate] = []
        for try await update in stream {
            events.append(update)
        }

        guard case .completion(let identity, let message) = try XCTUnwrap(events.last) else {
            return XCTFail("Expected the stream to end with a completion event")
        }
        XCTAssertEqual(identity, request.identity)
        XCTAssertEqual(message, Message(role: .assistant, content: "Hello world"))
    }

    func testStream_SendsAStreamingRequestWithHistoryAndConfinesTheSecret() async throws {
        let transport = FakeStreamingTransport(chunks: [], terminal: .finish)
        let (adapter, _) = try await makeAdapter(transport: transport, secret: "sk-stream-secret")

        _ = try await adapter.stream(streamingRequest)

        let sent = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(sent.url, URL(string: "https://api.example.com/v1/chat/completions"))
        XCTAssertEqual(sent.method, "POST")
        XCTAssertEqual(sent.headers["Authorization"], "Bearer sk-stream-secret")

        let body = try JSONDecoder().decode(ChatCompletionRequest.self, from: try XCTUnwrap(sent.body))
        XCTAssertEqual(body.model, "gpt-4o")
        XCTAssertTrue(body.stream)
        XCTAssertEqual(
            body.messages,
            [
                ChatMessage(role: "system", content: "You are concise."),
                ChatMessage(role: "user", content: "Hello"),
            ]
        )
        XCTAssertFalse(sent.url.absoluteString.contains("sk-stream-secret"))
        XCTAssertFalse(String(decoding: sent.body ?? Data(), as: UTF8.self).contains("sk-stream-secret"))
    }

    func testStream_DeliversInterruptionPreservingPartialContent() async throws {
        let transport = FakeStreamingTransport(
            chunks: [Self.streamChunkData(content: "Hello"), Self.streamChunkData(content: " world")],
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
            chunks: [Self.streamChunkData(content: "Hello")],
            terminal: .throwError(ProviderTransportError.networkFailure)
        )
        let (adapter, _) = try await makeAdapter(transport: transport)
        let stream = try await adapter.stream(streamingRequest)

        var events: [StreamingUpdate] = []
        do {
            for try await update in stream {
                events.append(update)
            }
            XCTFail("Expected CapabilityError.streamingInterrupted")
        } catch CapabilityError.streamingInterrupted(let partialContent) {
            XCTAssertEqual(partialContent, "Hello")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        guard case .contentDelta(_, let content) = events[0] else {
            return XCTFail("Expected a content delta before the failure")
        }
        XCTAssertEqual(content, "Hello")
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
        let client = OpenAICompatibleClient(transport: FakeTransport(), credentialStorage: storage)
        let adapter = OpenAICompatibleProviderAdapter(
            client: client,
            endpoint: endpoint,
            credential: CredentialReference()
        )

        do {
            _ = try await adapter.stream(streamingRequest)
            XCTFail("Expected CredentialStorageError.credentialNotFound")
        } catch CredentialStorageError.credentialNotFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStream_PropagatesConsumerCancellationToTheTransport() async throws {
        let transport = FakeStreamingTransport(
            chunks: [Self.streamChunkData(content: "Hello"), Self.streamChunkData(content: " world")],
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

    // MARK: - Credential confinement

    func testIsAvailable_ConfinesTheSecretToTheAuthorizationHeader() async throws {
        let transport = FakeTransport()
        let (adapter, _) = try await makeAdapter(transport: transport, secret: "sk-confined-secret")

        _ = await adapter.isAvailable()

        let sent = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(sent.headers["Authorization"], "Bearer sk-confined-secret")
        XCTAssertFalse(sent.url.absoluteString.contains("sk-confined-secret"))
        XCTAssertNil(sent.body)
    }

    // MARK: - Shell invariants

    func testAdapter_IsShareableAcrossConcurrencyDomains() async throws {
        let transport = FakeTransport(sendResult: .success(Self.modelListJSON))
        let (adapter, _) = try await makeAdapter(transport: transport)

        let available: Bool = await Task.detached {
            await adapter.isAvailable()
        }.value

        XCTAssertTrue(available)
    }

    // MARK: - Fixtures

    private static func textResponseJSON(text: String) -> Data {
        Data("""
        {"id":"chatcmpl-1","model":"gpt-4o","choices":[{"index":0,"message":{"role":"assistant","content":"\(text)"},"finish_reason":"stop"}]}
        """.utf8)
    }

    private static let modelListJSON = Data("""
    {"data":[{"id":"gpt-4o"}]}
    """.utf8)

    private static func streamChunkData(content: String) -> Data {
        Data("""
        data: {"id":"chatcmpl-5","model":"gpt-4o","choices":[{"index":0,"delta":{"content":"\(content)"},"finish_reason":null}]}\n\n
        """.utf8)
    }
}
