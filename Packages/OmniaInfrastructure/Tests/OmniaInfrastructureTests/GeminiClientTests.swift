import Foundation
import XCTest
import OmniaDomain
@testable import OmniaInfrastructure

final class GeminiClientTests: XCTestCase {

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

    // MARK: - Fixtures

    private let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta")!
    private let secret = "gemini-client-secret"

    private func storedCredential(secret: String = "gemini-client-secret") async throws -> (SecureCredentialStorage, CredentialReference) {
        let storage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let reference = CredentialReference()
        try await storage.store(Credential(secret: secret), for: reference)
        return (storage, reference)
    }

    private func makeRequest() -> GenerateContentRequest {
        GenerateContentRequest(
            contents: [GeminiContent(role: "user", parts: [GeminiPart(text: "Hello")])],
            systemInstruction: nil
        )
    }

    private func responseJSON(text: String) -> Data {
        Data(
            """
            {"candidates":[{"content":{"parts":[{"text":"\(text)"}],"role":"model"}}],"usageMetadata":{"promptTokenCount":2,"candidatesTokenCount":1,"totalTokenCount":3}}
            """.utf8
        )
    }

    private func eventData(text: String) -> Data {
        Data(
            "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"\(text)\"}],\"role\":\"model\"}}]}\n\n".utf8
        )
    }

