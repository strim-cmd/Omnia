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

    // MARK: - Capability contract conformance

    func testAdapter_ConformsToTheRealizedCapabilityContracts() async throws {
        let (adapter, _) = try await makeAdapter(transport: FakeTransport())

        let textGeneration: any TextGenerationContract = adapter
        let conversation: any ConversationContract = adapter
        let streaming: any StreamingContract = adapter

        XCTAssertTrue(type(of: textGeneration) == OpenAICompatibleProviderAdapter.self)
        XCTAssertTrue(type(of: conversation) == OpenAICompatibleProviderAdapter.self)
        XCTAssertTrue(type(of: streaming) == OpenAICompatibleProviderAdapter.self)
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
}
