import Foundation
import OmniaApplication
import XCTest
@testable import OmniaPresentation

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

private func makeService(
    conversationRepository: any ConversationRepository,
    workspaceRepository: any WorkspaceRepository
) -> ConversationService {
    ConversationService(
        conversationRepository: conversationRepository,
        workspaceRepository: workspaceRepository
    )
}

private func makeSurface(
    conversationRepository: any ConversationRepository,
    workspaceRepository: any WorkspaceRepository
) -> ConversationListSurface {
    ConversationListSurface(
        service: makeService(
            conversationRepository: conversationRepository,
            workspaceRepository: workspaceRepository
        )
    )
}

private func makeConversation(_ content: String) async throws -> Conversation {
    var conversation = Conversation(identity: ConversationIdentity())
    try conversation.append(Message(role: .user, content: content))
    return conversation
}

final class ConversationListSurfaceTests: XCTestCase {

    func testLoad_ReturnsWorkspaceConversationsAsListItems() async throws {
        let conversations = try await [
            makeConversation("Hello world"),
            makeConversation("Second"),
        ]
        let repository = InMemoryConversationRepository()
        for conversation in conversations {
            try await repository.save(conversation)
        }
        let workspace = Workspace(
            identity: WorkspaceIdentity(),
            name: "Default",
            conversationIdentities: Set(conversations.map(\.identity))
        )
        let workspaceRepository = InMemoryWorkspaceRepository()
        try await workspaceRepository.save(workspace)
        let surface = makeSurface(
            conversationRepository: repository,
            workspaceRepository: workspaceRepository
        )

        let state = try await surface.load(in: workspace.identity)

        XCTAssertEqual(state.items.count, 2)
        XCTAssertEqual(
            Set(state.items.map(\.identity)),
            Set(conversations.map(\.identity))
        )
        let titles = Set(state.items.map(\.displayTitle))
        XCTAssertEqual(titles, ["Hello world", "Second"])
        XCTAssertNil(state.failure)
        XCTAssertFalse(state.isEmpty)
    }

    func testLoad_WorkspaceWithNoStoredConversationYieldsEmptyList() async throws {
        let repository = InMemoryConversationRepository()
        let workspaceRepository = InMemoryWorkspaceRepository()
        let surface = makeSurface(
            conversationRepository: repository,
            workspaceRepository: workspaceRepository
        )

        let state = try await surface.load(in: WorkspaceIdentity())

        XCTAssertEqual(state.items, [])
        XCTAssertTrue(state.isEmpty)
        XCTAssertFalse(state.hasError)
    }

    func testLoad_SkipsMembershipIdentitiesWithNoStoredConversation() async throws {
        let stored = try await makeConversation("Stored")
        let orphaned = ConversationIdentity()
        let repository = InMemoryConversationRepository()
        try await repository.save(stored)
        let workspace = Workspace(
            identity: WorkspaceIdentity(),
            name: "Default",
            conversationIdentities: [stored.identity, orphaned]
        )
        let workspaceRepository = InMemoryWorkspaceRepository()
        try await workspaceRepository.save(workspace)
        let surface = makeSurface(
            conversationRepository: repository,
            workspaceRepository: workspaceRepository
        )

        let state = try await surface.load(in: workspace.identity)

        XCTAssertEqual(state.items.map(\.identity), [stored.identity])
    }

    func testCreate_ReturnsAndPersistsAConversation() async throws {
        let repository = InMemoryConversationRepository()
        let surface = makeSurface(
            conversationRepository: repository,
            workspaceRepository: InMemoryWorkspaceRepository()
        )

        let created = try await surface.create()

        XCTAssertEqual(created.history, [])
        let stored = try await repository.conversation(with: created.identity)
        XCTAssertEqual(stored?.identity, created.identity)
    }

    func testSelect_ReturnsTheStoredConversation() async throws {
        let conversation = try await makeConversation("Hello")
        let repository = InMemoryConversationRepository()
        try await repository.save(conversation)
        let surface = makeSurface(
            conversationRepository: repository,
            workspaceRepository: InMemoryWorkspaceRepository()
        )

        let selected = try await surface.select(conversation.identity)

        XCTAssertEqual(selected?.identity, conversation.identity)
        XCTAssertEqual(selected?.history, conversation.history)
    }

    func testSelect_ReturnsNilForAnUnknownIdentity() async throws {
        let surface = makeSurface(
            conversationRepository: InMemoryConversationRepository(),
            workspaceRepository: InMemoryWorkspaceRepository()
        )

        let selected = try await surface.select(ConversationIdentity())

        XCTAssertNil(selected)
    }

    func testDelete_RemovesTheConversation() async throws {
        let conversation = try await makeConversation("Hello")
        let repository = InMemoryConversationRepository()
        try await repository.save(conversation)
        let surface = makeSurface(
            conversationRepository: repository,
            workspaceRepository: InMemoryWorkspaceRepository()
        )

        try await surface.delete(conversation.identity)

        let stored = try await repository.conversation(with: conversation.identity)
        XCTAssertNil(stored)
    }

    func testDelete_UnknownIdentityIsIdempotent() async throws {
        let surface = makeSurface(
            conversationRepository: InMemoryConversationRepository(),
            workspaceRepository: InMemoryWorkspaceRepository()
        )

        try await surface.delete(ConversationIdentity())
    }

    func testLoad_PropagatesRepositoryFailureAsIs() async throws {
        let workspace = Workspace(
            identity: WorkspaceIdentity(),
            name: "Default",
            conversationIdentities: [ConversationIdentity()]
        )
        let workspaceRepository = InMemoryWorkspaceRepository()
        try await workspaceRepository.save(workspace)
        let surface = makeSurface(
            conversationRepository: FailingConversationRepository(),
            workspaceRepository: workspaceRepository
        )

        do {
            _ = try await surface.load(in: workspace.identity)
            XCTFail("expected a repository failure")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }
}