    /// Drains a response stream, returning the yielded responses and any terminal error.
    private func drain(
        _ stream: AsyncThrowingStream<GenerateContentResponse, any Error>
    ) -> (events: [GenerateContentResponse], error: (any Error)?) {
        let expectation = expectation(description: "stream drain")
        var events: [GenerateContentResponse] = []
        var terminalError: (any Error)?

        _ = Task {
            do {
                for try await event in stream {
                    events.append(event)
                }
            } catch {
                terminalError = error
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
        return (events, terminalError)
    }

    // MARK: - Generate Content

    func testGenerateContent_ConstructsTheExpectedRequest() async throws {
        let transport = FakeTransport(sendResult: .success(responseJSON(text: "Hello!")))
        let (storage, reference) = try await storedCredential()
        let client = GeminiClient(transport: transport, credentialStorage: storage)

        let request = makeRequest()
        _ = try await client.generateContent(
            request: request,
            model: "gemini-2.5-flash",
            endpoint: endpoint,
            credential: reference
        )

        let httpRequest = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(
            httpRequest.url.absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
        )
        XCTAssertEqual(httpRequest.method, "POST")
        XCTAssertEqual(httpRequest.headers["Content-Type"], "application/json")
        XCTAssertEqual(httpRequest.headers["x-goog-api-key"], secret)
        let body = try XCTUnwrap(httpRequest.body)
        let decoded = try JSONDecoder().decode(GenerateContentRequest.self, from: body)
        XCTAssertEqual(decoded, request)
    }

    func testGenerateContent_StripsTheModelsPrefixAndNormalizesTheTrailingSlash() async throws {
        let transport = FakeTransport(sendResult: .success(responseJSON(text: "Hello!")))
        let (storage, reference) = try await storedCredential()
        let client = GeminiClient(transport: transport, credentialStorage: storage)
        let slashedEndpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/")!

        _ = try await client.generateContent(
            request: makeRequest(),
            model: "models/gemini-2.5-flash",
            endpoint: slashedEndpoint,
            credential: reference
        )

        let httpRequest = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(
            httpRequest.url.absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
        )
    }

    func testGenerateContent_KeepsTheSecretOutOfTheURLAndBody() async throws {
        let transport = FakeTransport(sendResult: .success(responseJSON(text: "Hello!")))
        let (storage, reference) = try await storedCredential()
        let client = GeminiClient(transport: transport, credentialStorage: storage)

        _ = try await client.generateContent(
            request: makeRequest(),
            model: "gemini-2.5-flash",
            endpoint: endpoint,
            credential: reference
        )

        let httpRequest = try XCTUnwrap(transport.requests.first)
        XCTAssertFalse(httpRequest.url.absoluteString.contains(secret))
        let body = try XCTUnwrap(httpRequest.body)
        XCTAssertFalse(String(data: body, encoding: .utf8)?.contains(secret) ?? true)
    }

    func testGenerateContent_ReturnsTheDecodedResponse() async throws {
        let transport = FakeTransport(sendResult: .success(responseJSON(text: "Hello!")))
        let (storage, reference) = try await storedCredential()
        let client = GeminiClient(transport: transport, credentialStorage: storage)

        let response = try await client.generateContent(
            request: makeRequest(),
            model: "gemini-2.5-flash",
            endpoint: endpoint,
            credential: reference
        )

        XCTAssertEqual(response.candidates?.first?.content?.parts?.first?.text, "Hello!")
        XCTAssertEqual(response.usageMetadata?.totalTokenCount, 3)
    }

    func testGenerateContent_TranslatesAnUndecodableBodyToInvalidResponse() async throws {
        let transport = FakeTransport(sendResult: .success(Data("{ not json }".utf8)))
        let (storage, reference) = try await storedCredential()
        let client = GeminiClient(transport: transport, credentialStorage: storage)

        do {
            _ = try await client.generateContent(
                request: makeRequest(),
                model: "gemini-2.5-flash",
                endpoint: endpoint,
                credential: reference
            )
            XCTFail("Expected invalidResponse")
        } catch let error as ProviderTransportError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testGenerateContent_PropagatesTransportFailures() async throws {
        let cases: [ProviderTransportError] = [
            .networkFailure,
            .timedOut,
            .httpStatus(401),
            .invalidResponse,
        ]
        for failure in cases {
            let transport = FakeTransport(sendResult: .failure(failure))
            let (storage, reference) = try await storedCredential()
            let client = GeminiClient(transport: transport, credentialStorage: storage)

            do {
                _ = try await client.generateContent(
                    request: makeRequest(),
                    model: "gemini-2.5-flash",
                    endpoint: endpoint,
                    credential: reference
                )
                XCTFail("Expected \(failure)")
            } catch {
                XCTAssertEqual(error as? ProviderTransportError, failure)
            }
        }
    }

    func testGenerateContent_PropagatesACredentialFailure() async throws {
        let transport = FakeTransport(sendResult: .success(responseJSON(text: "Hello!")))
        let emptyStorage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let client = GeminiClient(transport: transport, credentialStorage: emptyStorage)

        do {
            _ = try await client.generateContent(
                request: makeRequest(),
                model: "gemini-2.5-flash",
                endpoint: endpoint,
                credential: CredentialReference()
            )
            XCTFail("Expected a credential error")
        } catch is CredentialStorageError {
            // expected
        }
    }

    // MARK: - Stream Generate Content

    func testStreamGenerateContent_ConstructsTheStreamingRequest() async throws {
        let transport = FakeTransport()
        let (storage, reference) = try await storedCredential()
        let client = GeminiClient(transport: transport, credentialStorage: storage)

        let stream = try await client.streamGenerateContent(
            request: makeRequest(),
            model: "gemini-2.5-flash",
            endpoint: endpoint,
            credential: reference
        )
        _ = drain(stream)

        let httpRequest = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(
            httpRequest.url.absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse"
        )
        XCTAssertEqual(httpRequest.method, "POST")
        XCTAssertEqual(httpRequest.headers["x-goog-api-key"], secret)
    }

    func testStreamGenerateContent_YieldsOneResponsePerSSEDataEvent() async throws {
        let transport = FakeTransport(streamChunks: [eventData(text: "Hello"), eventData(text: " world")])
        let (storage, reference) = try await storedCredential()
        let client = GeminiClient(transport: transport, credentialStorage: storage)

        let stream = try await client.streamGenerateContent(
            request: makeRequest(),
            model: "gemini-2.5-flash",
            endpoint: endpoint,
            credential: reference
        )
        let result = drain(stream)

        XCTAssertNil(result.error)
        XCTAssertEqual(result.events.count, 2)
        XCTAssertEqual(result.events[0].candidates?.first?.content?.parts?.first?.text, "Hello")
        XCTAssertEqual(result.events[1].candidates?.first?.content?.parts?.first?.text, " world")
    }

    func testStreamGenerateContent_AssemblesAnEventSplitAcrossTransportChunks() async throws {
        let event = String(decoding: eventData(text: "Hello"), as: UTF8.self)
        let split = event.count / 2
        let chunks = [
            Data(String(event.prefix(split)).utf8),
            Data(String(event.suffix(from: event.index(event.startIndex, offsetBy: split))).utf8),
        ]
        let transport = FakeTransport(streamChunks: chunks)
        let (storage, reference) = try await storedCredential()
        let client = GeminiClient(transport: transport, credentialStorage: storage)

        let stream = try await client.streamGenerateContent(
            request: makeRequest(),
            model: "gemini-2.5-flash",
            endpoint: endpoint,
            credential: reference
        )
        let result = drain(stream)

        XCTAssertNil(result.error)
        XCTAssertEqual(result.events.count, 1)
        XCTAssertEqual(result.events[0].candidates?.first?.content?.parts?.first?.text, "Hello")
    }

    func testStreamGenerateContent_HandlesUTF8BoundariesAcrossPerByteChunks() async throws {
        let event = String(decoding: eventData(text: "Привет"), as: UTF8.self)
        let chunks = event.utf8.map { Data([$0]) }
        let transport = FakeTransport(streamChunks: chunks)
        let (storage, reference) = try await storedCredential()
        let client = GeminiClient(transport: transport, credentialStorage: storage)

        let stream = try await client.streamGenerateContent(
            request: makeRequest(),
            model: "gemini-2.5-flash",
            endpoint: endpoint,
            credential: reference
        )
        let result = drain(stream)

        XCTAssertNil(result.error)
        XCTAssertEqual(result.events.count, 1)
        XCTAssertEqual(result.events[0].candidates?.first?.content?.parts?.first?.text, "Привет")
    }

    func testStreamGenerateContent_TranslatesAnUndecodableEventToInvalidResponse() async throws {
        let transport = FakeTransport(streamChunks: [Data("data: { not json }\n\n".utf8)])
        let (storage, reference) = try await storedCredential()
        let client = GeminiClient(transport: transport, credentialStorage: storage)

        let stream = try await client.streamGenerateContent(
            request: makeRequest(),
            model: "gemini-2.5-flash",
            endpoint: endpoint,
            credential: reference
        )
        let result = drain(stream)

        XCTAssertEqual(result.error as? ProviderTransportError, .invalidResponse)
        XCTAssertTrue(result.events.isEmpty)
    }

    func testStreamGenerateContent_PropagatesTransportFailures() async throws {
        let transport = FakeTransport(streamError: .networkFailure)
        let (storage, reference) = try await storedCredential()
        let client = GeminiClient(transport: transport, credentialStorage: storage)

        let stream = try await client.streamGenerateContent(
            request: makeRequest(),
            model: "gemini-2.5-flash",
            endpoint: endpoint,
            credential: reference
        )
        let result = drain(stream)

        XCTAssertEqual(result.error as? ProviderTransportError, .networkFailure)
        XCTAssertTrue(result.events.isEmpty)
    }

    func testStreamGenerateContent_PropagatesACredentialFailure() async throws {
        let transport = FakeTransport()
        let emptyStorage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let client = GeminiClient(transport: transport, credentialStorage: emptyStorage)

        do {
            _ = try await client.streamGenerateContent(
                request: makeRequest(),
                model: "gemini-2.5-flash",
                endpoint: endpoint,
                credential: CredentialReference()
            )
            XCTFail("Expected a credential error")
        } catch is CredentialStorageError {
            // expected
        }
    }

    // MARK: - Models

    func testModels_ConstructsAnAuthenticatedGETRequest() async throws {
        let transport = FakeTransport(sendResult: .success(Data("{\"models\":[]}".utf8)))
        let (storage, reference) = try await storedCredential()
        let client = GeminiClient(transport: transport, credentialStorage: storage)

        _ = try await client.models(endpoint: endpoint, credential: reference)

        let httpRequest = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(
            httpRequest.url.absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/models"
        )
        XCTAssertEqual(httpRequest.method, "GET")
        XCTAssertEqual(httpRequest.headers["x-goog-api-key"], secret)
        XCTAssertNil(httpRequest.body)
    }

    func testModels_StripsTheModelsPrefixSortsAndDeduplicates() async throws {
        let payload = Data(
            """
            {"models":[{"name":"models/z-model"},{"name":"models/a-model"},{"name":"models/a-model"},{"name":""},{"name":"models/b-model"}]}
            """.utf8
        )
        let transport = FakeTransport(sendResult: .success(payload))
        let (storage, reference) = try await storedCredential()
        let client = GeminiClient(transport: transport, credentialStorage: storage)

        let models = try await client.models(endpoint: endpoint, credential: reference)

        XCTAssertEqual(models.map(\.name), ["a-model", "b-model", "z-model"])
    }

    func testModels_TrimsWhitespaceAlongsideTheModelsPrefix() async throws {
        let payload = Data(
            """
            {"models":[{"name":"models/ gemini-2.5-flash "},{"name":"  gemini-2.5-pro"},{"name":"models/"}]}
            """.utf8
        )
        let transport = FakeTransport(sendResult: .success(payload))
        let (storage, reference) = try await storedCredential()
        let client = GeminiClient(transport: transport, credentialStorage: storage)

        let models = try await client.models(endpoint: endpoint, credential: reference)

        XCTAssertEqual(models.map(\.name), ["gemini-2.5-flash", "gemini-2.5-pro"])
    }

    func testModels_TranslatesAnUndecodableBodyToInvalidResponse() async throws {
        let transport = FakeTransport(sendResult: .success(Data("{ not json }".utf8)))
        let (storage, reference) = try await storedCredential()
        let client = GeminiClient(transport: transport, credentialStorage: storage)

        do {
            _ = try await client.models(endpoint: endpoint, credential: reference)
            XCTFail("Expected invalidResponse")
        } catch let error as ProviderTransportError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    // MARK: - Availability probe

    func testProbeAvailability_ReportsTrueWhenModelsAnswers() async throws {
        let transport = FakeTransport(sendResult: .success(Data("{\"models\":[]}".utf8)))
        let (storage, reference) = try await storedCredential()
        let client = GeminiClient(transport: transport, credentialStorage: storage)

        let available = await client.probeAvailability(endpoint: endpoint, credential: reference)

        XCTAssertTrue(available)
    }

    func testProbeAvailability_ReportsFalseOnTransportFailure() async throws {
        let transport = FakeTransport(sendResult: .failure(.httpStatus(401)))
        let (storage, reference) = try await storedCredential()
        let client = GeminiClient(transport: transport, credentialStorage: storage)

        let available = await client.probeAvailability(endpoint: endpoint, credential: reference)

        XCTAssertFalse(available)
    }

    func testProbeAvailability_ReportsFalseOnMissingCredential() async throws {
        let transport = FakeTransport()
        let emptyStorage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let client = GeminiClient(transport: transport, credentialStorage: emptyStorage)

        let available = await client.probeAvailability(
            endpoint: endpoint,
            credential: CredentialReference()
        )

        XCTAssertFalse(available)
    }
}
