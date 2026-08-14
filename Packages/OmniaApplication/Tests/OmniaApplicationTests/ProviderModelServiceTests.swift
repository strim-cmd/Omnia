import Foundation
import OmniaDomain
import OmniaFoundation
import XCTest
@testable import OmniaApplication

private final class ModelConfigurationRepository: ConfigurationRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ConfigurationLevel: [String: Any]] = [:]

    func store<Value: Equatable & Sendable>(
        _ value: Value,
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        lock.withLock { storage[level, default: [:]][slot(key, Value.self)] = value }
    }

    func value<Value: Equatable & Sendable>(
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws -> Value? {
        lock.withLock { storage[level]?[slot(key, Value.self)] as? Value }
    }

    func remove<Value: Equatable & Sendable>(
        _ key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        lock.withLock { storage[level]?[slot(key, Value.self)] = nil }
    }

    private func slot<Value>(_ key: ConfigurationKey<Value>, _ type: Value.Type) -> String {
        "\(key.name)\u{0}\(ObjectIdentifier(type))"
    }
}

private actor ModelDiscoveryScript {
    enum Outcome: Sendable {
        case models([ModelReference])
        case failure(ModelCatalogError)
    }

    private var outcome: Outcome
    private(set) var calls = 0

    init(_ outcome: Outcome) {
        self.outcome = outcome
    }

    func set(_ outcome: Outcome) {
        self.outcome = outcome
    }

    func run(_ provider: ProviderIdentity) throws -> [ModelReference] {
        calls += 1
        switch outcome {
        case .models(let models): return models
        case .failure(let error): throw error
        }
    }
}

final class ProviderModelServiceTests: XCTestCase {
    private let provider = ProviderIdentity()

    private func readyLifecycle(_ identity: ProviderIdentity) async throws -> ProviderLifecycleService {
        let lifecycle = ProviderLifecycleService()
        await lifecycle.register(
            ProviderConnection(
                identity: identity,
                capabilities: ProviderCapabilities(capabilities: [.streaming, .vision, .documentInput]),
                metadata: ProviderMetadata(displayName: "Provider"),
                limits: ProviderLimits(maxRequestsPerMinute: nil),
                version: SemanticVersion(major: 1, minor: 0, patch: 0)
            )
        )
        try await lifecycle.transition(identity, to: .validated)
        try await lifecycle.transition(identity, to: .initializing)
        try await lifecycle.transition(identity, to: .ready)
        return lifecycle
    }

    private func makeService(
        repository: ModelConfigurationRepository,
        lifecycle: ProviderLifecycleService,
        fallback: ModelReference? = nil,
        script: ModelDiscoveryScript
    ) -> ProviderModelService {
        ProviderModelService(
            configurationService: ConfigurationService(
                configurationRepository: repository,
                resolutionPolicy: ConfigurationResolutionPolicy()
            ),
            lifecycleService: lifecycle,
            configuredModel: { _ in fallback },
            discoverModels: { try await script.run($0) }
        )
    }

    func testRefreshNormalizesCachesAndPreservesModelsAsStaleOffline() async throws {
        let repository = ModelConfigurationRepository()
        let lifecycle = try await readyLifecycle(provider)
        let script = ModelDiscoveryScript(.models([
            ModelReference(name: "z-model"),
            ModelReference(name: "a-model"),
            ModelReference(name: "a-model"),
        ]))
        let service = makeService(
            repository: repository,
            lifecycle: lifecycle,
            fallback: ModelReference(name: "manual-model"),
            script: script
        )

        let loaded = try await service.refreshCatalog(for: provider)
        XCTAssertEqual(loaded.status, .loaded)
        XCTAssertEqual(
            loaded.models.map(\.selection.model.name),
            ["a-model", "z-model", "manual-model"]
        )

        await script.set(.failure(.unreachable))
        let stale = try await service.refreshCatalog(for: provider)
        XCTAssertEqual(stale.status, .stale(.unreachable))
        XCTAssertEqual(stale.models.map(\.selection.model.name), loaded.models.map(\.selection.model.name))
    }

