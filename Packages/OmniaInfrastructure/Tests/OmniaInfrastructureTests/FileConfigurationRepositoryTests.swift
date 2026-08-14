import Foundation
import XCTest
import OmniaDomain
@testable import OmniaInfrastructure

final class FileConfigurationRepositoryTests: XCTestCase {

    private var directoryURL: URL!

    override func setUp() {
        super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileConfigurationRepositoryTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
        super.tearDown()
    }

    private func makeRepository() -> FileConfigurationRepository {
        FileConfigurationRepository(directory: directoryURL)
    }

    // MARK: - Store / value round-trip

    func testStoreThenValue_RoundTripsAValue() async throws {
        let repository = makeRepository()
        let key = ConfigurationKey<Int>("retryCount")

        try await repository.store(3, for: key, at: .globalDefault)
        let loaded = try await repository.value(for: key, at: .globalDefault)

        XCTAssertEqual(loaded, 3)
    }

    func testStoreThenValue_RoundTripsDifferentValueTypes() async throws {
        let repository = makeRepository()
        let intKey = ConfigurationKey<Int>("retryCount")
        let stringKey = ConfigurationKey<String>("modelName")
        let boolKey = ConfigurationKey<Bool>("streamingEnabled")

        try await repository.store(3, for: intKey, at: .globalDefault)
        try await repository.store("gpt-4", for: stringKey, at: .providerSettings)
        try await repository.store(true, for: boolKey, at: .workspaceOverride)

        let loadedInt = try await repository.value(for: intKey, at: .globalDefault)
        let loadedString = try await repository.value(for: stringKey, at: .providerSettings)
        let loadedBool = try await repository.value(for: boolKey, at: .workspaceOverride)

        XCTAssertEqual(loadedInt, 3)
        XCTAssertEqual(loadedString, "gpt-4")
        XCTAssertEqual(loadedBool, true)
    }

    func testStore_ReplacesValueForSameKeyAndLevel() async throws {
        let repository = makeRepository()
        let key = ConfigurationKey<Int>("retryCount")

        try await repository.store(3, for: key, at: .globalDefault)
        try await repository.store(5, for: key, at: .globalDefault)

        let loaded = try await repository.value(for: key, at: .globalDefault)
        XCTAssertEqual(loaded, 5)
    }

    func testStore_IsolatesSameKeyAcrossLevels() async throws {
        let repository = makeRepository()
        let key = ConfigurationKey<Int>("retryCount")

        try await repository.store(3, for: key, at: .globalDefault)
        try await repository.store(5, for: key, at: .workspaceOverride)

        let global = try await repository.value(for: key, at: .globalDefault)
        let override = try await repository.value(for: key, at: .workspaceOverride)

        XCTAssertEqual(global, 3)
        XCTAssertEqual(override, 5)
    }

    func testStore_IsolatesDifferentKeysAtSameLevel() async throws {
        let repository = makeRepository()
        let first = ConfigurationKey<Int>("retryCount")
        let second = ConfigurationKey<Int>("maxTokens")

        try await repository.store(3, for: first, at: .globalDefault)
        try await repository.store(1000, for: second, at: .globalDefault)

        let firstLoaded = try await repository.value(for: first, at: .globalDefault)
        let secondLoaded = try await repository.value(for: second, at: .globalDefault)

        XCTAssertEqual(firstLoaded, 3)
        XCTAssertEqual(secondLoaded, 1000)
    }

    func testRemoveAll_RemovesConfigurationDocumentsAndPreservesUnrelatedFiles() async throws {
        let repository = makeRepository()
        let first = ConfigurationKey<Int>("retryCount")
        let second = ConfigurationKey<String>("modelName")
        try await repository.store(3, for: first, at: .globalDefault)
        try await repository.store("gpt-4", for: second, at: .providerSettings)
        let unrelated = directoryURL.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: unrelated)

        try await repository.removeAll()

