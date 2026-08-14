import Foundation
import OmniaApplication
import OmniaFoundation
import XCTest
@testable import OmniaPresentation

private let secretValue = "sk-provider-secret-that-must-never-leak"

private func request(
    displayName: String = "Example Provider",
    capabilities: ProviderCapabilities = ProviderCapabilities(
        capabilities: [.textGeneration, .conversation]
    ),
    limits: ProviderLimits = ProviderLimits(maxRequestsPerMinute: 60),
    version: SemanticVersion = SemanticVersion(major: 1, minor: 0, patch: 0),
    credential: Credential = Credential(secret: secretValue)
) -> ConfigureProviderRequest {
    ConfigureProviderRequest(
        displayName: displayName,
        capabilities: capabilities,
        limits: limits,
        version: version,
        credential: credential
    )
}

private final class InMemoryProviderRepository: ProviderRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ProviderIdentity: Provider] = [:]

    func save(_ provider: Provider) async throws {
        lock.withLock {
            storage[provider.identity] = provider
        }
    }

    func provider(with identity: ProviderIdentity) async throws -> Provider? {
        lock.withLock {
            storage[identity]
        }
    }

    func allProviders() async throws -> [Provider] {
        lock.withLock {
            Array(storage.values)
        }
    }

    func delete(_ identity: ProviderIdentity) async throws {
        lock.withLock {
            storage[identity] = nil
        }
    }
}

private final class FailingProviderRepository: ProviderRepository, @unchecked Sendable {
    func save(_ provider: Provider) async throws {
        throw RepositoryError.storageUnavailable
    }

    func provider(with identity: ProviderIdentity) async throws -> Provider? {
        throw RepositoryError.storageUnavailable
    }

    func allProviders() async throws -> [Provider] {
        throw RepositoryError.storageUnavailable
    }

    func delete(_ identity: ProviderIdentity) async throws {
        throw RepositoryError.storageUnavailable
    }
}

private final class DeleteFailingProviderRepository: ProviderRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ProviderIdentity: Provider] = [:]

    func save(_ provider: Provider) async throws {
        lock.withLock {
            storage[provider.identity] = provider
        }
    }

    func provider(with identity: ProviderIdentity) async throws -> Provider? {
        lock.withLock {
            storage[identity]
        }
    }

    func allProviders() async throws -> [Provider] {
        lock.withLock {
            Array(storage.values)
        }
    }

    func delete(_ identity: ProviderIdentity) async throws {
        throw RepositoryError.storageUnavailable
    }
}

private final class InMemoryCredentialStorage: CredentialStorageProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [CredentialReference: Credential] = [:]

    func store(_ credential: Credential, for reference: CredentialReference) async throws {
        lock.withLock {
            storage[reference] = credential
        }
    }

    func credential(for reference: CredentialReference) async throws -> Credential {
        guard let credential = lock.withLock({ storage[reference] }) else {
            throw CredentialStorageError.credentialNotFound
        }
        return credential
    }

    func removeCredential(for reference: CredentialReference) async throws {
        lock.withLock {
            storage[reference] = nil
        }
    }
}

private final class FailingCredentialStorage: CredentialStorageProtocol, @unchecked Sendable {
    func store(_ credential: Credential, for reference: CredentialReference) async throws {
        throw CredentialStorageError.storageUnavailable
    }

    func credential(for reference: CredentialReference) async throws -> Credential {
        throw CredentialStorageError.credentialNotFound
    }

    func removeCredential(for reference: CredentialReference) async throws {
        throw CredentialStorageError.storageUnavailable
    }
}

private final class RemoveFailingCredentialStorage: CredentialStorageProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [CredentialReference: Credential] = [:]

    func store(_ credential: Credential, for reference: CredentialReference) async throws {
        lock.withLock {
            storage[reference] = credential
        }
    }

    func credential(for reference: CredentialReference) async throws -> Credential {
        guard let credential = lock.withLock({ storage[reference] }) else {
            throw CredentialStorageError.credentialNotFound
        }
        return credential
    }

    func removeCredential(for reference: CredentialReference) async throws {
        throw CredentialStorageError.storageUnavailable
    }
}

