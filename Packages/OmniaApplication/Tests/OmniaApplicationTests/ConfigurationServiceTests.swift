import Foundation
import OmniaDomain
import XCTest
@testable import OmniaApplication

private final class InMemoryConfigurationRepository: ConfigurationRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ConfigurationLevel: [String: Any]] = [:]
    private var storeCount = 0

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

final class ConfigurationServiceTests: XCTestCase {

    private func makeService(
        configurationRepository: some ConfigurationRepository
    ) -> ConfigurationService {
        ConfigurationService(
            configurationRepository: configurationRepository,
            resolutionPolicy: ConfigurationResolutionPolicy()
        )
    }

    private let modelKey = ConfigurationKey<String>("model")
    private let temperatureKey = ConfigurationKey<Double>("temperature")
    private let maxTokensKey = ConfigurationKey<Int>("maxTokens")

    // MARK: Store and read

    func testStore_ThenValue_ReturnsTheStoredValue() async throws {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        try await service.store("gpt-4o", for: modelKey, at: .globalDefault)
        let loaded = try await service.value(for: modelKey, at: .globalDefault)
        XCTAssertEqual(loaded, "gpt-4o")
    }

    func testValue_UnsetKeyReturnsNil() async throws {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        let loaded = try await service.value(for: modelKey, at: .globalDefault)
        XCTAssertNil(loaded)
    }

    func testStore_ReplacesThePreviousValueAtTheSameLevel() async throws {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        try await service.store("gpt-4o", for: modelKey, at: .globalDefault)
        try await service.store("gpt-4.1", for: modelKey, at: .globalDefault)
        let loaded = try await service.value(for: modelKey, at: .globalDefault)
        XCTAssertEqual(loaded, "gpt-4.1")
    }

    func testStore_KeepsLevelsSeparate() async throws {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        try await service.store("provider-model", for: modelKey, at: .providerSettings)
        try await service.store("default-model", for: modelKey, at: .globalDefault)
        let providerValue = try await service.value(for: modelKey, at: .providerSettings)
        let defaultValue = try await service.value(for: modelKey, at: .globalDefault)
        XCTAssertEqual(providerValue, "provider-model")
        XCTAssertEqual(defaultValue, "default-model")
    }

    // MARK: Per-level resolution

    func testResolved_ProviderSettingsWinsOverEveryLevel() async throws {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        try await service.store("provider", for: modelKey, at: .providerSettings)
        try await service.store("workspace", for: modelKey, at: .workspaceOverride)
        try await service.store("global", for: modelKey, at: .globalDefault)
        try await service.store("capability", for: modelKey, at: .capabilityPreference)
        let resolved = try await service.resolved(for: modelKey)
        XCTAssertEqual(resolved, "provider")
    }

    func testResolved_WorkspaceOverrideWinsOverLowerLevels() async throws {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        try await service.store("workspace", for: modelKey, at: .workspaceOverride)
        try await service.store("global", for: modelKey, at: .globalDefault)
        let resolved = try await service.resolved(for: modelKey)
        XCTAssertEqual(resolved, "workspace")
    }

    func testResolved_GlobalDefaultWinsOverCapabilityPreference() async throws {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        try await service.store("global", for: modelKey, at: .globalDefault)
        try await service.store("capability", for: modelKey, at: .capabilityPreference)
        let resolved = try await service.resolved(for: modelKey)
        XCTAssertEqual(resolved, "global")
    }

    func testResolved_CapabilityPreferenceAppliesWhenNothingElseIsSet() async throws {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        try await service.store("capability", for: modelKey, at: .capabilityPreference)
        let resolved = try await service.resolved(for: modelKey)
        XCTAssertEqual(resolved, "capability")
    }

    func testResolved_ReturnsNilWhenNoLevelSetsTheKey() async throws {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        let resolved = try await service.resolved(for: modelKey)
        XCTAssertNil(resolved)
    }

    func testResolved_FallsThroughAfterRemovingTheHigherLevel() async throws {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        try await service.store("provider", for: modelKey, at: .providerSettings)
        try await service.store("global", for: modelKey, at: .globalDefault)
        let providerResolved = try await service.resolved(for: modelKey)
        XCTAssertEqual(providerResolved, "provider")
        try await service.remove(modelKey, at: .providerSettings)
        let resolved = try await service.resolved(for: modelKey)
        XCTAssertEqual(resolved, "global")
    }

    // MARK: Remove

    func testRemove_RemovesTheValueAtTheLevel() async throws {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        try await service.store("gpt-4o", for: modelKey, at: .globalDefault)
        try await service.remove(modelKey, at: .globalDefault)
        let loaded = try await service.value(for: modelKey, at: .globalDefault)
        XCTAssertNil(loaded)
    }

    func testRemove_IsIdempotent() async throws {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        try await service.store("gpt-4o", for: modelKey, at: .globalDefault)
        try await service.remove(modelKey, at: .globalDefault)
        try await service.remove(modelKey, at: .globalDefault)
    }

