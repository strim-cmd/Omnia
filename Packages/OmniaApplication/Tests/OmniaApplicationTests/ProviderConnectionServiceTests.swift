import Foundation
import OmniaDomain
import OmniaFoundation
import XCTest
@testable import OmniaApplication

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

private func referenceKey(
    for identity: ProviderIdentity
) -> ConfigurationKey<CredentialReference> {
    ConfigurationKey<CredentialReference>("providerCredential.\(identity.canonicalString)")
}

private func endpointKey(
    for identity: ProviderIdentity
) -> ConfigurationKey<String> {
    ConfigurationKey<String>("providerEndpoint.\(identity.canonicalString)")
}

private func modelKey(
    for identity: ProviderIdentity
) -> ConfigurationKey<String> {
    ConfigurationKey<String>("providerModel.\(identity.canonicalString)")
}

private final class InMemoryProviderRepository: ProviderRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ProviderIdentity: Provider] = [:]
    private var saveCount = 0
    private var deleteCount = 0

    func save(_ provider: Provider) async throws {
        lock.withLock {
            storage[provider.identity] = provider
            saveCount += 1
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
            deleteCount += 1
        }
    }

    var saveCallCount: Int {
        lock.withLock { saveCount }
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
    private var storeCount = 0
    private var removeCount = 0

    func store(_ credential: Credential, for reference: CredentialReference) async throws {
        lock.withLock {
            storage[reference] = credential
            storeCount += 1
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
            removeCount += 1
        }
    }

    var storeCallCount: Int {
        lock.withLock { storeCount }
    }

    var removeCallCount: Int {
        lock.withLock { removeCount }
    }
}

private final class FailingCredentialStorage: CredentialStorageProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var storeCount = 0

    func store(_ credential: Credential, for reference: CredentialReference) async throws {
        lock.withLock {
            storeCount += 1
        }
        throw CredentialStorageError.storageUnavailable
    }

    func credential(for reference: CredentialReference) async throws -> Credential {
        throw CredentialStorageError.credentialNotFound
    }

    func removeCredential(for reference: CredentialReference) async throws {
        throw CredentialStorageError.storageUnavailable
    }

    var storeCallCount: Int {
        lock.withLock { storeCount }
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
    private var storeCount = 0
    private var removeCount = 0

    func store<Value: Equatable & Sendable>(
        _ value: Value,
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        let slot = Self.slot(for: key, as: Value.self)
        lock.withLock {
            storage[level, default: [:]][slot] = value
            storeCount += 1
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
            removeCount += 1
        }
    }

    private static func slot<Value>(for key: ConfigurationKey<Value>, as type: Value.Type) -> String {
        "\(key.name)\u{0}\(ObjectIdentifier(type))"
    }

    var storeCallCount: Int {
        lock.withLock { storeCount }
    }
}

private final class FailingConfigurationRepository: ConfigurationRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storeCount = 0

    func store<Value: Equatable & Sendable>(
        _ value: Value,
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        lock.withLock {
            storeCount += 1
        }
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

    var storeCallCount: Int {
        lock.withLock { storeCount }
    }
}

final class ProviderConnectionServiceTests: XCTestCase {

    private func makeService(
        providerRepository: some ProviderRepository,
        credentialStorage: some CredentialStorageProtocol,
        configurationRepository: some ConfigurationRepository
    ) -> ProviderConnectionService {
        ProviderConnectionService(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository
        )
    }

    private func makeServiceWithInMemoryDoubles()
        -> (
            providerRepository: InMemoryProviderRepository,
            credentialStorage: InMemoryCredentialStorage,
            configurationRepository: InMemoryConfigurationRepository,
            service: ProviderConnectionService
        )
    {
        let providerRepository = InMemoryProviderRepository()
        let credentialStorage = InMemoryCredentialStorage()
        let configurationRepository = InMemoryConfigurationRepository()
        let service = makeService(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository
        )
        return (providerRepository, credentialStorage, configurationRepository, service)
    }