private final class InMemoryConfigurationRepository: ConfigurationRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ConfigurationLevel: [String: Any]] = [:]

    func store<Value: Equatable & Sendable>(
        _ value: Value,
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        let slot = Self.slot(for: key, as: Value.self)
        lock.withLock {
            storage[level, default: [:]][slot] = value
        }
    }

    func value<Value: Equatable & Sendable>(
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws -> Value? {
        let slot = Self.slot(for: key, as: Value.self)
        return lock.withLock {
            storage[level]?[slot] as? Value
        }
    }

    func remove<Value: Equatable & Sendable>(
        _ key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        let slot = Self.slot(for: key, as: Value.self)
        lock.withLock {
            storage[level]?[slot] = nil
        }
    }

    private static func slot<Value>(for key: ConfigurationKey<Value>, as type: Value.Type) -> String {
        "\(key.name)\u{0}\(ObjectIdentifier(type))"
    }
}

private final class FailingConfigurationRepository: ConfigurationRepository, @unchecked Sendable {
    func store<Value: Equatable & Sendable>(
        _ value: Value,
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        throw RepositoryError.storageUnavailable
    }

    func value<Value: Equatable & Sendable>(
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws -> Value? {
        throw RepositoryError.storageUnavailable
    }

    func remove<Value: Equatable & Sendable>(
        _ key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        throw RepositoryError.storageUnavailable
    }
}

private func makeSurface(
    providerRepository: some ProviderRepository,
    credentialStorage: some CredentialStorageProtocol,
    configurationRepository: some ConfigurationRepository
) -> SettingsSurface {
    SettingsSurface(
        connectionService: ProviderConnectionService(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository,
            lifecycleService: ProviderLifecycleService()
        ),
        configurationService: ConfigurationService(
            configurationRepository: configurationRepository,
            resolutionPolicy: ConfigurationResolutionPolicy()
        )
    )
}

private func makeProductionSurface(
    providerRepository: some ProviderRepository,
    credentialStorage: some CredentialStorageProtocol,
    configurationRepository: some ConfigurationRepository,
    validationService: ProviderValidationService,
    dataManagementService: DataManagementService? = nil
) -> SettingsSurface {
    let lifecycleService = ProviderLifecycleService()
    let configurationService = ConfigurationService(
        configurationRepository: configurationRepository,
        resolutionPolicy: ConfigurationResolutionPolicy()
    )
    return SettingsSurface(
        connectionService: ProviderConnectionService(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository,
            lifecycleService: lifecycleService
        ),
        configurationService: configurationService,
        modelService: ProviderModelService(
            configurationService: configurationService,
            lifecycleService: lifecycleService,
            configuredModel: { identity in
                try await configurationService.value(
                    for: ProviderConnectionService.modelKey(for: identity),
                    at: .providerSettings
                ).map(ModelReference.init(name:))
            },
            discoverModels: { _ in [] }
        ),
        validationService: validationService,
        dataManagementService: dataManagementService
    )
}

private actor ClearDataProbe {
    private(set) var count = 0
    func record() { count += 1 }
}

private func provider(
    identity: ProviderIdentity,
    displayName: String = "Example Provider"
) -> Provider {
    Provider(
        connection: ProviderConnection(
            identity: identity,
            capabilities: ProviderCapabilities(capabilities: [.textGeneration, .conversation]),
            metadata: ProviderMetadata(displayName: displayName),
            limits: ProviderLimits(maxRequestsPerMinute: 60),
            version: SemanticVersion(major: 1, minor: 0, patch: 0)
        )
    )
}

final class SettingsSurfaceTests: XCTestCase {

    func testClearData_InvokesTheComposedDestructiveCapability() async throws {
        let probe = ClearDataProbe()
        let surface = makeProductionSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository(),
            validationService: ProviderValidationService(
                testCandidate: { _, _, _ in [] },
                testExisting: { _, _, _ in [] }
            ),
            dataManagementService: DataManagementService {
                await probe.record()
            }
        )

        try await surface.clearData()

        let count = await probe.count
        XCTAssertEqual(count, 1)
    }

    private let modelKey = ConfigurationKey<String>("model")

    // MARK: Load — provider connections