    func testRemove_KeepsOtherLevelsIntact() async throws {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        try await service.store("provider", for: modelKey, at: .providerSettings)
        try await service.store("global", for: modelKey, at: .globalDefault)
        try await service.remove(modelKey, at: .providerSettings)
        let globalValue = try await service.value(for: modelKey, at: .globalDefault)
        XCTAssertEqual(globalValue, "global")
    }

    // MARK: Typed values

    func testValue_KeysOfDifferentTypesNeverInterchange() async throws {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        try await service.store(2048, for: ConfigurationKey<Int>("capacity"), at: .globalDefault)
        let stringValue = try await service.value(
            for: ConfigurationKey<String>("capacity"),
            at: .globalDefault
        )
        let intValue = try await service.value(
            for: ConfigurationKey<Int>("capacity"),
            at: .globalDefault
        )
        XCTAssertNil(stringValue)
        XCTAssertEqual(intValue, 2048)
    }

    func testValue_StoresMultipleTypedKeysAlongsideEachOther() async throws {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        try await service.store("gpt-4o", for: modelKey, at: .globalDefault)
        try await service.store(0.7, for: temperatureKey, at: .globalDefault)
        try await service.store(4096, for: maxTokensKey, at: .globalDefault)
        let loadedModel = try await service.value(for: modelKey, at: .globalDefault)
        let loadedTemperature = try await service.value(for: temperatureKey, at: .globalDefault)
        let loadedMaxTokens = try await service.value(for: maxTokensKey, at: .globalDefault)
        XCTAssertEqual(loadedModel, "gpt-4o")
        XCTAssertEqual(loadedTemperature, 0.7)
        XCTAssertEqual(loadedMaxTokens, 4096)
    }

    func testValue_MayHoldOnlyACredentialReferencePointer() async throws {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        let key = ConfigurationKey<CredentialReference>("providerCredential")
        let reference = CredentialReference()
        try await service.store(reference, for: key, at: .providerSettings)
        let loaded = try await service.value(for: key, at: .providerSettings)
        XCTAssertEqual(loaded, reference)
    }

    // MARK: Boundary validation

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

    func testStore_EmptyKeyNameIsRejectedBeforeAnyWrite() async {
        let repository = InMemoryConfigurationRepository()
        let service = makeService(configurationRepository: repository)
        await assertThrowsValidationError(reason: "The configuration key name is empty.") {
            try await service.store("value", for: ConfigurationKey<String>(""), at: .globalDefault)
        }
        XCTAssertEqual(repository.storeCallCount, 0)
    }

    func testStore_WhitespaceOnlyKeyNameIsRejected() async {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        await assertThrowsValidationError(reason: "The configuration key name is empty.") {
            try await service.store("value", for: ConfigurationKey<String>("   "), at: .globalDefault)
        }
    }

    func testValue_EmptyKeyNameIsRejected() async {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        await assertThrowsValidationError(reason: "The configuration key name is empty.") {
            _ = try await service.value(for: ConfigurationKey<String>(""), at: .globalDefault)
        }
    }

    func testResolved_EmptyKeyNameIsRejected() async {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        await assertThrowsValidationError(reason: "The configuration key name is empty.") {
            _ = try await service.resolved(for: ConfigurationKey<String>(""))
        }
    }

    func testRemove_EmptyKeyNameIsRejected() async {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        await assertThrowsValidationError(reason: "The configuration key name is empty.") {
            try await service.remove(ConfigurationKey<String>(""), at: .globalDefault)
        }
    }

    // MARK: Failures surface as-is

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

    func testStore_FailureSurfacesAsRepositoryError() async {
        let service = makeService(configurationRepository: FailingConfigurationRepository())
        await assertSurfacesRepositoryError {
            try await service.store("value", for: modelKey, at: .globalDefault)
        }
    }

    func testValue_FailureSurfacesAsRepositoryError() async {
        let service = makeService(configurationRepository: FailingConfigurationRepository())
        await assertSurfacesRepositoryError {
            _ = try await service.value(for: modelKey, at: .globalDefault)
        }
    }

    func testResolved_FailureSurfacesAsRepositoryError() async {
        let service = makeService(configurationRepository: FailingConfigurationRepository())
        await assertSurfacesRepositoryError {
            _ = try await service.resolved(for: modelKey)
        }
    }

    func testRemove_FailureSurfacesAsRepositoryError() async {
        let service = makeService(configurationRepository: FailingConfigurationRepository())
        await assertSurfacesRepositoryError {
            try await service.remove(modelKey, at: .globalDefault)
        }
    }

    // MARK: Sendability

    func testSendability_ShareAcrossConcurrencyDomain() async throws {
        let service = makeService(configurationRepository: InMemoryConfigurationRepository())
        let returned = await Task.detached {
            service
        }.value
        try await returned.store("gpt-4o", for: modelKey, at: .globalDefault)
        let loaded = try await returned.value(for: modelKey, at: .globalDefault)
        XCTAssertEqual(loaded, "gpt-4o")
    }
}
