import Foundation
import XCTest
import OmniaDomain
@testable import OmniaInfrastructure

// Infrastructure Sprint 2 verification (issue #76): the verification matrix of
// DES-010 v1.1.0 §3.9.
//
// Black-box: exercises the concrete capability surface through the public
// adapter methods and the Domain capability vocabulary only — provider-specific
// request, response, and chunk shapes never appear here (ARC-004, DES-010
// §3.9.2). The transport seam is injected through the standard test initializer
// so the matrix is deterministic without a network (ARC-001, ARC-006).
//
// The dependency and layer posture is verified by inspection and recorded in
// PROJECT_STATE.md: OmniaInfrastructure depends only on OmniaDomain and
// OmniaFoundation (Package.swift, ARC-009), the sources import no UI framework
// and no other-layer package (ARC-002, ARC-004), and the existing public
// surface is unchanged — the sprint added the three capability methods only.
final class InfrastructureSprint2VerificationTests: XCTestCase {

    // MARK: - Test double

    private final class FakeVerificationTransport: ProviderTransport, @unchecked Sendable {
        enum StreamTerminal {
            case finish
            case throwError(any Error & Sendable)
            case awaitCancellationThenThrow(any Error & Sendable)
        }

        private let lock = NSLock()
        private var recordedRequests: [ProviderHTTPRequest] = []
        private var producedTasks: [Task<Void, Never>] = []
        private var cancellationObserved = false
        let sendResult: Result<Data, ProviderTransportError>
        private let chunks: [Data]
        private let streamTerminal: StreamTerminal
        private let cancellationContinuation: AsyncStream<Void>.Continuation
        let cancellationStream: AsyncStream<Void>