    func testUnsupportedDiscoveryKeepsConfiguredFallback() async throws {
        let repository = ModelConfigurationRepository()
        let lifecycle = try await readyLifecycle(provider)
        let service = makeService(
            repository: repository,
            lifecycle: lifecycle,
            fallback: ModelReference(name: "manual/model"),
            script: ModelDiscoveryScript(.failure(.unsupported))
        )

        let catalog = try await service.refreshCatalog(for: provider)

        XCTAssertEqual(catalog.status, .unavailable(.unsupported))
        XCTAssertEqual(catalog.models.map(\.selection.model.name), ["manual/model"])
        XCTAssertEqual(catalog.models.first?.source, .configuredFallback)
    }

    func testEmptyDiscoveryIsExplicit() async throws {
        let service = makeService(
            repository: ModelConfigurationRepository(),
            lifecycle: try await readyLifecycle(provider),
            script: ModelDiscoveryScript(.models([]))
        )
        let catalog = try await service.refreshCatalog(for: provider)
        XCTAssertEqual(catalog.status, .empty)
        XCTAssertTrue(catalog.models.isEmpty)
    }

    func testDefaultSelectionPersistsAndOnlyValidDefaultIsInherited() async throws {
        let repository = ModelConfigurationRepository()
        let lifecycle = try await readyLifecycle(provider)
        let model = ModelReference(name: "model")
        let script = ModelDiscoveryScript(.models([model]))
        let service = makeService(repository: repository, lifecycle: lifecycle, script: script)
        _ = try await service.refreshCatalog(for: provider)
        let selection = ProviderModelSelection(provider: provider, model: model)

        try await service.setDefaultSelection(selection)

        let reloaded = makeService(repository: repository, lifecycle: lifecycle, script: script)
        let storedDefault = try await reloaded.defaultSelection()
        let validDefault = try await reloaded.validDefaultSelection()
        XCTAssertEqual(storedDefault, selection)
        XCTAssertEqual(validDefault, selection)
    }

    func testUnavailableDefaultIsRejectedWithoutFallback() async throws {
        let repository = ModelConfigurationRepository()
        let lifecycle = try await readyLifecycle(provider)
        let service = makeService(
            repository: repository,
            lifecycle: lifecycle,
            script: ModelDiscoveryScript(.models([ModelReference(name: "available")]))
        )
        _ = try await service.refreshCatalog(for: provider)
        let missing = ProviderModelSelection(
            provider: provider,
            model: ModelReference(name: "missing")
        )

        do {
            try await service.setDefaultSelection(missing)
            XCTFail("Expected modelUnavailable")
        } catch let error as CapabilityError {
            XCTAssertEqual(error, .modelUnavailable(model: missing.model))
        }
        let storedDefault = try await service.defaultSelection()
        XCTAssertNil(storedDefault)
    }

