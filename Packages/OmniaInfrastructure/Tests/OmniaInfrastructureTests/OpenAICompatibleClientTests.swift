import Foundation
import XCTest
import OmniaDomain
@testable import OmniaInfrastructure

final class OpenAICompatibleClientTests: XCTestCase {

    // MARK: - Test doubles

    private final class FakeTransport: ProviderTransport, @unchecked Sendable {
        private let lock = NSLock()
        private var recordedRequests: [ProviderHTTPRequest] = []
        let sendResult: Result<Data, ProviderTransportError>
        let streamChunks: [Data]
        let streamError: ProviderTransportError?

        init(
            sendResult: Result<Data, ProviderTransportError> = .success(Data()),
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

    private final class SequentialTransport: ProviderTransport, @unchecked Sendable {
        private let lock = NSLock()
        private var pendingResults: [Result<Data, ProviderTransportError>]
        private var recordedRequests: [ProviderHTTPRequest] = []

        init(_ results: [Result<Data, ProviderTransportError>]) {
            self.pendingResults = results
        }

        var requests: [ProviderHTTPRequest] {
            lock.withLock { recordedRequests }
        }

        func send(_ request: ProviderHTTPRequest) async throws -> ProviderHTTPResponse {
            let result: Result<Data, ProviderTransportError> = lock.withLock {
                recordedRequests.append(request)
                guard !pendingResults.isEmpty else { return .failure(.invalidResponse) }
                return pendingResults.removeFirst()
            }
            return try ProviderHTTPResponse(body: result.get())
        }

        func stream(_ request: ProviderHTTPRequest) -> AsyncThrowingStream<Data, any Error> {
            AsyncThrowingStream { continuation in
                continuation.finish(throwing: ProviderTransportError.invalidRequest)
            }
        }
    }

    private let endpoint = URL(string: "https://api.example.com/v1")!

    private func makeClient(
        transport: any ProviderTransport,
        storage: SecureCredentialStorage
    ) -> OpenAICompatibleClient {
        OpenAICompatibleClient(transport: transport, credentialStorage: storage)
    }

    private func makeStoredCredential(
        secret: String = "sk-test-secret"
    ) async throws -> (SecureCredentialStorage, CredentialReference) {
        let storage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let reference = CredentialReference()
        try await storage.store(Credential(secret: secret), for: reference)
        return (storage, reference)
    }

    private func makeRequest() -> ChatCompletionRequest {
        ChatCompletionRequest(
            model: "gpt-4o",
            messages: [ChatMessage(role: "user", content: "Hi")],
            stream: false,
            temperature: nil,
            maxTokens: nil
        )
    }

    private func makeInspector(
        transport: any ProviderTransport
    ) async throws -> OpenAICompatibleProviderInspector {
        let (storage, reference) = try await makeStoredCredential(secret: "inspector-secret")
        return OpenAICompatibleProviderInspector(
            client: makeClient(transport: transport, storage: storage),
            endpoint: endpoint,
            credential: reference
        )
    }

    // MARK: - Model discovery and connection validation

    func testModels_DecodesNormalizesAndBuildsAuthenticatedModelsRequest() async throws {
        let transport = FakeTransport(sendResult: .success(Data("""
        {"data":[{"id":" z-model "},{"id":"a-model"},{"id":"a-model"},{"id":""}]}
        """.utf8)))
        let (storage, reference) = try await makeStoredCredential(secret: "models-secret")
        let client = makeClient(transport: transport, storage: storage)

        let models = try await client.models(
            endpoint: endpoint,
            credential: reference
        )

        XCTAssertEqual(models.map(\.name), ["a-model", "z-model"])
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url, URL(string: "https://api.example.com/v1/models"))
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.headers, ["Authorization": "Bearer models-secret"])
        XCTAssertNil(request.body)
    }

