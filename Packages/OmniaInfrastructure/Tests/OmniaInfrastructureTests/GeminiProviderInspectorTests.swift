import Foundation
import XCTest
import OmniaDomain
@testable import OmniaInfrastructure

final class GeminiProviderInspectorTests: XCTestCase {

    // MARK: - Test doubles

    private final class FakeTransport: ProviderTransport, @unchecked Sendable {
        private let lock = NSLock()
        private var recordedRequests: [ProviderHTTPRequest] = []
        let sendResult: Result<Data, ProviderTransportError>

        init(sendResult: Result<Data, ProviderTransportError> = .success(Data())) {
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
            AsyncThrowingStream { continuation in
                continuation.finish()
            }
        }
    }

    // MARK: - Fixtures

    private let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta")!
    private let secret = "gemini-inspector-secret"

    private func storedCredential() async throws -> (SecureCredentialStorage, CredentialReference) {
        let storage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let reference = CredentialReference()
        try await storage.store(Credential(secret: secret), for: reference)
        return (storage, reference)
    }

    private func catalogPayload(names: [String]) -> Data {
        let models = names.map { "{\"name\":\"models/\($0)\"}" }.joined(separator: ",")
        return Data("{\"models\":[\(models)]}".utf8)
    }

    private func makeInspector(
        transport: FakeTransport,
        storage: SecureCredentialStorage,
        reference: CredentialReference
    ) -> GeminiProviderInspector {
        GeminiProviderInspector(
            client: GeminiClient(transport: transport, credentialStorage: storage),
            endpoint: endpoint,
            credential: reference
        )
    }

    // MARK: - Discovery

    func testDiscoverModels_ReturnsTheProviderCatalogSorted() async throws {
        let transport = FakeTransport(sendResult: .success(catalogPayload(names: ["z-model", "a-model", "b-model"])))
        let (storage, reference) = try await storedCredential()
        let inspector = makeInspector(transport: transport, storage: storage, reference: reference)

        let models = try await inspector.discoverModels()

        XCTAssertEqual(models.map(\.name), ["a-model", "b-model", "z-model"])
        let httpRequest = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(httpRequest.method, "GET")
        XCTAssertEqual(httpRequest.headers["x-goog-api-key"], secret)
        XCTAssertFalse(httpRequest.url.absoluteString.contains(secret))
    }

    func testDiscoverModels_MapsTransportEvidenceToCatalogErrors() async throws {
        let cases: [(ProviderTransportError, ModelCatalogError)] = [
            (.networkFailure, .unreachable),
            (.timedOut, .timedOut),
            (.httpStatus(401), .unauthorized),
            (.httpStatus(403), .unauthorized),
            (.httpStatus(429), .rateLimited),
            (.httpStatus(500), .serverFailure),
            (.httpStatus(404), .unsupported),
            (.invalidResponse, .invalidResponse),
        ]
        for (transportError, expected) in cases {
            let transport = FakeTransport(sendResult: .failure(transportError))
            let (storage, reference) = try await storedCredential()
            let inspector = makeInspector(transport: transport, storage: storage, reference: reference)

            do {
                _ = try await inspector.discoverModels()
                XCTFail("Expected \(expected) for \(transportError)")
            } catch let error as ModelCatalogError {
                XCTAssertEqual(error, expected)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testDiscoverModels_MapsACredentialFailureToUnauthorized() async throws {
        let transport = FakeTransport(sendResult: .success(catalogPayload(names: ["a-model"])))
        let emptyStorage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let inspector = makeInspector(
            transport: transport,
            storage: emptyStorage,
            reference: CredentialReference()
        )

        do {
            _ = try await inspector.discoverModels()
            XCTFail("Expected unauthorized")
        } catch let error as ModelCatalogError {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    // MARK: - Connection test

    func testTestConnection_SucceedsWhenTheRecordedModelIsOffered() async throws {
        let transport = FakeTransport(sendResult: .success(catalogPayload(names: ["gemini-2.5-flash", "gemini-2.5-pro"])))
        let (storage, reference) = try await storedCredential()
        let inspector = makeInspector(transport: transport, storage: storage, reference: reference)

        let models = try await inspector.testConnection(model: ModelReference(name: "gemini-2.5-flash"))

        XCTAssertEqual(models.map(\.name), ["gemini-2.5-flash", "gemini-2.5-pro"])
    }

    func testTestConnection_RejectsARecordedModelTheEndpointDoesNotOffer() async throws {
        let transport = FakeTransport(sendResult: .success(catalogPayload(names: ["gemini-2.5-flash"])))
        let (storage, reference) = try await storedCredential()
        let inspector = makeInspector(transport: transport, storage: storage, reference: reference)

        do {
            _ = try await inspector.testConnection(model: ModelReference(name: "gemini-3"))
            XCTFail("Expected modelUnavailable")
        } catch let error as ProviderConnectionTestError {
            XCTAssertEqual(error, .modelUnavailable)
        }
    }

    func testTestConnection_MapsTransportEvidenceToConnectionErrors() async throws {
        let cases: [(ProviderTransportError, ProviderConnectionTestError)] = [
            (.networkFailure, .unreachable),
            (.timedOut, .timedOut),
            (.httpStatus(401), .invalidCredential),
            (.httpStatus(403), .invalidCredential),
            (.httpStatus(429), .rateLimited),
            (.httpStatus(500), .serverFailure),
            (.httpStatus(404), .invalidEndpoint),
            (.invalidResponse, .invalidResponse),
            (.invalidRequest, .invalidEndpoint),
        ]
        for (transportError, expected) in cases {
            let transport = FakeTransport(sendResult: .failure(transportError))
            let (storage, reference) = try await storedCredential()
            let inspector = makeInspector(transport: transport, storage: storage, reference: reference)

            do {
                _ = try await inspector.testConnection(model: nil)
                XCTFail("Expected \(expected) for \(transportError)")
            } catch let error as ProviderConnectionTestError {
                XCTAssertEqual(error, expected)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testTestConnection_MapsACredentialFailureToInvalidCredential() async throws {
        let transport = FakeTransport(sendResult: .success(catalogPayload(names: ["gemini-2.5-flash"])))
        let emptyStorage = SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
        let inspector = makeInspector(
            transport: transport,
            storage: emptyStorage,
            reference: CredentialReference()
        )

        do {
            _ = try await inspector.testConnection(model: nil)
            XCTFail("Expected invalidCredential")
        } catch let error as ProviderConnectionTestError {
            XCTAssertEqual(error, .invalidCredential)
        }
    }
}
