import Foundation
import OmniaDomain
import XCTest
@testable import OmniaApplication

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

private final class InMemoryWorkspaceRepository: WorkspaceRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [WorkspaceIdentity: Workspace] = [:]

    func save(_ workspace: Workspace) async throws {
        lock.withLock {
            storage[workspace.identity] = workspace
        }
    }

    func workspace(with identity: WorkspaceIdentity) async throws -> Workspace? {
        lock.withLock {
            storage[identity]
        }
    }

    func allWorkspaces() async throws -> [Workspace] {
        lock.withLock {
            Array(storage.values)
        }
    }

    func delete(_ identity: WorkspaceIdentity) async throws {
        lock.withLock {
            storage[identity] = nil
        }
    }
}

private final class FailingConversationRepository: ConversationRepository, @unchecked Sendable {
    func save(_ conversation: Conversation) async throws {
        throw RepositoryError.storageUnavailable
    }

    func conversation(with identity: ConversationIdentity) async throws -> Conversation? {
        throw RepositoryError.storageUnavailable
    }

    func delete(_ identity: ConversationIdentity) async throws {
        throw RepositoryError.storageUnavailable
    }
}

private final class FailingWorkspaceRepository: WorkspaceRepository, @unchecked Sendable {
    func save(_ workspace: Workspace) async throws {
        throw RepositoryError.storageUnavailable
    }

    func workspace(with identity: WorkspaceIdentity) async throws -> Workspace? {
        throw RepositoryError.storageUnavailable
    }

    func allWorkspaces() async throws -> [Workspace] {
        throw RepositoryError.storageUnavailable
    }

    func delete(_ identity: WorkspaceIdentity) async throws {
        throw RepositoryError.storageUnavailable
    }
}

final class ConversationServiceTests: XCTestCase {

    private func makeService(
        conversationRepository: some ConversationRepository,
        workspaceRepository: some WorkspaceRepository
    ) -> ConversationService {
        ConversationService(
            conversationRepository: conversationRepository,
            workspaceRepository: workspaceRepository
        )
    }

    // MARK: Create

    func testCreateConversation_ReturnsAnEmptyIdleConversation() async throws {
        let service = makeService(
            conversationRepository: InMemoryConversationRepository(),
            workspaceRepository: InMemoryWorkspaceRepository()
        )
        let conversation = try await service.createConversation()
        XCTAssertTrue(conversation.history.isEmpty)
        XCTAssertEqual(conversation.streamingState, .idle)
        XCTAssertFalse(conversation.isStreaming)
        XCTAssertNil(conversation.partialContent)
    }

    func testCreateConversation_PersistsTheCreatedConversation() async throws {
        let conversationRepository = InMemoryConversationRepository()
        let service = makeService(
            conversationRepository: conversationRepository,
            workspaceRepository: InMemoryWorkspaceRepository()
        )
        let created = try await service.createConversation()
        let loaded = try await conversationRepository.conversation(with: created.identity)
        XCTAssertEqual(loaded, created)
    }

    func testCreateConversation_AssignsAFreshIdentity() async throws {
        let service = makeService(
            conversationRepository: InMemoryConversationRepository(),
            workspaceRepository: InMemoryWorkspaceRepository()
        )
        let first = try await service.createConversation()
        let second = try await service.createConversation()
        XCTAssertNotEqual(first.identity, second.identity)
    }

    // MARK: Load (select)

    func testConversation_ReturnsTheStoredConversation() async throws {
        let conversationRepository = InMemoryConversationRepository()
        let service = makeService(
            conversationRepository: conversationRepository,
            workspaceRepository: InMemoryWorkspaceRepository()
        )
        var conversation = Conversation(identity: ConversationIdentity())
        try conversation.append(Message(role: .user, content: "Hello"))
        try await conversationRepository.save(conversation)

        let loaded = try await service.conversation(with: conversation.identity)

        XCTAssertEqual(loaded, conversation)
    }

    func testConversation_ReturnsNilForUnknownIdentity() async throws {
        let service = makeService(
            conversationRepository: InMemoryConversationRepository(),
            workspaceRepository: InMemoryWorkspaceRepository()
        )
        let loaded = try await service.conversation(with: ConversationIdentity())
        XCTAssertNil(loaded)
    }

    func testConversation_ReturnsHistoryWithTheAggregate() async throws {
        let conversationRepository = InMemoryConversationRepository()
        let service = makeService(
            conversationRepository: conversationRepository,
            workspaceRepository: InMemoryWorkspaceRepository()
        )
        var conversation = Conversation(identity: ConversationIdentity())
        try conversation.append(Message(role: .user, content: "Question"))
        try conversation.append(Message(role: .assistant, content: "Answer"))
        try await conversationRepository.save(conversation)

        let loaded = try await service.conversation(with: conversation.identity)

        XCTAssertEqual(loaded?.history, [
            Message(role: .user, content: "Question"),
            Message(role: .assistant, content: "Answer"),
        ])
    }

    // MARK: List by workspace membership