        let firstValue = try await repository.value(for: first, at: .globalDefault)
        let secondValue = try await repository.value(for: second, at: .providerSettings)
        XCTAssertNil(firstValue)
        XCTAssertNil(secondValue)
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }

    func testStore_RoundTripsCredentialReferencePointer() async throws {
        let repository = makeRepository()
        let key = ConfigurationKey<CredentialReference>("providerCredential")
        let reference = CredentialReference()

        try await repository.store(reference, for: key, at: .providerSettings)

        let loaded = try await repository.value(for: key, at: .providerSettings)
        XCTAssertEqual(loaded, reference)
    }

    func testRelaunch_RoundTripsM1ModelConfigurationTypes() async throws {
        let first = makeRepository()
        let provider = ProviderIdentity()
        let selection = ProviderModelSelection(
            provider: provider,
            model: ModelReference(name: "provider/model-v1")
        )
        let models = [
            ModelReference(name: "model-a"),
            ModelReference(name: "provider/model-v1"),
        ]
        let profile = ModelCapabilityProfile(
            supported: [.vision],
            unsupported: [.documentInput]
        )
        let selectionKey = ConfigurationKey<ProviderModelSelection>("models.defaultSelection")
        let modelsKey = ConfigurationKey<[ModelReference]>("models.cache.provider")
        let profileKey = ConfigurationKey<ModelCapabilityProfile>("models.capabilities.provider.model")

        try await first.store(selection, for: selectionKey, at: .globalDefault)
        try await first.store(models, for: modelsKey, at: .providerSettings)
        try await first.store(profile, for: profileKey, at: .providerSettings)

        let relaunched = makeRepository()
        let restoredSelection = try await relaunched.value(
            for: selectionKey,
            at: .globalDefault
        )
        let restoredModels = try await relaunched.value(
            for: modelsKey,
            at: .providerSettings
        )
        let restoredProfile = try await relaunched.value(
            for: profileKey,
            at: .providerSettings
        )

        XCTAssertEqual(restoredSelection, selection)
        XCTAssertEqual(restoredModels, models)
        XCTAssertEqual(restoredProfile, profile)
    }

    func testStoredDocument_NeverCarriesCredentialMaterial() async throws {
        let repository = makeRepository()
        let key = ConfigurationKey<CredentialReference>("providerCredential")
        try await repository.store(CredentialReference(), for: key, at: .providerSettings)

        let url = directoryURL
            .appendingPathComponent("\(ConfigurationLevel.providerSettings.serializedName)-\(key.name)")
            .appendingPathExtension("json")
        let json = try String(contentsOf: url, encoding: .utf8).lowercased()

        XCTAssertFalse(json.contains("secret"))
        XCTAssertFalse(json.contains("credential"))
        XCTAssertFalse(json.contains("apikey"))
    }

    // MARK: - Value absent

    func testValue_AbsentKeyReturnsNil() async throws {
        let repository = makeRepository()

        let loaded = try await repository.value(
            for: ConfigurationKey<Int>("retryCount"),
            at: .globalDefault
        )

        XCTAssertNil(loaded)
    }

    func testValue_WrongStoredValueTypeThrowsStorageUnavailable() async throws {
        let repository = makeRepository()
        try await repository.store(3, for: ConfigurationKey<Int>("count"), at: .globalDefault)

        do {
            _ = try await repository.value(for: ConfigurationKey<String>("count"), at: .globalDefault)
            XCTFail("Expected RepositoryError.storageUnavailable")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }

    // MARK: - Remove

    func testRemove_RemovesTheValue() async throws {
        let repository = makeRepository()
        let key = ConfigurationKey<Int>("retryCount")

        try await repository.store(3, for: key, at: .globalDefault)
        try await repository.remove(key, at: .globalDefault)

        let loaded = try await repository.value(for: key, at: .globalDefault)
        XCTAssertNil(loaded)
    }

    func testRemove_AbsentKeyIsNotAnError() async throws {
        let repository = makeRepository()

        try await repository.remove(ConfigurationKey<Int>("retryCount"), at: .globalDefault)
    }

    func testRemove_IsIdempotent() async throws {
        let repository = makeRepository()
        let key = ConfigurationKey<Int>("retryCount")

        try await repository.store(3, for: key, at: .globalDefault)
        try await repository.remove(key, at: .globalDefault)
        try await repository.remove(key, at: .globalDefault)
    }

    // MARK: - Storage-error translation

    func testStore_WhenDirectoryCannotBeReached_ThrowsStorageUnavailable() async throws {
        let blockingFileURL = directoryURL.appendingPathComponent("blocking-file")
        try Data("not a directory".utf8).write(to: blockingFileURL)
        let repository = FileConfigurationRepository(directory: blockingFileURL)

        do {
            try await repository.store(3, for: ConfigurationKey<Int>("count"), at: .globalDefault)
            XCTFail("Expected RepositoryError.storageUnavailable")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }

    func testValue_WithCorruptedStoredDocument_ThrowsStorageUnavailable() async throws {
        let repository = makeRepository()
        let key = ConfigurationKey<Int>("retryCount")
        try Data(#"{"payload":"not a number"}"#.utf8).write(
            to: directoryURL
                .appendingPathComponent("\(ConfigurationLevel.globalDefault.serializedName)-\(key.name)")
                .appendingPathExtension("json")
        )

        do {
            _ = try await repository.value(for: key, at: .globalDefault)
            XCTFail("Expected RepositoryError.storageUnavailable")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }
}
