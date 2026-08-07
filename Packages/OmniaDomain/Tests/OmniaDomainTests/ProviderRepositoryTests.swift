import Foundation
import OmniaFoundation
import XCTest
@testable import OmniaDomain

private let canonicalProvider = "1CE9122D-9DDE-11D1-80B4-00C04FD430C8"

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

private func makeConnection() throws -> ProviderConnection {
    let identity = try XCTUnwrap(ProviderIdentity(restoring: canonicalProvider))
    return ProviderConnection(
        identity: identity,
        capabilities: ProviderCapabilities(capabilities: [.textGeneration]),
        metadata: ProviderMetadata(displayName: "Mock Provider"),
        limits: ProviderLimits(maxRequestsPerMinute: 60),
        version: SemanticVersion(major: 1, minor: 0, patch: 0)
    )
}

final class ProviderRepositoryTests: XCTestCase {

    func testSaveThenGet_ReturnsTheStoredProvider() async throws {
        let repository = InMemoryProviderRepository()
        let provider = Provider(connection: try makeConnection())

        try await repository.save(provider)
        let loaded = try await repository.provider(with: provider.identity)

        XCTAssertEqual(loaded?.connection, provider.connection)
        XCTAssertEqual(loaded?.state, provider.state)
    }

    func testSaveThenGet_PreservesLifecycleState() async throws {
        let repository = InMemoryProviderRepository()
        let provider = Provider(connection: try makeConnection())
        try provider.transition(to: .validated)
        try provider.transition(to: .initializing)
        try provider.transition(to: .ready)
        try provider.transition(to: .disabled)

        try await repository.save(provider)
        let loaded = try await repository.provider(with: provider.identity)

        XCTAssertEqual(loaded?.state, .disabled)
    }

    func testGet_MissingIdentityReturnsNil() async throws {
        let repository = InMemoryProviderRepository()
        let loaded = try await repository.provider(with: ProviderIdentity())
        XCTAssertNil(loaded)
    }

    func testAllProviders_ReturnsEveryStoredProvider() async throws {
        let repository = InMemoryProviderRepository()
        let a = Provider(connection: try makeConnection())
        let b = Provider(connection: ProviderConnection(
            identity: ProviderIdentity(),
            capabilities: ProviderCapabilities(capabilities: [.streaming]),
            metadata: ProviderMetadata(displayName: "Other"),
            limits: ProviderLimits(maxRequestsPerMinute: 30),
            version: SemanticVersion(major: 2, minor: 0, patch: 0)
        ))
        try await repository.save(a)
        try await repository.save(b)

        let all = try await repository.allProviders()
        XCTAssertEqual(Set(all.map(\.identity)), Set([a.identity, b.identity]))
    }

    func testDelete_RemovesTheStoredProvider() async throws {
        let repository = InMemoryProviderRepository()
        let provider = Provider(connection: try makeConnection())
        try await repository.save(provider)

        try await repository.delete(provider.identity)

        let loaded = try await repository.provider(with: provider.identity)
        XCTAssertNil(loaded)
        let all = try await repository.allProviders()
        XCTAssertTrue(all.isEmpty)
    }

    func testDelete_IsIdempotent() async throws {
        let repository = InMemoryProviderRepository()
        let identity = ProviderIdentity()
        try await repository.delete(identity)
        try await repository.delete(identity)
        let loaded = try await repository.provider(with: identity)
        XCTAssertNil(loaded)
    }
}