    // MARK: Configure

    func testConfigure_ReturnsConnectionWithFreshIdentityAndDeclaredContent() async throws {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        let connection = try await service.configure(request())

        XCTAssertNotEqual(connection.identity, ProviderIdentity())
        XCTAssertEqual(
            connection.capabilities,
            ProviderCapabilities(capabilities: [.textGeneration, .conversation])
        )
        XCTAssertEqual(connection.metadata, ProviderMetadata(displayName: "Example Provider"))
        XCTAssertEqual(connection.limits, ProviderLimits(maxRequestsPerMinute: 60))
        XCTAssertEqual(connection.version, SemanticVersion(major: 1, minor: 0, patch: 0))
    }

    func testConfigure_PersistsTheProvider() async throws {
        let (providerRepository, _, _, service) = makeServiceWithInMemoryDoubles()
        let connection = try await service.configure(request())

        let stored = try await providerRepository.provider(with: connection.identity)
        XCTAssertEqual(stored?.connection, connection)
        XCTAssertEqual(stored?.state, .registered)
        XCTAssertTrue(stored?.canDeliver(.textGeneration) == true)
        XCTAssertTrue(stored?.canDeliver(.conversation) == true)
    }

    func testConfigure_StoresTheCredentialByReference() async throws {
        let (_, credentialStorage, configurationRepository, service) =
            makeServiceWithInMemoryDoubles()
        let connection = try await service.configure(request())

        let storedValue = try? await configurationRepository.value(
            for: referenceKey(for: connection.identity),
            at: .providerSettings
        )
        let reference = try XCTUnwrap(storedValue)
        let stored = try await credentialStorage.credential(for: reference)
        stored.withValue { XCTAssertEqual($0, secretValue) }
        XCTAssertNotEqual(reference.canonicalString, secretValue)
    }

    func testConfigure_RecordsTheReferenceAtProviderSettingsLevel() async throws {
        let (_, _, configurationRepository, service) = makeServiceWithInMemoryDoubles()
        let connection = try await service.configure(request())

        let reference = try await configurationRepository.value(
            for: referenceKey(for: connection.identity),
            at: .providerSettings
        )
        XCTAssertNotNil(reference)
    }

    func testConfigure_AssignsAFreshIdentityPerCall() async throws {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        let first = try await service.configure(request())
        let second = try await service.configure(request())
        XCTAssertNotEqual(first.identity, second.identity)
    }

    func testConfigure_TwoProvidersKeepDistinctCredentialReferences() async throws {
        let (_, credentialStorage, configurationRepository, service) =
            makeServiceWithInMemoryDoubles()
        let first = try await service.configure(request(displayName: "Alpha"))
        let second = try await service.configure(request(displayName: "Beta"))

        let firstStoredValue = try? await configurationRepository.value(
            for: referenceKey(for: first.identity),
            at: .providerSettings
        )
        let firstReference = try XCTUnwrap(firstStoredValue)
        let secondStoredValue = try? await configurationRepository.value(
            for: referenceKey(for: second.identity),
            at: .providerSettings
        )
        let secondReference = try XCTUnwrap(secondStoredValue)
        XCTAssertNotEqual(firstReference, secondReference)

        try await service.remove(first.identity)
        _ = try await credentialStorage.credential(for: secondReference)
    }

    // MARK: The credential never leaves the secure storage

    func testConfigure_ThePersistedProviderNeverCarriesTheCredential() async throws {
        let (providerRepository, _, configurationRepository, service) = makeServiceWithInMemoryDoubles()
        let connection = try await service.configure(request())

        let storedProviderValue = try? await providerRepository.provider(with: connection.identity)
        let stored = try XCTUnwrap(storedProviderValue)
        XCTAssertFalse(String(describing: stored.connection).contains(secretValue))
        let storedReferenceValue = try? await configurationRepository.value(
            for: referenceKey(for: connection.identity),
            at: .providerSettings
        )
        let reference = try XCTUnwrap(storedReferenceValue)
        XCTAssertFalse(String(describing: reference).contains(secretValue))
        XCTAssertFalse(String(describing: configurationRepository).contains(secretValue))
    }

