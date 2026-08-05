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

    private let endpoint = URL(string: "https://api.example.com/v1")!

    private func makeAdapter(
        transport: FakeTransport,
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

        XCTAssertNotNil(adapter as? any TextGenerationContract)
        XCTAssertNil(adapter as? any ConversationContract)
        XCTAssertNil(adapter as? any StreamingContract)
    }

    func testPublicInitializer_ClaimsOnlyTheCapabilitiesItDelivers() {
        let storage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let adapter = OpenAICompatibleProviderAdapter(
            endpoint: endpoint,
            credential: CredentialReference(),
            credentialStorage: storage
        )

        XCTAssertNotNil(adapter as? any TextGenerationContract)
        XCTAssertNil(adapter as? any ConversationContract)
        XCTAssertNil(adapter as? any StreamingContract)
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
        let transport = FakeTransport(sendResult: .success(Data("[]".utf8)))
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

    func testGenerateText_SurfacesProviderUnavailableOnHttpStatus() async throws {
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
            XCTFail("Expected CapabilityError.providerUnavailable")
        } catch CapabilityError.providerUnavailable {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGenerateText_SurfacesProviderUnavailableOnNetworkFailure() async throws {
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
            XCTFail("Expected CapabilityError.providerUnavailable")
        } catch CapabilityError.providerUnavailable {
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
        let transport = FakeTransport(sendResult: .success(Data("[]".utf8)))
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
}