    func testConversations_ReturnsWorkspaceMembershipInIdentityOrder() async throws {
        let conversationRepository = InMemoryConversationRepository()
        let workspaceRepository = InMemoryWorkspaceRepository()
        let service = makeService(
            conversationRepository: conversationRepository,
            workspaceRepository: workspaceRepository
        )
        let identities = [
            try XCTUnwrap(ConversationIdentity(restoring: "550E8400-E29B-41D4-A716-446655440002")),
            try XCTUnwrap(ConversationIdentity(restoring: "550E8400-E29B-41D4-A716-446655440000")),
            try XCTUnwrap(ConversationIdentity(restoring: "550E8400-E29B-41D4-A716-446655440001")),
        ]
        for identity in identities {
            try await conversationRepository.save(Conversation(identity: identity))
        }
        let workspace = Workspace(
            identity: WorkspaceIdentity(),
            name: "Research",
            conversationIdentities: Set(identities)
        )
        try await workspaceRepository.save(workspace)

        let conversations = try await service.conversations(in: workspace.identity)

        let expectedOrder = identities.sorted { $0.canonicalString < $1.canonicalString }
        XCTAssertEqual(conversations.map(\.identity), expectedOrder)
    }

    func testConversations_EmptyMembershipReturnsEmptyList() async throws {
        let workspaceRepository = InMemoryWorkspaceRepository()
        let service = makeService(
            conversationRepository: InMemoryConversationRepository(),
            workspaceRepository: workspaceRepository
        )
        let workspace = Workspace(identity: WorkspaceIdentity(), name: "Empty")
        try await workspaceRepository.save(workspace)

        let conversations = try await service.conversations(in: workspace.identity)

        XCTAssertTrue(conversations.isEmpty)
    }

    func testConversations_UnknownWorkspaceReturnsEmptyList() async throws {
        let service = makeService(
            conversationRepository: InMemoryConversationRepository(),
            workspaceRepository: InMemoryWorkspaceRepository()
        )
        let conversations = try await service.conversations(in: WorkspaceIdentity())
        XCTAssertTrue(conversations.isEmpty)
    }

    func testConversations_SkipsIdentitiesWithoutAStoredConversation() async throws {
        let conversationRepository = InMemoryConversationRepository()
        let workspaceRepository = InMemoryWorkspaceRepository()
        let service = makeService(
            conversationRepository: conversationRepository,
            workspaceRepository: workspaceRepository
        )
        let stored = ConversationIdentity()
        let missing = ConversationIdentity()
        try await conversationRepository.save(Conversation(identity: stored))
        let workspace = Workspace(
            identity: WorkspaceIdentity(),
            name: "Research",
            conversationIdentities: [stored, missing]
        )
        try await workspaceRepository.save(workspace)

        let conversations = try await service.conversations(in: workspace.identity)

        XCTAssertEqual(conversations.map(\.identity), [stored])
    }

    // MARK: Delete

    func testDelete_RemovesTheConversation() async throws {
        let conversationRepository = InMemoryConversationRepository()
        let service = makeService(
            conversationRepository: conversationRepository,
            workspaceRepository: InMemoryWorkspaceRepository()
        )
        let identity = ConversationIdentity()
        try await conversationRepository.save(Conversation(identity: identity))

        try await service.delete(identity)

        let loaded = try await conversationRepository.conversation(with: identity)
        XCTAssertNil(loaded)
    }

    func testDelete_IsIdempotent() async throws {
        let service = makeService(
            conversationRepository: InMemoryConversationRepository(),
            workspaceRepository: InMemoryWorkspaceRepository()
        )
        let identity = ConversationIdentity()
        try await service.delete(identity)
        try await service.delete(identity)
    }

    // MARK: Repository failures surface as-is

    private func assertSurfacesStorageUnavailable(
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

    func testCreate_FailureSurfacesAsRepositoryError() async {
        let service = makeService(
            conversationRepository: FailingConversationRepository(),
            workspaceRepository: InMemoryWorkspaceRepository()
        )
        await assertSurfacesStorageUnavailable {
            _ = try await service.createConversation()
        }
    }

    func testLoad_FailureSurfacesAsRepositoryError() async {
        let service = makeService(
            conversationRepository: FailingConversationRepository(),
            workspaceRepository: InMemoryWorkspaceRepository()
        )
        await assertSurfacesStorageUnavailable {
            _ = try await service.conversation(with: ConversationIdentity())
        }
    }

    func testList_FailureSurfacesAsRepositoryError() async {
        let service = makeService(
            conversationRepository: InMemoryConversationRepository(),
            workspaceRepository: FailingWorkspaceRepository()
        )
        await assertSurfacesStorageUnavailable {
            _ = try await service.conversations(in: WorkspaceIdentity())
        }
    }

    func testDelete_FailureSurfacesAsRepositoryError() async {
        let service = makeService(
            conversationRepository: FailingConversationRepository(),
            workspaceRepository: InMemoryWorkspaceRepository()
        )
        await assertSurfacesStorageUnavailable {
            try await service.delete(ConversationIdentity())
        }
    }

    // MARK: Sendability

    func testSendability_ShareAcrossConcurrencyDomain() async throws {
        let service = makeService(
            conversationRepository: InMemoryConversationRepository(),
            workspaceRepository: InMemoryWorkspaceRepository()
        )
        let returned = await Task.detached {
            service
        }.value
        let conversation = try await returned.createConversation()
        XCTAssertTrue(conversation.history.isEmpty)
    }
}
