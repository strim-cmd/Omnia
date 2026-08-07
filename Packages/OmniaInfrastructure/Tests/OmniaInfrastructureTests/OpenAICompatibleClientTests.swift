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

    private let endpoint = URL(string: "https://api.example.com/v1")!

    private func makeClient(
        transport: FakeTransport,
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
