import Foundation
import OmniaFoundation
import XCTest
@testable import OmniaDomain

private final class InMemoryConversationRepository: ConversationRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ConversationIdentity: Conversation] = [:]

    func save(_ conversation: Conversation) async throws {
        lock.withLock {
            storage[conversation.identity] = conversation
        }
    }

    func conversation(with identity: ConversationIdentity) async throws -> Conversation? {
        lock.withLock {
            storage[identity]
        }
    }

    func delete(_ identity: ConversationIdentity) async throws {
        lock.withLock {
            storage[identity] = nil
        }
    }
}

final class ConversationRepositoryTests: XCTestCase {

    func testSaveThenGet_ReturnsTheStoredConversation() async throws {
        let repository = InMemoryConversationRepository()
        let identity = ConversationIdentity()
        var conversation = Conversation(identity: identity)
        try conversation.append(Message(role: .user, content: "Hello"))

        try await repository.save(conversation)
        let loaded = try await repository.conversation(with: identity)

        XCTAssertEqual(loaded, conversation)
    }

    func testSaveThenGet_PreservesMessageHistoryAndStreamingState() async throws {
        let repository = InMemoryConversationRepository()
        let identity = ConversationIdentity()
        var conversation = Conversation(identity: identity)
        try conversation.append(Message(role: .user, content: "Hello"))
        try conversation.beginStreaming()
        try conversation.appendPartial("Partial")
        try conversation.interruptStreaming()

        try await repository.save(conversation)
        let loaded = try await repository.conversation(with: identity)

        XCTAssertEqual(loaded?.history, [Message(role: .user, content: "Hello")])
        XCTAssertEqual(loaded?.streamingState, .interrupted(partialContent: "Partial"))
    }

    func testGet_MissingIdentityReturnsNil() async throws {
        let repository = InMemoryConversationRepository()
        let loaded = try await repository.conversation(with: ConversationIdentity())
        XCTAssertNil(loaded)
    }

    func testDelete_RemovesTheStoredConversation() async throws {
        let repository = InMemoryConversationRepository()
        let identity = ConversationIdentity()
        try await repository.save(Conversation(identity: identity))

        try await repository.delete(identity)

        let loaded = try await repository.conversation(with: identity)
        XCTAssertNil(loaded)
    }

    func testDelete_IsIdempotent() async throws {
        let repository = InMemoryConversationRepository()
        let identity = ConversationIdentity()
        try await repository.delete(identity)
        try await repository.delete(identity)
        let loaded = try await repository.conversation(with: identity)
        XCTAssertNil(loaded)
    }
}