        init(
            sendResult: Result<Data, ProviderTransportError> = .success(Data("[]".utf8)),
            chunks: [Data] = [],
            streamTerminal: StreamTerminal = .finish
        ) {
            self.sendResult = sendResult
            self.chunks = chunks
            self.streamTerminal = streamTerminal
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
            return try ProviderHTTPResponse(body: sendResult.get())
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
                    switch streamTerminal {
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

    private let endpoint = URL(string: "https://api.example.com/v1")!
    private let secret = "sk-verification-secret"

    private func makeAdapter(
        transport: any ProviderTransport
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

    private var textRequest: TextGenerationRequest {
        TextGenerationRequest(
            identity: CapabilityRequestIdentity(),
            prompt: "Hello",
            model: ModelReference(name: "gpt-4o")
        )
    }

    private var conversationRequest: ConversationRequest {
        ConversationRequest(
            identity: CapabilityRequestIdentity(),
            history: [
                Message(role: .system, content: "You are concise."),
                Message(role: .user, content: "Hello"),
            ],
            model: ModelReference(name: "gpt-4o")
        )
    }

    private var streamingRequest: StreamingRequest {
        StreamingRequest(
            identity: CapabilityRequestIdentity(),
            history: [Message(role: .user, content: "Hello")],
            model: ModelReference(name: "gpt-4o")
        )
    }

    private static func completionResponseData(text: String) -> Data {
        Data("""
        {"id":"chatcmpl-1","model":"gpt-4o","choices":[{"index":0,"message":{"role":"assistant","content":"\(text)"},"finish_reason":"stop"}]}
        """.utf8)
    }

    private static func streamChunkData(content: String) -> Data {
        Data("""
        data: {"id":"chatcmpl-5","model":"gpt-4o","choices":[{"index":0,"delta":{"content":"\(content)"},"finish_reason":null}]}\n\n
        """.utf8)
    }

    // MARK: - Text generation capability

    func testVerification_TextGenerationIsDeliveredThroughThePublicSurface() async throws {
        let transport = FakeVerificationTransport(sendResult: .success(Self.completionResponseData(text: "Hi from the model")))
        let (adapter, _) = try await makeAdapter(transport: transport)

        let response = try await adapter.generateText(from: textRequest)

        XCTAssertEqual(response.text, "Hi from the model")
    }

    // MARK: - Conversation capability

    func testVerification_ConversationIsDeliveredThroughThePublicSurface() async throws {
        let transport = FakeVerificationTransport(sendResult: .success(Self.completionResponseData(text: "Greetings")))
        let (adapter, _) = try await makeAdapter(transport: transport)

        let response = try await adapter.sendMessage(conversationRequest)

        XCTAssertEqual(response.message, Message(role: .assistant, content: "Greetings"))
    }

    // MARK: - Streaming capability

    func testVerification_StreamingDeliversDeltasAndEndsWithTheAssembledMessage() async throws {
        let transport = FakeVerificationTransport(
            chunks: [Self.streamChunkData(content: "Hello"), Self.streamChunkData(content: " world")],
            streamTerminal: .finish
        )
        let (adapter, _) = try await makeAdapter(transport: transport)
        let request = streamingRequest

        let stream = try await adapter.stream(request)
        var events: [StreamingUpdate] = []
        for try await update in stream {
            events.append(update)
        }

        XCTAssertEqual(events.count, 3)
        let deltas = events.compactMap { update -> String? in
            guard case .contentDelta(let identity, let content) = update else {
                return nil
            }
            XCTAssertEqual(identity, request.identity)
            return content
        }
        XCTAssertEqual(deltas, ["Hello", " world"])
        guard case .completion(let identity, let message) = try XCTUnwrap(events.last) else {
            return XCTFail("Expected the stream to end with a completion event")
        }
        XCTAssertEqual(identity, request.identity)
        XCTAssertEqual(message, Message(role: .assistant, content: "Hello world"))
    }

    func testVerification_StreamingInterruptionPreservesPartialContent() async throws {
        let transport = FakeVerificationTransport(
            chunks: [Self.streamChunkData(content: "Hello"), Self.streamChunkData(content: " world")],
            streamTerminal: .awaitCancellationThenThrow(CancellationError())
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

    func testVerification_StreamingFailureThrowsWithPartialContent() async throws {
        let transport = FakeVerificationTransport(
            chunks: [Self.streamChunkData(content: "Hello")],
            streamTerminal: .throwError(ProviderTransportError.networkFailure)
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

    // MARK: - Error translation

    func testVerification_TransportFailuresAreTranslatedToDomainCapabilityErrors() async throws {
        let cases: [(ProviderTransportError, CapabilityError)] = [
            (.invalidRequest, .invalidRequest),
            (.invalidResponse, .invalidResponse),
            (.httpStatus(503), .serverFailure),
            (.networkFailure, .networkUnavailable),
            (.timedOut, .timedOut),
        ]
        for (transportError, expected) in cases {
            let transport = FakeVerificationTransport(sendResult: .failure(transportError))
            let (adapter, _) = try await makeAdapter(transport: transport)
            do {
                _ = try await adapter.generateText(from: textRequest)
                XCTFail("Expected \(expected)")
            } catch let error as CapabilityError {
                XCTAssertEqual(error, expected)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testVerification_CredentialFailuresSurfaceUnwrapped() async throws {
        let storage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let client = OpenAICompatibleClient(transport: FakeVerificationTransport(), credentialStorage: storage)
        let adapter = OpenAICompatibleProviderAdapter(
            client: client,
            endpoint: endpoint,
            credential: CredentialReference()
        )

        do {
            _ = try await adapter.generateText(from: textRequest)
            XCTFail("Expected CredentialStorageError.credentialNotFound")
        } catch CredentialStorageError.credentialNotFound {
            // expected — surfaced as the Domain error, never wrapped
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Credential hygiene

    func testVerification_SecretNeverLeavesTheAuthorizationHeaderAcrossAllCapabilities() async throws {
        let transport = FakeVerificationTransport(sendResult: .success(Self.completionResponseData(text: "Hi")))
        let (adapter, _) = try await makeAdapter(transport: transport)

        _ = try await adapter.generateText(from: textRequest)
        _ = try await adapter.sendMessage(conversationRequest)
        _ = try await adapter.stream(streamingRequest)

        XCTAssertEqual(transport.requests.count, 3)
        for sent in transport.requests {
            XCTAssertEqual(sent.headers["Authorization"], "Bearer \(secret)")
            XCTAssertFalse(sent.url.absoluteString.contains(secret))
            XCTAssertFalse(String(decoding: sent.body ?? Data(), as: UTF8.self).contains(secret))
            for (header, value) in sent.headers where header != "Authorization" {
                XCTAssertFalse(value.contains(secret), "Secret leaked into header \(header)")
            }
        }
    }

    // MARK: - Additive surface

    func testVerification_TheFrozenPublicSurfaceIsUnchangedAndAdditive() async {
        let adapter = OpenAICompatibleProviderAdapter(
            endpoint: endpoint,
            credential: CredentialReference(),
            credentialStorage: SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        )
        let erased: any CapabilityContract = adapter

        XCTAssertNotNil(erased as? any TextGenerationContract)
        XCTAssertNotNil(erased as? any ConversationContract)
        XCTAssertNotNil(erased as? any StreamingContract)

        let available = await adapter.isAvailable()

        XCTAssertFalse(available)
    }
}