    func testCapabilitiesStayConservativeAndOverridesPersistSeparately() async throws {
        let repository = ModelConfigurationRepository()
        let lifecycle = try await readyLifecycle(provider)
        let model = ModelReference(name: "vendor/model Ю")
        let script = ModelDiscoveryScript(.models([model]))
        let service = makeService(repository: repository, lifecycle: lifecycle, script: script)
        _ = try await service.refreshCatalog(for: provider)
        let selection = ProviderModelSelection(provider: provider, model: model)
        let providerCapabilities = ProviderCapabilities(
            capabilities: [.streaming, .vision, .documentInput]
        )

        let initialVision = try await service.effectiveSupport(
            for: .vision,
            selection: selection,
            providerCapabilities: providerCapabilities
        )
        let initialDocument = try await service.effectiveSupport(
            for: .documentInput,
            selection: selection,
            providerCapabilities: providerCapabilities
        )
        XCTAssertEqual(initialVision, .unknown)
        XCTAssertEqual(initialDocument, .unknown)

        let profile = ModelCapabilityProfile(
            supported: [.vision],
            unsupported: [.documentInput]
        )
        try await service.setCapabilityOverride(profile, for: selection)
        let reloaded = makeService(repository: repository, lifecycle: lifecycle, script: script)
        let reloadedVision = try await reloaded.effectiveSupport(
            for: .vision,
            selection: selection,
            providerCapabilities: providerCapabilities
        )
        let reloadedDocument = try await reloaded.effectiveSupport(
            for: .documentInput,
            selection: selection,
            providerCapabilities: providerCapabilities
        )
        XCTAssertEqual(reloadedVision, .supported)
        XCTAssertEqual(reloadedDocument, .unsupported)
        let key = ProviderModelService.capabilityOverrideKey(for: selection).name
        XCTAssertFalse(key.contains("/"))
        XCTAssertFalse(key.contains("Ю"))
    }
}

final class ProviderValidationServiceTests: XCTestCase {
    func testCandidateSuccessReturnsDiscoveredModels() async throws {
        let expected = [ModelReference(name: "one"), ModelReference(name: "two")]
        let service = ProviderValidationService(
            testCandidate: { _, _, model in
                XCTAssertEqual(model, ModelReference(name: "one"))
                return expected
            },
            testExisting: { _, _, _ in XCTFail("Wrong path"); return [] }
        )

        let result = try await service.test(
            ProviderConnectionTestRequest(
                endpoint: " https://api.example.com/v1 ",
                model: " one ",
                credential: Credential(secret: "test-secret")
            )
        )

        XCTAssertEqual(result.models, expected)
    }

    func testExistingConnectionUsesStoredCredentialPath() async throws {
        let provider = ProviderIdentity()
        let service = ProviderValidationService(
            testCandidate: { _, _, _ in XCTFail("Wrong path"); return [] },
            testExisting: { identity, endpoint, _ in
                XCTAssertEqual(identity, provider)
                XCTAssertEqual(endpoint.absoluteString, "https://api.example.com/v1")
                return [ModelReference(name: "model")]
            }
        )
        let result = try await service.test(
            ProviderConnectionTestRequest(
                provider: provider,
                endpoint: "https://api.example.com/v1"
            )
        )
        XCTAssertEqual(result.models, [ModelReference(name: "model")])
    }

    func testInvalidEndpointAndMissingCandidateCredentialAreTyped() async {
        let service = ProviderValidationService(
            testCandidate: { _, _, _ in [] },
            testExisting: { _, _, _ in [] }
        )
        await assertTestError(.invalidEndpoint) {
            _ = try await service.test(ProviderConnectionTestRequest(endpoint: "not a URL"))
        }
        await assertTestError(.invalidCredential) {
            _ = try await service.test(
                ProviderConnectionTestRequest(endpoint: "https://api.example.com/v1")
            )
        }
    }

    func testTypedTransportEvidencePassesThroughAndNeverContainsCredential() async {
        let failures: [ProviderConnectionTestError] = [
            .invalidCredential, .unreachable, .invalidEndpoint, .modelUnavailable,
            .rateLimited, .timedOut, .serverFailure, .invalidResponse,
        ]
        for expected in failures {
            let service = ProviderValidationService(
                testCandidate: { _, _, _ in throw expected },
                testExisting: { _, _, _ in throw expected }
            )
            await assertTestError(expected) {
                _ = try await service.test(
                    ProviderConnectionTestRequest(
                        endpoint: "https://api.example.com/v1",
                        credential: Credential(secret: "never-leak-this")
                    )
                )
            }
            XCTAssertFalse(String(describing: expected).contains("never-leak-this"))
        }
    }

    private func assertTestError(
        _ expected: ProviderConnectionTestError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expected)")
        } catch let error as ProviderConnectionTestError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
