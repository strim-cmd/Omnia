import Foundation
import XCTest
import OmniaDomain
import OmniaFoundation
@testable import OmniaInfrastructure

final class FileProviderRepositoryTests: XCTestCase {

    private var directoryURL: URL!

    override func setUp() {
        super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileProviderRepositoryTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
        super.tearDown()
    }

    private func makeRepository() -> FileProviderRepository {
        FileProviderRepository(directory: directoryURL)
    }

    private func makeConnection() -> ProviderConnection {
        ProviderConnection(
            identity: ProviderIdentity(),
            capabilities: ProviderCapabilities(capabilities: [.textGeneration, .streaming]),
            metadata: ProviderMetadata(displayName: "Test Provider"),
            limits: ProviderLimits(maxRequestsPerMinute: 10, maxTokensPerMinute: 100, maxContextTokens: 4000),
            version: SemanticVersion(major: 1, minor: 2, patch: 3)
        )
    }

    /// Creates a provider whose lifecycle has reached `state` through its own
    /// legal transitions.
    private func provider(in state: ProviderState) throws -> Provider {
        let provider = Provider(connection: makeConnection())
        switch state {
        case .registered:
            return provider
        case .validated:
            try provider.transition(to: .validated)
        case .initializing:
            try provider.transition(to: .validated)
            try provider.transition(to: .initializing)
        case .ready:
            try provider.transition(to: .validated)
            try provider.transition(to: .initializing)
            try provider.transition(to: .ready)
        case .unavailable:
            try provider.transition(to: .validated)
            try provider.transition(to: .initializing)
            try provider.transition(to: .unavailable)
        case .disabled:
            try provider.transition(to: .validated)
            try provider.transition(to: .initializing)
            try provider.transition(to: .ready)
            try provider.transition(to: .disabled)
        case .removed:
            try provider.transition(to: .validated)
            try provider.transition(to: .initializing)
            try provider.transition(to: .ready)
            try provider.transition(to: .removed)
        }
        return provider
    }

    // MARK: - Save / Load round-trip

    func testSaveThenLoad_RoundTripsTheProviderInEveryLifecycleState() async throws {
        let repository = makeRepository()
        for state in [ProviderState.registered, .validated, .initializing, .ready, .unavailable, .disabled, .removed] {
            let provider = try provider(in: state)

            try await repository.save(provider)
            let loaded = try await repository.provider(with: provider.identity)

            XCTAssertEqual(loaded?.connection, provider.connection, "connection mismatch for state \(state)")
            XCTAssertEqual(loaded?.state, state, "state mismatch for state \(state)")
        }
    }

    func testSaveThenLoad_PreservesDeclaredConnection() async throws {
        let repository = makeRepository()
        let provider = try provider(in: .ready)

        try await repository.save(provider)
        let loaded = try await repository.provider(with: provider.identity)

        XCTAssertEqual(loaded?.connection, provider.connection)
        XCTAssertTrue(loaded?.canDeliver(.textGeneration) ?? false)
        XCTAssertTrue(loaded?.canDeliver(.streaming) ?? false)
        XCTAssertFalse(loaded?.canDeliver(.vision) ?? true)
    }

    func testSave_ReplacesExistingProviderWithSameIdentity() async throws {
        let repository = makeRepository()
        let identity = ProviderIdentity()
        let first = Provider(
            connection: ProviderConnection(
                identity: identity,
                capabilities: ProviderCapabilities(capabilities: [.textGeneration]),
                metadata: ProviderMetadata(displayName: "First"),
                limits: ProviderLimits(maxRequestsPerMinute: nil, maxTokensPerMinute: nil, maxContextTokens: nil),
                version: SemanticVersion(major: 1, minor: 0, patch: 0)
            )
        )
        let second = Provider(
            connection: ProviderConnection(
                identity: identity,
                capabilities: ProviderCapabilities(capabilities: [.conversation]),
                metadata: ProviderMetadata(displayName: "Second"),
                limits: ProviderLimits(maxRequestsPerMinute: nil, maxTokensPerMinute: nil, maxContextTokens: nil),
                version: SemanticVersion(major: 2, minor: 0, patch: 0)
            )
        )
        try first.transition(to: .validated)
        try second.transition(to: .validated)
        try second.transition(to: .initializing)
        try second.transition(to: .ready)

        try await repository.save(first)
        try await repository.save(second)

        let loaded = try await repository.provider(with: identity)
        XCTAssertEqual(loaded?.connection, second.connection)
        XCTAssertEqual(loaded?.state, .ready)
    }

