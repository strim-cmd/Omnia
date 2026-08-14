import Foundation
import OmniaDomain
import XCTest
@testable import OmniaApplication

private final class DraftConfigurationRepository: ConfigurationRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Any] = [:]

    func store<Value: Equatable & Sendable>(
        _ value: Value,
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        lock.withLock { values[slot(key.name, level)] = value }
    }

    func value<Value: Equatable & Sendable>(
        for key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws -> Value? {
        lock.withLock { values[slot(key.name, level)] as? Value }
    }

    func remove<Value: Equatable & Sendable>(
        _ key: ConfigurationKey<Value>,
        at level: ConfigurationLevel
    ) async throws {
        lock.withLock { values[slot(key.name, level)] = nil }
    }

    private func slot(_ key: String, _ level: ConfigurationLevel) -> String {
        "\(level)-\(key)"
    }
}

final class ConversationDraftServiceTests: XCTestCase {
    private func makeService() -> ConversationDraftService {
        ConversationDraftService(
            configurationService: ConfigurationService(
                configurationRepository: DraftConfigurationRepository(),
                resolutionPolicy: ConfigurationResolutionPolicy()
            )
        )
    }

    func testDraft_RoundTripsExactlyAndDoesNotLeakAcrossConversations() async throws {
        let service = makeService()
        let first = ConversationIdentity()
        let second = ConversationIdentity()

        try await service.save("  unfinished\nmessage  ", for: first)

        let restored = try await service.draft(for: first)
        let unrelated = try await service.draft(for: second)
        XCTAssertEqual(restored, "  unfinished\nmessage  ")
        XCTAssertEqual(unrelated, "")
    }

    func testSaveEmpty_RemovesAcceptedDraftIdempotently() async throws {
        let service = makeService()
        let identity = ConversationIdentity()
        try await service.save("Send me", for: identity)

        try await service.save("", for: identity)
        try await service.remove(for: identity)

        let restored = try await service.draft(for: identity)
        XCTAssertEqual(restored, "")
    }

    func testKey_IsStableAndConversationScoped() {
        let identity = ConversationIdentity()
        XCTAssertEqual(
            ConversationDraftService.key(for: identity).name,
            "conversationDraft.\(identity.canonicalString)"
        )
    }
}

final class DataManagementServiceTests: XCTestCase {
    func testClearAll_InvokesComposedCleanupExactlyOnce() async throws {
        let recorder = ClearDataRecorder()
        let service = DataManagementService {
            await recorder.record()
        }

        try await service.clearAll()

        let count = await recorder.count
        XCTAssertEqual(count, 1)
    }
}

private actor ClearDataRecorder {
    private(set) var count = 0
    func record() { count += 1 }
}