    func testLoad_RendersConfiguredConnectionsInIdentityOrder() async throws {
        let providerRepository = InMemoryProviderRepository()
        let credentialStorage = InMemoryCredentialStorage()
        let configurationRepository = InMemoryConfigurationRepository()
        let identities = [
            try XCTUnwrap(ProviderIdentity(restoring: "550E8400-E29B-41D4-A716-446655440002")),
            try XCTUnwrap(ProviderIdentity(restoring: "550E8400-E29B-41D4-A716-446655440000")),
            try XCTUnwrap(ProviderIdentity(restoring: "550E8400-E29B-41D4-A716-446655440001")),
        ]
        for identity in identities {
            try await providerRepository.save(provider(identity: identity))
        }

        let surface = makeSurface(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository
        )
        let state = try await surface.load()

        let expectedOrder = identities.sorted { $0.canonicalString < $1.canonicalString }
        XCTAssertEqual(state.connections.map(\.identity), expectedOrder)
        XCTAssertEqual(state.connections.map(\.displayName), ["Example Provider", "Example Provider", "Example Provider"])
        XCTAssertTrue(state.connections.allSatisfy { $0.state == .registered })
    }

    func testLoad_EmptyWhenNothingIsConfigured() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        let state = try await surface.load()
        XCTAssertTrue(state.connections.isEmpty)
        XCTAssertTrue(state.configuration.isEmpty)
        XCTAssertFalse(state.hasError)
    }

    func testLoadModelCatalogsLoadingPreservesManualModelsAndReportsLoading() async throws {
        let providerRepository = InMemoryProviderRepository()
        let credentialStorage = InMemoryCredentialStorage()
        let configurationRepository = InMemoryConfigurationRepository()
        let legacySurface = makeSurface(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository
        )
        let connection = try await legacySurface.configure(
            request(),
            endpoint: "https://api.example.com/v1",
            model: "manual-model"
        )
        let surface = makeProductionSurface(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository,
            validationService: ProviderValidationService(
                testCandidate: { _, _, _ in [] },
                testExisting: { _, _, _ in [] }
            )
        )

        let state = try await surface.loadModelCatalogsLoading()

        XCTAssertEqual(state.modelCatalogs.count, 1)
        XCTAssertEqual(state.modelCatalogs.first?.provider, connection.identity)
        XCTAssertEqual(state.modelCatalogs.first?.status, .loading)
        XCTAssertEqual(
            state.modelCatalogs.first?.models.map(\.selection.model.name),
            ["manual-model"]
        )
    }

    // MARK: Load — configuration

    func testLoad_RendersResolvedConfigurationValues() async throws {
        let configurationRepository = InMemoryConfigurationRepository()
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: configurationRepository
        )
        try await configurationRepository.store("provider-model", for: modelKey, at: .providerSettings)
        try await configurationRepository.store("global-model", for: modelKey, at: .globalDefault)

        let state = try await surface.load(configurationKeys: [modelKey])

        XCTAssertEqual(state.configuration, [SettingsState.ConfigurationItem(key: modelKey, value: "provider-model")])
    }

    func testLoad_OmitsConfigurationKeysNoLevelSets() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        let state = try await surface.load(configurationKeys: [modelKey])
        XCTAssertTrue(state.configuration.isEmpty)
    }

    func testLoad_NoConfigurationKeysPresentsNoConfigurationItems() async throws {
        let configurationRepository = InMemoryConfigurationRepository()
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: configurationRepository
        )
        try await configurationRepository.store("gpt-4o", for: modelKey, at: .globalDefault)

        let state = try await surface.load()

        XCTAssertTrue(state.configuration.isEmpty)
        let loaded = try await surface.value(for: modelKey, at: .globalDefault)
        XCTAssertEqual(loaded, "gpt-4o")
    }

    // MARK: Load — failures surface as-is

    func testLoad_ProviderRepositoryFailureSurfacesAsRepositoryError() async {
        let surface = makeSurface(
            providerRepository: FailingProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        do {
            _ = try await surface.load()
            XCTFail("Expected RepositoryError.storageUnavailable")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .storageUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLoad_ConfigurationRepositoryFailureSurfacesAsRepositoryError() async {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: FailingConfigurationRepository()
        )
        do {
            _ = try await surface.load(configurationKeys: [modelKey])
            XCTFail("Expected RepositoryError.storageUnavailable")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .storageUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: Configure

    func testConfigure_ReturnsConnectionWithDeclaredContentAndPersistsIt() async throws {
        let providerRepository = InMemoryProviderRepository()
        let credentialStorage = InMemoryCredentialStorage()
        let configurationRepository = InMemoryConfigurationRepository()
        let surface = makeSurface(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository
        )

        let connection = try await surface.configure(request())

        XCTAssertNotEqual(connection.identity, ProviderIdentity())
        XCTAssertEqual(connection.metadata, ProviderMetadata(displayName: "Example Provider"))
        XCTAssertEqual(connection.capabilities, ProviderCapabilities(capabilities: [.textGeneration, .conversation]))
        XCTAssertEqual(connection.limits, ProviderLimits(maxRequestsPerMinute: 60))
        XCTAssertEqual(connection.version, SemanticVersion(major: 1, minor: 0, patch: 0))
        let stored = try await providerRepository.provider(with: connection.identity)
        XCTAssertEqual(stored?.connection, connection)
    }

    func testConfigure_ValidationFailureSurfacesAsApplicationValidationError() async {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        do {
            _ = try await surface.configure(request(displayName: ""))
            XCTFail("Expected ApplicationValidationError")
        } catch let error as ApplicationValidationError {
            XCTAssertEqual(error, .invalid(reason: "The display name is empty."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testConfigure_CredentialStorageFailureSurfacesAsCredentialStorageError() async {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: FailingCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        do {
            _ = try await surface.configure(request())
            XCTFail("Expected CredentialStorageError")
        } catch let error as CredentialStorageError {
            XCTAssertEqual(error, .storageUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: Configure — the credential boundary

    func testConfigure_TheSecretNeverEntersAnyRepresentation() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )

        let connection = try await surface.configure(request())
        let state = try await surface.load()

        XCTAssertFalse(String(describing: request()).contains(secretValue))
        XCTAssertFalse(String(describing: connection).contains(secretValue))
        XCTAssertFalse(String(describing: state).contains(secretValue))
        XCTAssertFalse(String(describing: surface).contains(secretValue))
    }

    func testProductionConfigureValidatesExactCandidateBeforeMarkingReady() async throws {
        let providerRepository = InMemoryProviderRepository()
        let credentialStorage = InMemoryCredentialStorage()
        let configurationRepository = InMemoryConfigurationRepository()
        let expectedModel = ModelReference(name: "gpt-4o")
        let surface = makeProductionSurface(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository,
            validationService: ProviderValidationService(
                testCandidate: { endpoint, credential, model in
                    XCTAssertEqual(endpoint.absoluteString, "https://api.example.com/v1")
                    XCTAssertEqual(model, expectedModel)
                    XCTAssertEqual(credential.withValue { $0 }, secretValue)
                    return [expectedModel]
                },
                testExisting: { _, _, _ in
                    throw ProviderConnectionTestError.invalidResponse
                }
            )
        )

        let connection = try await surface.configure(
            request(),
            endpoint: "https://api.example.com/v1",
            model: expectedModel.name
        )

        let stored = try await providerRepository.provider(with: connection.identity)
        let storedModel = try await surface.model(for: connection.identity)
        XCTAssertEqual(stored?.state, .ready)
        XCTAssertEqual(storedModel, expectedModel.name)
    }

    func testProductionConfigureCachesValidatedDiscoveryBeforeRefresh() async throws {
        let providerRepository = InMemoryProviderRepository()
        let credentialStorage = InMemoryCredentialStorage()
        let configurationRepository = InMemoryConfigurationRepository()
        let validatedModels = [
            ModelReference(name: "model-b"),
            ModelReference(name: "model-a"),
            ModelReference(name: "model-a"),
        ]
        let surface = makeProductionSurface(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository,
            validationService: ProviderValidationService(
                testCandidate: { _, _, model in
                    XCTAssertNil(model)
                    return validatedModels
                },
                testExisting: { _, _, _ in [] }
            )
        )

        let connection = try await surface.configure(
            request(),
            endpoint: "https://api.example.com/v1",
            model: nil
        )
        let loading = try await surface.loadModelCatalogsLoading()
        let catalog = try XCTUnwrap(
            loading.modelCatalogs.first { $0.provider == connection.identity }
        )

        XCTAssertEqual(catalog.status, .loading)
        XCTAssertEqual(catalog.models.map(\.selection.model.name), ["model-a", "model-b"])
    }

    func testProductionConfigureValidationFailureWritesNothing() async throws {
        let providerRepository = InMemoryProviderRepository()
        let surface = makeProductionSurface(
            providerRepository: providerRepository,
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository(),
            validationService: ProviderValidationService(
                testCandidate: { _, _, _ in
                    throw ProviderConnectionTestError.invalidCredential
                },
                testExisting: { _, _, _ in [] }
            )
        )

        do {
            _ = try await surface.configure(
                request(),
                endpoint: "https://api.example.com/v1",
                model: "gpt-4o"
            )
            XCTFail("Expected invalidCredential")
        } catch let error as ProviderConnectionTestError {
            XCTAssertEqual(error, .invalidCredential)
        }
        let storedProviders = try await providerRepository.allProviders()
        XCTAssertTrue(storedProviders.isEmpty)
    }

    func testProductionUpdateValidationFailurePreservesExistingDeclaration() async throws {
        let providerRepository = InMemoryProviderRepository()
        let credentialStorage = InMemoryCredentialStorage()
        let configurationRepository = InMemoryConfigurationRepository()
        let legacySurface = makeSurface(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository
        )
        let connection = try await legacySurface.configure(
            request(),
            endpoint: "https://api.example.com/v1",
            model: "gpt-4o"
        )
        let surface = makeProductionSurface(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository,
            validationService: ProviderValidationService(
                testCandidate: { _, _, _ in [] },
                testExisting: { provider, endpoint, model in
                    XCTAssertEqual(provider, connection.identity)
                    XCTAssertEqual(endpoint.absoluteString, "https://api.changed.example.com/v1")
                    XCTAssertEqual(model?.name, "gpt-5")
                    throw ProviderConnectionTestError.timedOut
                }
            )
        )
        let update = ProviderUpdateRequest(
            displayName: "Changed Provider",
            capabilities: connection.capabilities,
            limits: connection.limits,
            version: connection.version
        )

        do {
            _ = try await surface.update(
                update,
                for: connection.identity,
                endpoint: "https://api.changed.example.com/v1",
                model: "gpt-5"
            )
            XCTFail("Expected timedOut")
        } catch let error as ProviderConnectionTestError {
            XCTAssertEqual(error, .timedOut)
        }

        let stored = try await providerRepository.provider(with: connection.identity)
        let storedEndpoint = try await surface.endpoint(for: connection.identity)
        let storedModel = try await surface.model(for: connection.identity)
        XCTAssertEqual(stored?.connection, connection)
        XCTAssertEqual(storedEndpoint, "https://api.example.com/v1")
        XCTAssertEqual(storedModel, "gpt-4o")
    }

    // MARK: Configure — endpoint collection

    func testConfigureWithEndpoint_RecordsTheEndpointAtProviderSettingsLevel() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )

        let connection = try await surface.configure(
            request(),
            endpoint: "https://api.example.com/v1"
        )

        let recorded = try await surface.value(
            for: ProviderConnectionService.endpointKey(for: connection.identity),
            at: .providerSettings
        )
        XCTAssertEqual(recorded, "https://api.example.com/v1")
    }

    func testConfigureWithEndpoint_InvalidEndpointSurfacesAsApplicationValidationError() async throws {
        let providerRepository = InMemoryProviderRepository()
        let surface = makeSurface(
            providerRepository: providerRepository,
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        do {
            _ = try await surface.configure(request(), endpoint: "api.example.com/v1")
            XCTFail("Expected ApplicationValidationError")
        } catch let error as ApplicationValidationError {
            XCTAssertEqual(
                error,
                .invalid(reason: "The endpoint must be an absolute http or https URL.")
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let state = try await surface.load()
        XCTAssertTrue(state.connections.isEmpty)
    }

    // MARK: Endpoint — update and read (UX audit U7)

    func testEndpoint_ReturnsNilWhenNoEndpointIsRecorded() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        let connection = try await surface.configure(request())
        let endpoint = try await surface.endpoint(for: connection.identity)
        XCTAssertNil(endpoint)
    }

    func testUpdateEndpoint_RecordsTheEndpointAtProviderSettingsLevel() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        let connection = try await surface.configure(request(), endpoint: "https://api.example.com/v1")

        try await surface.updateEndpoint("https://api.updated.example.com/v1", for: connection.identity)

        let endpoint = try await surface.endpoint(for: connection.identity)
        XCTAssertEqual(endpoint, "https://api.updated.example.com/v1")
    }

    func testUpdateEndpoint_ReplacesThePreviouslyRecordedEndpoint() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        let connection = try await surface.configure(request(), endpoint: "https://api.example.com/v1")

        try await surface.updateEndpoint("https://api.updated.example.com/v1", for: connection.identity)
        try await surface.updateEndpoint("https://api.final.example.com/v1", for: connection.identity)

        let endpoint = try await surface.endpoint(for: connection.identity)
        XCTAssertEqual(endpoint, "https://api.final.example.com/v1")
    }

    func testUpdateEndpoint_TrimsWhitespaceAroundTheEndpoint() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        let connection = try await surface.configure(request())

        try await surface.updateEndpoint("  https://api.example.com/v1  ", for: connection.identity)

        let endpoint = try await surface.endpoint(for: connection.identity)
        XCTAssertEqual(endpoint, "https://api.example.com/v1")
    }

    func testUpdateEndpoint_InvalidEndpointSurfacesAsApplicationValidationError() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        let connection = try await surface.configure(request(), endpoint: "https://api.example.com/v1")

        do {
            try await surface.updateEndpoint("api.example.com/v1", for: connection.identity)
            XCTFail("Expected ApplicationValidationError")
        } catch let error as ApplicationValidationError {
            XCTAssertEqual(
                error,
                .invalid(reason: "The endpoint must be an absolute http or https URL.")
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let endpoint = try await surface.endpoint(for: connection.identity)
        XCTAssertEqual(endpoint, "https://api.example.com/v1")
    }

    func testUpdateEndpoint_EmptyEndpointSurfacesAsApplicationValidationError() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        let connection = try await surface.configure(request(), endpoint: "https://api.example.com/v1")

        do {
            try await surface.updateEndpoint("", for: connection.identity)
            XCTFail("Expected ApplicationValidationError")
        } catch let error as ApplicationValidationError {
            XCTAssertEqual(error, .invalid(reason: "The endpoint is empty."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let endpoint = try await surface.endpoint(for: connection.identity)
        XCTAssertEqual(endpoint, "https://api.example.com/v1")
    }

    func testUpdateEndpoint_RepositoryFailureSurfacesAsRepositoryError() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: FailingConfigurationRepository()
        )
        do {
            try await surface.updateEndpoint("https://api.example.com/v1", for: ProviderIdentity())
            XCTFail("Expected RepositoryError")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .storageUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: Configure — model collection

    func testConfigureWithEndpointAndModel_RecordsTheModelAtProviderSettingsLevel() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )

        let connection = try await surface.configure(
            request(),
            endpoint: "https://api.example.com/v1",
            model: "omniroute:gpt-4o"
        )

        let recorded = try await surface.value(
            for: ProviderConnectionService.modelKey(for: connection.identity),
            at: .providerSettings
        )
        XCTAssertEqual(recorded, "omniroute:gpt-4o")
    }

    func testConfigureWithEndpointAndModel_NilModelRecordsNoModel() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )

        let connection = try await surface.configure(
            request(),
            endpoint: "https://api.example.com/v1",
            model: nil
        )

        let model = try await surface.model(for: connection.identity)
        XCTAssertNil(model)
    }

    func testConfigureWithEndpointAndModel_WhitespaceModelSurfacesAsApplicationValidationError() async throws {
        let providerRepository = InMemoryProviderRepository()
        let surface = makeSurface(
            providerRepository: providerRepository,
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        do {
            _ = try await surface.configure(
                request(),
                endpoint: "https://api.example.com/v1",
                model: "   "
            )
            XCTFail("Expected ApplicationValidationError")
        } catch let error as ApplicationValidationError {
            XCTAssertEqual(error, .invalid(reason: "The model is empty."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let state = try await surface.load()
        XCTAssertTrue(state.connections.isEmpty)
    }

    // MARK: Model — update and read

    func testModel_ReturnsNilWhenNoModelIsRecorded() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        let connection = try await surface.configure(request())
        let model = try await surface.model(for: connection.identity)
        XCTAssertNil(model)
    }

    func testUpdateModel_RecordsTheModelAtProviderSettingsLevel() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        let connection = try await surface.configure(request())

        try await surface.updateModel("omniroute:gpt-4o", for: connection.identity)

        let model = try await surface.model(for: connection.identity)
        XCTAssertEqual(model, "omniroute:gpt-4o")
    }

    func testUpdateModel_TrimsWhitespaceAroundTheModel() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        let connection = try await surface.configure(request())

        try await surface.updateModel("  omniroute:gpt-4o  ", for: connection.identity)

        let model = try await surface.model(for: connection.identity)
        XCTAssertEqual(model, "omniroute:gpt-4o")
    }

    func testUpdateModel_ReplacesThePreviouslyRecordedModel() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        let connection = try await surface.configure(request())

        try await surface.updateModel("omniroute:gpt-4o", for: connection.identity)
        try await surface.updateModel("omniroute:gpt-5", for: connection.identity)

        let model = try await surface.model(for: connection.identity)
        XCTAssertEqual(model, "omniroute:gpt-5")
    }

    func testUpdateModel_EmptyModelSurfacesAsApplicationValidationError() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        let connection = try await surface.configure(request())
        try await surface.updateModel("omniroute:gpt-4o", for: connection.identity)

        do {
            try await surface.updateModel("", for: connection.identity)
            XCTFail("Expected ApplicationValidationError")
        } catch let error as ApplicationValidationError {
            XCTAssertEqual(error, .invalid(reason: "The model is empty."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let model = try await surface.model(for: connection.identity)
        XCTAssertEqual(model, "omniroute:gpt-4o")
    }

    func testUpdateModel_RepositoryFailureSurfacesAsRepositoryError() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: FailingConfigurationRepository()
        )
        do {
            try await surface.updateModel("omniroute:gpt-4o", for: ProviderIdentity())
            XCTFail("Expected RepositoryError")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .storageUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: Remove

    func testRemove_RemovesProviderCredentialAndReference() async throws {
        let providerRepository = InMemoryProviderRepository()
        let credentialStorage = InMemoryCredentialStorage()
        let configurationRepository = InMemoryConfigurationRepository()
        let surface = makeSurface(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository
        )
        let connection = try await surface.configure(request())
        let key = ConfigurationKey<CredentialReference>("providerCredential.\(connection.identity.canonicalString)")
        let storedValue = try? await configurationRepository.value(for: key, at: .providerSettings)
        let reference = try XCTUnwrap(storedValue)
        _ = try await credentialStorage.credential(for: reference)

        try await surface.remove(connection.identity)

        let storedProvider = try await providerRepository.provider(with: connection.identity)
        XCTAssertNil(storedProvider)
        let storedReference = try await configurationRepository.value(for: key, at: .providerSettings)
        XCTAssertNil(storedReference)
        do {
            _ = try await credentialStorage.credential(for: reference)
            XCTFail("Expected the stored credential to be removed")
        } catch let error as CredentialStorageError {
            XCTAssertEqual(error, .credentialNotFound)
        }
    }

    func testRemove_IsIdempotent() async throws {
        let providerRepository = InMemoryProviderRepository()
        let credentialStorage = InMemoryCredentialStorage()
        let configurationRepository = InMemoryConfigurationRepository()
        let surface = makeSurface(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository
        )
        let connection = try await surface.configure(request())

        try await surface.remove(connection.identity)
        try await surface.remove(connection.identity)

        let storedProvider = try await providerRepository.provider(with: connection.identity)
        XCTAssertNil(storedProvider)
    }

    func testRemove_CredentialRemovalFailureSurfacesAsCredentialStorageError() async throws {
        let providerRepository = InMemoryProviderRepository()
        let configurationRepository = InMemoryConfigurationRepository()
        let surface = makeSurface(
            providerRepository: providerRepository,
            credentialStorage: RemoveFailingCredentialStorage(),
            configurationRepository: configurationRepository
        )
        let connection = try await surface.configure(request())

        do {
            try await surface.remove(connection.identity)
            XCTFail("Expected CredentialStorageError")
        } catch let error as CredentialStorageError {
            XCTAssertEqual(error, .storageUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        let storedProvider = try await providerRepository.provider(with: connection.identity)
        XCTAssertNotNil(storedProvider)
    }

    func testRemove_ProviderDeleteFailureSurfacesAsRepositoryError() async throws {
        let providerRepository = DeleteFailingProviderRepository()
        let credentialStorage = InMemoryCredentialStorage()
        let configurationRepository = InMemoryConfigurationRepository()
        let surface = makeSurface(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository
        )
        let connection = try await surface.configure(request())

        do {
            try await surface.remove(connection.identity)
            XCTFail("Expected RepositoryError")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .storageUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        let storedProvider = try await providerRepository.provider(with: connection.identity)
        XCTAssertNotNil(storedProvider)
    }

    // MARK: Configuration — store, read, resolve, remove

    func testStore_ThenValue_ReturnsTheStoredValue() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        try await surface.store("gpt-4o", for: modelKey, at: .globalDefault)
        let loaded = try await surface.value(for: modelKey, at: .globalDefault)
        XCTAssertEqual(loaded, "gpt-4o")
    }

    func testValue_UnsetKeyReturnsNil() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        let loaded = try await surface.value(for: modelKey, at: .globalDefault)
        XCTAssertNil(loaded)
    }

    func testStore_KeepsLevelsSeparate() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        try await surface.store("provider-model", for: modelKey, at: .providerSettings)
        try await surface.store("global-model", for: modelKey, at: .globalDefault)
        let providerValue = try await surface.value(for: modelKey, at: .providerSettings)
        let defaultValue = try await surface.value(for: modelKey, at: .globalDefault)
        XCTAssertEqual(providerValue, "provider-model")
        XCTAssertEqual(defaultValue, "global-model")
    }

    func testResolved_ProviderSettingsWinsOverEveryLevel() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        try await surface.store("provider", for: modelKey, at: .providerSettings)
        try await surface.store("workspace", for: modelKey, at: .workspaceOverride)
        try await surface.store("global", for: modelKey, at: .globalDefault)
        let resolved = try await surface.resolved(for: modelKey)
        XCTAssertEqual(resolved, "provider")
    }

    func testResolved_GlobalDefaultAppliesWhenNothingHigherIsSet() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        try await surface.store("global", for: modelKey, at: .globalDefault)
        let resolved = try await surface.resolved(for: modelKey)
        XCTAssertEqual(resolved, "global")
    }

    func testResolved_UnsetKeyReturnsNil() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        let resolved = try await surface.resolved(for: modelKey)
        XCTAssertNil(resolved)
    }

    func testRemove_RemovesTheValueAtTheLevel() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        try await surface.store("gpt-4o", for: modelKey, at: .globalDefault)
        try await surface.remove(modelKey, at: .globalDefault)
        let loaded = try await surface.value(for: modelKey, at: .globalDefault)
        XCTAssertNil(loaded)
    }

    func testRemove_UnsetKeyIsIdempotent() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        try await surface.remove(modelKey, at: .globalDefault)
        try await surface.remove(modelKey, at: .globalDefault)
    }

    func testConfiguration_RepositoryFailureSurfacesAsRepositoryError() async {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: FailingConfigurationRepository()
        )
        do {
            try await surface.store("gpt-4o", for: modelKey, at: .globalDefault)
            XCTFail("Expected RepositoryError")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .storageUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: Sendability

    func testSendability_ShareAcrossConcurrencyDomain() async throws {
        let surface = makeSurface(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        let returned = await Task.detached {
            surface
        }.value
        let connection = try await returned.configure(request())
        XCTAssertEqual(connection.metadata, ProviderMetadata(displayName: "Example Provider"))
    }
}