    // MARK: - Load absent

    func testProvider_WithAbsentIdentityReturnsNil() async throws {
        let repository = makeRepository()

        let loaded = try await repository.provider(with: ProviderIdentity())

        XCTAssertNil(loaded)
    }

    // MARK: - List

    func testAllProviders_ReturnsEveryStoredProvider() async throws {
        let repository = makeRepository()
        let a = try provider(in: .registered)
        let b = try provider(in: .ready)

        try await repository.save(a)
        try await repository.save(b)

        let providers = try await repository.allProviders()

        XCTAssertEqual(
            Set(providers.map { $0.identity.canonicalString }),
            Set([a.identity.canonicalString, b.identity.canonicalString])
        )
    }

    func testAllProviders_EmptyRepositoryReturnsEmpty() async throws {
        let repository = makeRepository()

        let providers = try await repository.allProviders()

        XCTAssertTrue(providers.isEmpty)
    }

    func testAllProviders_ReturnsProvidersInStableSortedOrder() async throws {
        let repository = makeRepository()
        let gamma = try provider(in: .registered)
        let alpha = try provider(in: .registered)
        let beta = try provider(in: .registered)

        try await repository.save(gamma)
        try await repository.save(alpha)
        try await repository.save(beta)

        let providers = try await repository.allProviders()
        let expected = [alpha, beta, gamma].sorted {
            $0.identity.canonicalString < $1.identity.canonicalString
        }

        XCTAssertEqual(providers.map { $0.identity.canonicalString },
                       expected.map { $0.identity.canonicalString })
    }

    // MARK: - Delete

    func testDelete_RemovesTheProvider() async throws {
        let repository = makeRepository()
        let provider = try provider(in: .ready)

        try await repository.save(provider)
        try await repository.delete(provider.identity)

        let loaded = try await repository.provider(with: provider.identity)
        let providers = try await repository.allProviders()
        XCTAssertNil(loaded)
        XCTAssertTrue(providers.isEmpty)
    }

    func testDelete_AbsentIdentityIsNotAnError() async throws {
        let repository = makeRepository()

        try await repository.delete(ProviderIdentity())
    }

    func testDelete_IsIdempotent() async throws {
        let repository = makeRepository()
        let provider = try provider(in: .ready)

        try await repository.save(provider)
        try await repository.delete(provider.identity)
        try await repository.delete(provider.identity)
    }

    // MARK: - Storage-error translation

    func testSave_WhenDirectoryCannotBeReached_ThrowsStorageUnavailable() async throws {
        let blockingFileURL = directoryURL.appendingPathComponent("blocking-file")
        try Data("not a directory".utf8).write(to: blockingFileURL)
        let repository = FileProviderRepository(directory: blockingFileURL)

        do {
            try await repository.save(Provider(connection: makeConnection()))
            XCTFail("Expected RepositoryError.storageUnavailable")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }

    func testProvider_WithCorruptedStoredDocument_ThrowsStorageUnavailable() async throws {
        let repository = makeRepository()
        let identity = ProviderIdentity()
        let badStateDocument = Data(
            """
            {"connection":{"identity":"\(identity.canonicalString)","capabilities":{"capabilities":["textGeneration"]},"metadata":{"displayName":"Test"},"limits":{"maxRequestsPerMinute":null,"maxTokensPerMinute":null,"maxContextTokens":null},"version":{"major":1,"minor":0,"patch":0}},"state":"expired"}
            """.utf8
        )
        try badStateDocument.write(
            to: directoryURL
                .appendingPathComponent(identity.canonicalString)
                .appendingPathExtension("json")
        )

        do {
            _ = try await repository.provider(with: identity)
            XCTFail("Expected RepositoryError.storageUnavailable")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }
}