    // MARK: Configure — boundary validation

    private func assertThrowsValidationError(
        reason: String,
        _ operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("Expected ApplicationValidationError.invalid(reason: \"\(reason)\")", file: file, line: line)
        } catch let error as ApplicationValidationError {
            XCTAssertEqual(error, .invalid(reason: reason), file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }

    func testConfigure_EmptyDisplayNameIsRejectedBeforeAnyWrite() async {
        let (providerRepository, credentialStorage, configurationRepository, service) =
            makeServiceWithInMemoryDoubles()
        await assertThrowsValidationError(reason: "The display name is empty.") {
            _ = try await service.configure(request(displayName: ""))
        }
        XCTAssertEqual(providerRepository.saveCallCount, 0)
        XCTAssertEqual(credentialStorage.storeCallCount, 0)
        XCTAssertEqual(configurationRepository.storeCallCount, 0)
    }

    func testConfigure_WhitespaceOnlyDisplayNameIsRejected() async {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        await assertThrowsValidationError(reason: "The display name is empty.") {
            _ = try await service.configure(request(displayName: "   "))
        }
    }

    func testConfigure_EmptyCapabilitiesAreRejectedBeforeAnyWrite() async {
        let (providerRepository, credentialStorage, configurationRepository, service) =
            makeServiceWithInMemoryDoubles()
        await assertThrowsValidationError(reason: "The provider must declare at least one capability.") {
            _ = try await service.configure(
                request(capabilities: ProviderCapabilities(capabilities: []))
            )
        }
        XCTAssertEqual(providerRepository.saveCallCount, 0)
        XCTAssertEqual(credentialStorage.storeCallCount, 0)
        XCTAssertEqual(configurationRepository.storeCallCount, 0)
    }

    func testConfigure_EmptyCredentialIsRejectedBeforeAnyWrite() async {
        let (providerRepository, credentialStorage, configurationRepository, service) =
            makeServiceWithInMemoryDoubles()
        await assertThrowsValidationError(reason: "The credential is empty.") {
            _ = try await service.configure(request(credential: Credential(secret: "")))
        }
        XCTAssertEqual(providerRepository.saveCallCount, 0)
        XCTAssertEqual(credentialStorage.storeCallCount, 0)
        XCTAssertEqual(configurationRepository.storeCallCount, 0)
    }

    // MARK: Configure — failures surface as-is

    private func assertSurfacesRepositoryError(
        _ operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("Expected RepositoryError.storageUnavailable", file: file, line: line)
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .storageUnavailable, file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }

    private func assertSurfacesCredentialStorageError(
        _ operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("Expected CredentialStorageError", file: file, line: line)
        } catch let error as CredentialStorageError {
            XCTAssertEqual(error, .storageUnavailable, file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }

    func testConfigure_ProviderSaveFailureSurfacesAsRepositoryError() async {
        let credentialStorage = InMemoryCredentialStorage()
        let configurationRepository = InMemoryConfigurationRepository()
        let service = makeService(
            providerRepository: FailingProviderRepository(),
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository
        )
        await assertSurfacesRepositoryError {
            _ = try await service.configure(request())
        }
        XCTAssertEqual(credentialStorage.storeCallCount, 0)
        XCTAssertEqual(configurationRepository.storeCallCount, 0)
    }

    func testConfigure_CredentialStoreFailureSurfacesAsCredentialStorageError() async {
        let providerRepository = InMemoryProviderRepository()
        let configurationRepository = InMemoryConfigurationRepository()
        let service = makeService(
            providerRepository: providerRepository,
            credentialStorage: FailingCredentialStorage(),
            configurationRepository: configurationRepository
        )
        await assertSurfacesCredentialStorageError {
            _ = try await service.configure(request())
        }
        XCTAssertEqual(configurationRepository.storeCallCount, 0)
    }

    func testConfigure_ReferenceRecordFailureSurfacesAsRepositoryError() async {
        let providerRepository = InMemoryProviderRepository()
        let credentialStorage = InMemoryCredentialStorage()
        let service = makeService(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: FailingConfigurationRepository()
        )
        await assertSurfacesRepositoryError {
            _ = try await service.configure(request())
        }
        XCTAssertEqual(providerRepository.saveCallCount, 1)
        XCTAssertEqual(credentialStorage.storeCallCount, 1)
    }

    // MARK: Configure — endpoint collection

    func testConfigureWithEndpoint_RecordsTheEndpointKeyedByConnectionIdentity() async throws {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        let connection = try await service.configure(
            request(),
            endpoint: "https://api.example.com/v1"
        )

        let endpoint = try await service.endpoint(for: connection.identity)
        XCTAssertEqual(endpoint, "https://api.example.com/v1")
    }

    func testConfigureWithEndpoint_RecordsTheTrimmedEndpoint() async throws {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        let connection = try await service.configure(
            request(),
            endpoint: "  https://api.example.com/v1  "
        )

        let endpoint = try await service.endpoint(for: connection.identity)
        XCTAssertEqual(endpoint, "https://api.example.com/v1")
    }

    func testConfigureWithEndpoint_UpperAndMixedCaseSchemeIsAccepted() async throws {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        let connection = try await service.configure(
            request(),
            endpoint: "HTTPS://api.example.com/v1"
        )

        let endpoint = try await service.endpoint(for: connection.identity)
        XCTAssertEqual(endpoint, "HTTPS://api.example.com/v1")
    }

    func testConfigureWithEndpoint_EmptyEndpointIsRejectedBeforeAnyWrite() async {
        let (providerRepository, credentialStorage, configurationRepository, service) =
            makeServiceWithInMemoryDoubles()
        await assertThrowsValidationError(reason: "The endpoint is empty.") {
            _ = try await service.configure(request(), endpoint: "")
        }
        XCTAssertEqual(providerRepository.saveCallCount, 0)
        XCTAssertEqual(credentialStorage.storeCallCount, 0)
        XCTAssertEqual(configurationRepository.storeCallCount, 0)
    }

    func testConfigureWithEndpoint_WhitespaceOnlyEndpointIsRejectedBeforeAnyWrite() async {
        let (providerRepository, credentialStorage, configurationRepository, service) =
            makeServiceWithInMemoryDoubles()
        await assertThrowsValidationError(reason: "The endpoint is empty.") {
            _ = try await service.configure(request(), endpoint: "   ")
        }
        XCTAssertEqual(providerRepository.saveCallCount, 0)
        XCTAssertEqual(credentialStorage.storeCallCount, 0)
        XCTAssertEqual(configurationRepository.storeCallCount, 0)
    }

    func testConfigureWithEndpoint_NonHTTPSchemeIsRejectedBeforeAnyWrite() async {
        let (providerRepository, credentialStorage, configurationRepository, service) =
            makeServiceWithInMemoryDoubles()
        await assertThrowsValidationError(reason: "The endpoint must be an absolute http or https URL.") {
            _ = try await service.configure(request(), endpoint: "ftp://files.example.com")
        }
        XCTAssertEqual(providerRepository.saveCallCount, 0)
        XCTAssertEqual(credentialStorage.storeCallCount, 0)
        XCTAssertEqual(configurationRepository.storeCallCount, 0)
    }

    func testConfigureWithEndpoint_EndpointRecordFailureSurfacesAsRepositoryError() async {
        let providerRepository = InMemoryProviderRepository()
        let credentialStorage = InMemoryCredentialStorage()
        let service = makeService(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: FailingConfigurationRepository()
        )
        await assertSurfacesRepositoryError {
            _ = try await service.configure(
                request(),
                endpoint: "https://api.example.com/v1"
            )
        }
        XCTAssertEqual(providerRepository.saveCallCount, 1)
        XCTAssertEqual(credentialStorage.storeCallCount, 1)
    }

    // MARK: List

    func testAllProviders_ReturnsStoredProvidersInIdentityOrder() async throws {
        let (providerRepository, _, _, service) = makeServiceWithInMemoryDoubles()
        let identities = [
            try XCTUnwrap(ProviderIdentity(restoring: "550E8400-E29B-41D4-A716-446655440002")),
            try XCTUnwrap(ProviderIdentity(restoring: "550E8400-E29B-41D4-A716-446655440000")),
            try XCTUnwrap(ProviderIdentity(restoring: "550E8400-E29B-41D4-A716-446655440001")),
        ]
        for identity in identities {
            try await providerRepository.save(
                Provider(
                    connection: ProviderConnection(
                        identity: identity,
                        capabilities: ProviderCapabilities(capabilities: [.textGeneration]),
                        metadata: ProviderMetadata(displayName: "P"),
                        limits: ProviderLimits(),
                        version: SemanticVersion(major: 1, minor: 0, patch: 0)
                    )
                )
            )
        }

        let providers = try await service.allProviders()

        let expectedOrder = identities.sorted { $0.canonicalString < $1.canonicalString }
        XCTAssertEqual(providers.map(\.identity), expectedOrder)
    }

    func testAllProviders_ReturnsEmptyListWhenNoneIsConfigured() async throws {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        let providers = try await service.allProviders()
        XCTAssertTrue(providers.isEmpty)
    }

    func testAllProviders_FailureSurfacesAsRepositoryError() async {
        let service = makeService(
            providerRepository: FailingProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: InMemoryConfigurationRepository()
        )
        await assertSurfacesRepositoryError {
            _ = try await service.allProviders()
        }
    }

    // MARK: Remove

    func testRemove_RemovesProviderCredentialAndReference() async throws {
        let (providerRepository, credentialStorage, configurationRepository, service) =
            makeServiceWithInMemoryDoubles()
        let connection = try await service.configure(request())
        let key = referenceKey(for: connection.identity)
        let storedValue = try? await configurationRepository.value(for: key, at: .providerSettings)
        let reference = try XCTUnwrap(storedValue)
        _ = try await credentialStorage.credential(for: reference)

        try await service.remove(connection.identity)

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
        let (providerRepository, credentialStorage, _, service) =
            makeServiceWithInMemoryDoubles()
        let connection = try await service.configure(request())

        try await service.remove(connection.identity)
        try await service.remove(connection.identity)

        let storedProvider = try await providerRepository.provider(with: connection.identity)
        XCTAssertNil(storedProvider)
        XCTAssertEqual(credentialStorage.removeCallCount, 1)
    }

    func testRemove_WithNoRecordedReferenceStillRemovesTheProvider() async throws {
        let (providerRepository, _, _, service) = makeServiceWithInMemoryDoubles()
        let identity = ProviderIdentity()
        try await providerRepository.save(
            Provider(
                connection: ProviderConnection(
                    identity: identity,
                    capabilities: ProviderCapabilities(capabilities: [.textGeneration]),
                    metadata: ProviderMetadata(displayName: "Standalone"),
                    limits: ProviderLimits(),
                    version: SemanticVersion(major: 1, minor: 0, patch: 0)
                )
            )
        )

        try await service.remove(identity)

        let storedProvider = try await providerRepository.provider(with: identity)
        XCTAssertNil(storedProvider)
    }

    func testRemove_CredentialRemovalFailureSurfacesAsCredentialStorageError() async throws {
        let providerRepository = InMemoryProviderRepository()
        let configurationRepository = InMemoryConfigurationRepository()
        let service = makeService(
            providerRepository: providerRepository,
            credentialStorage: RemoveFailingCredentialStorage(),
            configurationRepository: configurationRepository
        )
        let connection = try await service.configure(request())

        await assertSurfacesCredentialStorageError {
            try await service.remove(connection.identity)
        }
        let storedProvider = try await providerRepository.provider(with: connection.identity)
        XCTAssertNotNil(storedProvider)
        let storedReference = try await configurationRepository.value(
            for: referenceKey(for: connection.identity),
            at: .providerSettings
        )
        XCTAssertNotNil(storedReference)
    }

    func testRemove_ProviderDeleteFailureSurfacesAsRepositoryError() async throws {
        let providerRepository = DeleteFailingProviderRepository()
        let credentialStorage = InMemoryCredentialStorage()
        let configurationRepository = InMemoryConfigurationRepository()
        let service = makeService(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: configurationRepository
        )
        let connection = try await service.configure(request())

        await assertSurfacesRepositoryError {
            try await service.remove(connection.identity)
        }
        let storedProvider = try await providerRepository.provider(with: connection.identity)
        XCTAssertNotNil(storedProvider)
    }

    func testRemove_ReferenceReadFailureSurfacesAsRepositoryError() async throws {
        let providerRepository = InMemoryProviderRepository()
        let credentialStorage = InMemoryCredentialStorage()
        let service = makeService(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: FailingConfigurationRepository()
        )
        let identity = ProviderIdentity()

        await assertSurfacesRepositoryError {
            try await service.remove(identity)
        }
        let storedProvider = try await providerRepository.provider(with: identity)
        XCTAssertNil(storedProvider)
        XCTAssertEqual(credentialStorage.removeCallCount, 0)
    }

    // MARK: Endpoint

    func testUpdateEndpoint_RecordsTheEndpointAtProviderSettingsLevel() async throws {
        let (_, _, configurationRepository, service) = makeServiceWithInMemoryDoubles()
        let identity = ProviderIdentity()
        try await service.updateEndpoint("https://api.example.com/v1", for: identity)

        let stored = try await configurationRepository.value(
            for: endpointKey(for: identity),
            at: .providerSettings
        )
        XCTAssertEqual(stored, "https://api.example.com/v1")
    }

    func testUpdateEndpoint_RecordsTheTrimmedEndpoint() async throws {
        let (_, _, configurationRepository, service) = makeServiceWithInMemoryDoubles()
        let identity = ProviderIdentity()
        try await service.updateEndpoint("  https://api.example.com/v1  ", for: identity)

        let stored = try await configurationRepository.value(
            for: endpointKey(for: identity),
            at: .providerSettings
        )
        XCTAssertEqual(stored, "https://api.example.com/v1")
    }

    func testEndpoint_ReturnsTheRecordedEndpoint() async throws {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        let identity = ProviderIdentity()
        try await service.updateEndpoint("https://api.example.com/v1", for: identity)

        let endpoint = try await service.endpoint(for: identity)
        XCTAssertEqual(endpoint, "https://api.example.com/v1")
    }

    func testEndpoint_ReturnsNilWhenNoneIsRecorded() async throws {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        let endpoint = try await service.endpoint(for: ProviderIdentity())
        XCTAssertNil(endpoint)
    }

    func testUpdateEndpoint_UpperAndMixedCaseSchemeIsAccepted() async throws {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        let identity = ProviderIdentity()
        try await service.updateEndpoint("HTTPS://api.example.com/v1", for: identity)

        let endpoint = try await service.endpoint(for: identity)
        XCTAssertEqual(endpoint, "HTTPS://api.example.com/v1")
    }

    func testUpdateEndpoint_EmptyEndpointIsRejectedBeforeAnyWrite() async {
        let (_, _, configurationRepository, service) = makeServiceWithInMemoryDoubles()
        await assertThrowsValidationError(reason: "The endpoint is empty.") {
            try await service.updateEndpoint("", for: ProviderIdentity())
        }
        XCTAssertEqual(configurationRepository.storeCallCount, 0)
    }

    func testUpdateEndpoint_WhitespaceOnlyEndpointIsRejected() async {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        await assertThrowsValidationError(reason: "The endpoint is empty.") {
            try await service.updateEndpoint("   ", for: ProviderIdentity())
        }
    }

    func testUpdateEndpoint_NonHTTPSchemeIsRejected() async {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        await assertThrowsValidationError(reason: "The endpoint must be an absolute http or https URL.") {
            try await service.updateEndpoint("ftp://files.example.com", for: ProviderIdentity())
        }
    }

    func testUpdateEndpoint_RelativeEndpointIsRejected() async {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        await assertThrowsValidationError(reason: "The endpoint must be an absolute http or https URL.") {
            try await service.updateEndpoint("api.example.com/v1", for: ProviderIdentity())
        }
    }

    func testUpdateEndpoint_MissingAuthorityIsRejected() async {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        await assertThrowsValidationError(reason: "The endpoint must be an absolute http or https URL.") {
            try await service.updateEndpoint("https://", for: ProviderIdentity())
        }
    }

    func testUpdateEndpoint_RecordFailureSurfacesAsRepositoryError() async {
        let service = makeService(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: FailingConfigurationRepository()
        )
        await assertSurfacesRepositoryError {
            try await service.updateEndpoint("https://api.example.com/v1", for: ProviderIdentity())
        }
    }

    func testEndpoint_ReadFailureSurfacesAsRepositoryError() async {
        let service = makeService(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: FailingConfigurationRepository()
        )
        await assertSurfacesRepositoryError {
            _ = try await service.endpoint(for: ProviderIdentity())
        }
    }

    func testRemove_RemovesTheRecordedEndpoint() async throws {
        let (_, _, configurationRepository, service) = makeServiceWithInMemoryDoubles()
        let identity = ProviderIdentity()
        try await service.updateEndpoint("https://api.example.com/v1", for: identity)
        let key = endpointKey(for: identity)
        let recorded = try await configurationRepository.value(for: key, at: .providerSettings)
        XCTAssertNotNil(recorded)

        try await service.remove(identity)

        let stored = try await configurationRepository.value(for: key, at: .providerSettings)
        XCTAssertNil(stored)
    }

    // MARK: Model

    func testUpdateModel_RecordsTheModelAtProviderSettingsLevel() async throws {
        let (_, _, configurationRepository, service) = makeServiceWithInMemoryDoubles()
        let identity = ProviderIdentity()
        try await service.updateModel("omniroute:gpt-4o", for: identity)

        let stored = try await configurationRepository.value(
            for: modelKey(for: identity),
            at: .providerSettings
        )
        XCTAssertEqual(stored, "omniroute:gpt-4o")
    }

    func testUpdateModel_RecordsTheTrimmedModel() async throws {
        let (_, _, configurationRepository, service) = makeServiceWithInMemoryDoubles()
        let identity = ProviderIdentity()
        try await service.updateModel("  omniroute:gpt-4o  ", for: identity)

        let stored = try await configurationRepository.value(
            for: modelKey(for: identity),
            at: .providerSettings
        )
        XCTAssertEqual(stored, "omniroute:gpt-4o")
    }

    func testModel_ReturnsTheRecordedModel() async throws {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        let identity = ProviderIdentity()
        try await service.updateModel("omniroute:gpt-4o", for: identity)

        let model = try await service.model(for: identity)
        XCTAssertEqual(model, "omniroute:gpt-4o")
    }

    func testModel_ReturnsNilWhenNoneIsRecorded() async throws {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        let model = try await service.model(for: ProviderIdentity())
        XCTAssertNil(model)
    }

    func testUpdateModel_EmptyModelIsRejectedBeforeAnyWrite() async {
        let (_, _, configurationRepository, service) = makeServiceWithInMemoryDoubles()
        await assertThrowsValidationError(reason: "The model is empty.") {
            try await service.updateModel("", for: ProviderIdentity())
        }
        XCTAssertEqual(configurationRepository.storeCallCount, 0)
    }

    func testUpdateModel_WhitespaceOnlyModelIsRejected() async {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        await assertThrowsValidationError(reason: "The model is empty.") {
            try await service.updateModel("   ", for: ProviderIdentity())
        }
    }

    func testUpdateModel_RecordFailureSurfacesAsRepositoryError() async {
        let service = makeService(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: FailingConfigurationRepository()
        )
        await assertSurfacesRepositoryError {
            try await service.updateModel("omniroute:gpt-4o", for: ProviderIdentity())
        }
    }

    func testModel_ReadFailureSurfacesAsRepositoryError() async {
        let service = makeService(
            providerRepository: InMemoryProviderRepository(),
            credentialStorage: InMemoryCredentialStorage(),
            configurationRepository: FailingConfigurationRepository()
        )
        await assertSurfacesRepositoryError {
            _ = try await service.model(for: ProviderIdentity())
        }
    }

    func testRemove_RemovesTheRecordedModel() async throws {
        let (_, _, configurationRepository, service) = makeServiceWithInMemoryDoubles()
        let identity = ProviderIdentity()
        try await service.updateModel("omniroute:gpt-4o", for: identity)
        let key = modelKey(for: identity)
        let recorded = try await configurationRepository.value(for: key, at: .providerSettings)
        XCTAssertNotNil(recorded)

        try await service.remove(identity)

        let stored = try await configurationRepository.value(for: key, at: .providerSettings)
        XCTAssertNil(stored)
    }

    func testConfigureWithEndpointAndModel_RecordsTheModelKeyedByConnectionIdentity() async throws {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        let connection = try await service.configure(
            request(),
            endpoint: "https://api.example.com/v1",
            model: "omniroute:gpt-4o"
        )

        let model = try await service.model(for: connection.identity)
        XCTAssertEqual(model, "omniroute:gpt-4o")
    }

    func testConfigureWithEndpointAndNilModel_RecordsNoModel() async throws {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        let connection = try await service.configure(
            request(),
            endpoint: "https://api.example.com/v1",
            model: nil
        )

        let model = try await service.model(for: connection.identity)
        XCTAssertNil(model)
    }

    func testConfigureWithEndpointAndEmptyModel_IsRejectedBeforeAnyWrite() async {
        let (providerRepository, credentialStorage, configurationRepository, service) =
            makeServiceWithInMemoryDoubles()
        await assertThrowsValidationError(reason: "The model is empty.") {
            _ = try await service.configure(
                request(),
                endpoint: "https://api.example.com/v1",
                model: "   "
            )
        }
        XCTAssertEqual(providerRepository.saveCallCount, 0)
        XCTAssertEqual(credentialStorage.storeCallCount, 0)
        XCTAssertEqual(configurationRepository.storeCallCount, 0)
    }

    func testConfigureWithEndpointAndModel_ModelRecordFailureSurfacesAsRepositoryError() async {
        let providerRepository = InMemoryProviderRepository()
        let credentialStorage = InMemoryCredentialStorage()
        let service = makeService(
            providerRepository: providerRepository,
            credentialStorage: credentialStorage,
            configurationRepository: FailingConfigurationRepository()
        )
        await assertSurfacesRepositoryError {
            _ = try await service.configure(
                request(),
                endpoint: "https://api.example.com/v1",
                model: "omniroute:gpt-4o"
            )
        }
        XCTAssertEqual(providerRepository.saveCallCount, 1)
        XCTAssertEqual(credentialStorage.storeCallCount, 1)
    }

    // MARK: Sendability

    func testSendability_ShareAcrossConcurrencyDomain() async throws {
        let (_, _, _, service) = makeServiceWithInMemoryDoubles()
        let returned = await Task.detached {
            service
        }.value
        let connection = try await returned.configure(request())
        XCTAssertEqual(connection.metadata, ProviderMetadata(displayName: "Example Provider"))
    }
}
