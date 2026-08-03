import Foundation
import XCTest
@testable import OmniaDomain

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

final class ConfigurationRepositoryTests: XCTestCase {

    func testStoreThenValue_ReturnsTheTypedValue() async throws {
        let repository = InMemoryConfigurationRepository()
        let key = ConfigurationKey<String>("defaultModel")

        try await repository.store("gpt-4o", for: key, at: .globalDefault)
        let loaded = try await repository.value(for: key, at: .globalDefault)

        XCTAssertEqual(loaded, "gpt-4o")
    }

    func testValue_UnsetKeyReturnsNil() async throws {
        let repository = InMemoryConfigurationRepository()
        let loaded = try await repository.value(for: ConfigurationKey<String>("missing"), at: .globalDefault)
        XCTAssertNil(loaded)
    }

    func testStore_ReplacesTheValueForTheSameKeyAndLevel() async throws {
        let repository = InMemoryConfigurationRepository()
        let key = ConfigurationKey<Int>("maxTokens")

        try await repository.store(4_000, for: key, at: .globalDefault)
        try await repository.store(8_000, for: key, at: .globalDefault)

        let loaded = try await repository.value(for: key, at: .globalDefault)
        XCTAssertEqual(loaded, 8_000)
    }

    func testLevel_IsolatesValuesWithTheSameName() async throws {
        let repository = InMemoryConfigurationRepository()
        let key = ConfigurationKey<String>("model")

        try await repository.store("global", for: key, at: .globalDefault)
        try await repository.store("workspace", for: key, at: .workspaceOverride)

        let global = try await repository.value(for: key, at: .globalDefault)
        let workspace = try await repository.value(for: key, at: .workspaceOverride)
        XCTAssertEqual(global, "global")
        XCTAssertEqual(workspace, "workspace")
    }

    func testValue_TypeIsPartOfTheKey() async throws {
        let repository = InMemoryConfigurationRepository()
        let stringKey = ConfigurationKey<String>("capacity")
        let intKey = ConfigurationKey<Int>("capacity")

        try await repository.store("high", for: stringKey, at: .globalDefault)
        try await repository.store(100, for: intKey, at: .globalDefault)

        let loadedString = try await repository.value(for: stringKey, at: .globalDefault)
        let loadedInt = try await repository.value(for: intKey, at: .globalDefault)
        XCTAssertEqual(loadedString, "high")
        XCTAssertEqual(loadedInt, 100)
    }

    func testRemove_ClearsTheValueForTheKeyAndLevel() async throws {
        let repository = InMemoryConfigurationRepository()
        let key = ConfigurationKey<String>("defaultModel")
        try await repository.store("gpt-4o", for: key, at: .globalDefault)

        try await repository.remove(key, at: .globalDefault)

        let loaded = try await repository.value(for: key, at: .globalDefault)
        XCTAssertNil(loaded)
    }

    func testRemove_IsIdempotent() async throws {
        let repository = InMemoryConfigurationRepository()
        let key = ConfigurationKey<String>("defaultModel")
        try await repository.remove(key, at: .globalDefault)
        try await repository.remove(key, at: .globalDefault)
        let loaded = try await repository.value(for: key, at: .globalDefault)
        XCTAssertNil(loaded)
    }
}