    func testModels_EmptyCatalogIsValidAndMalformedCatalogIsInvalidResponse() async throws {
        let empty = FakeTransport(sendResult: .success(Data(#"{"data":[]}"#.utf8)))
        let (storage, reference) = try await makeStoredCredential()
        let client = makeClient(transport: empty, storage: storage)
        let emptyModels = try await client.models(endpoint: endpoint, credential: reference)
        XCTAssertTrue(emptyModels.isEmpty)

        let malformed = FakeTransport(sendResult: .success(Data("[]".utf8)))
        let malformedClient = makeClient(transport: malformed, storage: storage)
        do {
            _ = try await malformedClient.models(endpoint: endpoint, credential: reference)
            XCTFail("Expected invalidResponse")
        } catch let error as ProviderTransportError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testInspectorMapsCatalogTransportFailuresToSafeTypedErrors() async throws {
        let cases: [(ProviderTransportError, ModelCatalogError)] = [
            (.httpStatus(404), .unsupported),
            (.httpStatus(401), .unauthorized),
            (.networkFailure, .unreachable),
            (.httpStatus(429), .rateLimited),
            (.timedOut, .timedOut),
            (.httpStatus(503), .serverFailure),
            (.invalidResponse, .invalidResponse),
        ]
        for (transportError, expected) in cases {
            let inspector = try await makeInspector(
                transport: FakeTransport(sendResult: .failure(transportError))
            )
            do {
                _ = try await inspector.discoverModels()
                XCTFail("Expected \(expected)")
            } catch let error as ModelCatalogError {
                XCTAssertEqual(error, expected)
                XCTAssertFalse(String(describing: error).contains("inspector-secret"))
            }
        }
    }

    func testInspectorConnectionTestMapsFailuresAndMissingModel() async throws {
        let cases: [(ProviderTransportError, ProviderConnectionTestError)] = [
            (.httpStatus(401), .invalidCredential),
            (.networkFailure, .unreachable),
            (.httpStatus(404), .invalidEndpoint),
            (.httpStatus(429), .rateLimited),
            (.timedOut, .timedOut),
            (.httpStatus(500), .serverFailure),
            (.invalidResponse, .invalidResponse),
        ]
        for (transportError, expected) in cases {
            let inspector = try await makeInspector(
                transport: FakeTransport(sendResult: .failure(transportError))
            )
            do {
                _ = try await inspector.testConnection(model: nil)
                XCTFail("Expected \(expected)")
            } catch let error as ProviderConnectionTestError {
                XCTAssertEqual(error, expected)
            }
        }

        let inspector = try await makeInspector(
            transport: FakeTransport(
                sendResult: .success(Data(#"{"data":[{"id":"available"}]}"#.utf8))
            )
        )
        do {
            _ = try await inspector.testConnection(model: ModelReference(name: "missing"))
            XCTFail("Expected modelUnavailable")
        } catch let error as ProviderConnectionTestError {
            XCTAssertEqual(error, .modelUnavailable)
        }
    }

    func testInspectorValidatesManualModelWhenModelsEndpointIsUnsupported() async throws {
        let manualModel = ModelReference(name: "manual/model")
        let transport = SequentialTransport([
            .failure(.httpStatus(404)),
            .success(Data(responseJSON.utf8)),
        ])
        let inspector = try await makeInspector(transport: transport)

        let models = try await inspector.testConnection(model: manualModel)

        XCTAssertEqual(models, [manualModel])
        XCTAssertEqual(
            transport.requests.map(\.url.path),
            ["/v1/models", "/v1/chat/completions"]
        )
        let body = try XCTUnwrap(transport.requests.last?.body)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        XCTAssertEqual(json["model"] as? String, manualModel.name)
        XCTAssertEqual(json["max_tokens"] as? Int, 1)
        XCTAssertEqual(json["stream"] as? Bool, false)
    }

    func testInspectorRejectsUnavailableManualModelWithoutInventingSuccess() async throws {
        let transport = SequentialTransport([
            .failure(.httpStatus(405)),
            .failure(.httpStatus(400)),
        ])
        let inspector = try await makeInspector(transport: transport)

        do {
            _ = try await inspector.testConnection(model: ModelReference(name: "missing"))
            XCTFail("Expected modelUnavailable")
        } catch let error as ProviderConnectionTestError {
            XCTAssertEqual(error, .modelUnavailable)
        }
        XCTAssertEqual(transport.requests.count, 2)
    }

    // MARK: - Non-streaming request construction

    func testChatCompletions_ConstructsTheExpectedRequest() async throws {
        let transport = FakeTransport(sendResult: .success(Data(responseJSON.utf8)))
        let (storage, reference) = try await makeStoredCredential()
        let client = makeClient(transport: transport, storage: storage)

        let response = try await client.chatCompletions(
            request: makeRequest(),
            endpoint: endpoint,
            credential: reference
        )

        XCTAssertEqual(response.choices[0].message.content, "Hello!")
        let sent = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(sent.url, URL(string: "https://api.example.com/v1/chat/completions"))
        XCTAssertEqual(sent.method, "POST")
        XCTAssertEqual(sent.headers["Content-Type"], "application/json")
        XCTAssertEqual(sent.headers["Authorization"], "Bearer sk-test-secret")
        XCTAssertEqual(sent.headers.count, 2)
        let body = try XCTUnwrap(sent.body)
        let decoded = try JSONDecoder().decode(ChatCompletionRequest.self, from: body)
        XCTAssertEqual(decoded.model, "gpt-4o")
        XCTAssertFalse(decoded.stream)
    }

    func testStreamChatCompletions_SetsStreamingFlag() async throws {
        let transport = FakeTransport()
        let (storage, reference) = try await makeStoredCredential()
        let client = makeClient(transport: transport, storage: storage)

        _ = try await client.streamChatCompletions(
            request: makeRequest(),
            endpoint: endpoint,
            credential: reference
        )

        let sent = try XCTUnwrap(transport.requests.first)
        let body = try XCTUnwrap(sent.body)
        let decoded = try JSONDecoder().decode(ChatCompletionRequest.self, from: body)
        XCTAssertTrue(decoded.stream)
    }

    func testChatCompletions_CredentialByReferenceConfinesTheSecretToTheHeader() async throws {
        let transport = FakeTransport(sendResult: .success(Data(responseJSON.utf8)))
        let (storage, reference) = try await makeStoredCredential(secret: "sk-header-only")
        let client = makeClient(transport: transport, storage: storage)

        _ = try await client.chatCompletions(
            request: makeRequest(),
            endpoint: endpoint,
            credential: reference
        )

        let sent = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(sent.headers["Authorization"], "Bearer sk-header-only")
        XCTAssertFalse(sent.url.absoluteString.contains("sk-header-only"))
        XCTAssertFalse(String(decoding: sent.body ?? Data(), as: UTF8.self).contains("sk-header-only"))
        XCTAssertFalse(String(describing: sent.method).contains("sk-header-only"))
    }

    // MARK: - Error translation

    func testChatCompletions_PropagatesHttpStatus() async throws {
        let transport = FakeTransport(sendResult: .failure(.httpStatus(401)))
        let (storage, reference) = try await makeStoredCredential()
        let client = makeClient(transport: transport, storage: storage)

        do {
            _ = try await client.chatCompletions(
                request: makeRequest(),
                endpoint: endpoint,
                credential: reference
            )
            XCTFail("Expected ProviderTransportError.httpStatus(401)")
        } catch ProviderTransportError.httpStatus(let code) {
            XCTAssertEqual(code, 401)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testChatCompletions_PropagatesNetworkFailure() async throws {
        let transport = FakeTransport(sendResult: .failure(.networkFailure))
        let (storage, reference) = try await makeStoredCredential()
        let client = makeClient(transport: transport, storage: storage)

        do {
            _ = try await client.chatCompletions(
                request: makeRequest(),
                endpoint: endpoint,
                credential: reference
            )
            XCTFail("Expected ProviderTransportError.networkFailure")
        } catch ProviderTransportError.networkFailure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testChatCompletions_TranslatesUndecodableBodyToInvalidResponse() async throws {
        let transport = FakeTransport(sendResult: .success(Data("not json".utf8)))
        let (storage, reference) = try await makeStoredCredential()
        let client = makeClient(transport: transport, storage: storage)

        do {
            _ = try await client.chatCompletions(
                request: makeRequest(),
                endpoint: endpoint,
                credential: reference
            )
            XCTFail("Expected ProviderTransportError.invalidResponse")
        } catch ProviderTransportError.invalidResponse {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testChatCompletions_PropagatesMissingCredential() async throws {
        let transport = FakeTransport(sendResult: .success(Data(responseJSON.utf8)))
        let storage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let client = makeClient(transport: transport, storage: storage)

        do {
            _ = try await client.chatCompletions(
                request: makeRequest(),
                endpoint: endpoint,
                credential: CredentialReference()
            )
            XCTFail("Expected CredentialStorageError.credentialNotFound")
        } catch CredentialStorageError.credentialNotFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Streaming

    func testStreamChatCompletions_YieldsChunksPerEventAndStopsAtDone() async throws {
        let chunkJSON = """
        {"id":"chatcmpl-5","model":"gpt-4o","choices":[{"index":0,"delta":{"content":"Hi"},"finish_reason":null}]}
        """
        let transport = FakeTransport(
            streamChunks: [
                Data("data: \(chunkJSON)\n\n".utf8),
                Data("data: [DONE]\n\n".utf8),
            ]
        )
        let (storage, reference) = try await makeStoredCredential()
        let client = makeClient(transport: transport, storage: storage)

        let stream = try await client.streamChatCompletions(
            request: makeRequest(),
            endpoint: endpoint,
            credential: reference
        )
        var chunks: [ChatCompletionChunk] = []
        do {
            for try await chunk in stream {
                chunks.append(chunk)
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].choices[0].delta.content, "Hi")
    }

    func testStreamChatCompletions_HandlesAChunkSplitAcrossTransportChunks() async throws {
        let chunkJSON = """
        {"id":"chatcmpl-6","model":"gpt-4o","choices":[{"index":0,"delta":{"content":"Split"},"finish_reason":null}]}
        """
        let firstHalf = "data: " + String(chunkJSON.prefix(chunkJSON.count / 2))
        let secondHalf = String(chunkJSON.suffix(chunkJSON.count - chunkJSON.count / 2))
        let transport = FakeTransport(
            streamChunks: [
                Data(firstHalf.utf8),
                Data("\(secondHalf)\n\n".utf8),
                Data("data: [DONE]\n\n".utf8),
            ]
        )
        let (storage, reference) = try await makeStoredCredential()
        let client = makeClient(transport: transport, storage: storage)

        let stream = try await client.streamChatCompletions(
            request: makeRequest(),
            endpoint: endpoint,
            credential: reference
        )
        var chunks: [ChatCompletionChunk] = []
        do {
            for try await chunk in stream {
                chunks.append(chunk)
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].choices[0].delta.content, "Split")
    }

    func testStreamChatCompletions_UTF8ContentSurvivesPerByteDelivery() async throws {
        let chunkJSON = """
        {"id":"chatcmpl-8","model":"gpt-4o","choices":[{"index":0,"delta":{"content":"Привет, мир! 😊"},"finish_reason":null}]}
        """
        let payload = Data("data: \(chunkJSON)\n\n".utf8)
        let transport = FakeTransport(
            streamChunks: payload.map { Data([$0]) } + [Data("data: [DONE]\n\n".utf8)]
        )
        let (storage, reference) = try await makeStoredCredential()
        let client = makeClient(transport: transport, storage: storage)

        let stream = try await client.streamChatCompletions(
            request: makeRequest(),
            endpoint: endpoint,
            credential: reference
        )
        var chunks: [ChatCompletionChunk] = []
        do {
            for try await chunk in stream {
                chunks.append(chunk)
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].choices[0].delta.content, "Привет, мир! 😊")
    }

    func testStreamChatCompletions_PropagatesTransportErrors() async throws {
        let chunkJSON = """
        {"id":"chatcmpl-7","model":"gpt-4o","choices":[{"index":0,"delta":{"content":"Hi"},"finish_reason":null}]}
        """
        let transport = FakeTransport(
            streamChunks: [Data("data: \(chunkJSON)\n\n".utf8)],
            streamError: .networkFailure
        )
        let (storage, reference) = try await makeStoredCredential()
        let client = makeClient(transport: transport, storage: storage)

        let stream = try await client.streamChatCompletions(
            request: makeRequest(),
            endpoint: endpoint,
            credential: reference
        )
        do {
            for try await _ in stream {}
            XCTFail("Expected ProviderTransportError.networkFailure")
        } catch ProviderTransportError.networkFailure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStreamChatCompletions_TranslatesUndecodableEventToInvalidResponse() async throws {
        let transport = FakeTransport(
            streamChunks: [
                Data("data: not-json\n\n".utf8),
                Data("data: [DONE]\n\n".utf8),
            ]
        )
        let (storage, reference) = try await makeStoredCredential()
        let client = makeClient(transport: transport, storage: storage)

        let stream = try await client.streamChatCompletions(
            request: makeRequest(),
            endpoint: endpoint,
            credential: reference
        )
        do {
            for try await _ in stream {}
            XCTFail("Expected ProviderTransportError.invalidResponse")
        } catch ProviderTransportError.invalidResponse {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Fixtures

    private var responseJSON: String {
        """
        {
          "id": "chatcmpl-0",
          "model": "gpt-4o",
          "choices": [
            { "index": 0, "message": { "role": "assistant", "content": "Hello!" } }
          ],
          "usage": { "prompt_tokens": 2, "completion_tokens": 1, "total_tokens": 3 }
        }
        """
    }
}
