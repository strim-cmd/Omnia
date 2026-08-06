import Foundation
import OmniaDomain
import XCTest
@testable import OmniaApplication

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

final class WorkspaceServiceTests: XCTestCase {

    private func makeService(workspaceRepository: some WorkspaceRepository) -> WorkspaceService {
        WorkspaceService(workspaceRepository: workspaceRepository)
    }

    // MARK: Create

    func testCreateWorkspace_ReturnsWorkspaceWithTheGivenName() async throws {
        let service = makeService(workspaceRepository: InMemoryWorkspaceRepository())
        let workspace = try await service.createWorkspace(named: "Research")
        XCTAssertEqual(workspace.name, "Research")
        XCTAssertTrue(workspace.conversationIdentities.isEmpty)
        XCTAssertTrue(workspace.providerIdentities.isEmpty)
    }

    func testCreateWorkspace_PersistsTheCreatedWorkspace() async throws {
        let repository = InMemoryWorkspaceRepository()
        let service = makeService(workspaceRepository: repository)
        let created = try await service.createWorkspace(named: "Research")
        let loaded = try await repository.workspace(with: created.identity)
        XCTAssertEqual(loaded, created)
    }

    func testCreateWorkspace_AssignsAFreshIdentity() async throws {
        let service = makeService(workspaceRepository: InMemoryWorkspaceRepository())
        let first = try await service.createWorkspace(named: "One")
        let second = try await service.createWorkspace(named: "Two")
        XCTAssertNotEqual(first.identity, second.identity)
    }

    func testCreateWorkspace_RejectsEmptyNameBeforeAnyWrite() async {
        let repository = InMemoryWorkspaceRepository()
        let service = makeService(workspaceRepository: repository)
        await assertThrowsValidationError(reason: "The workspace name is empty.") {
            _ = try await service.createWorkspace(named: "")
        }
        let stored = try? await repository.allWorkspaces()
        XCTAssertEqual(stored?.isEmpty, true)
    }

    func testCreateWorkspace_RejectsWhitespaceOnlyName() async {
        let service = makeService(workspaceRepository: InMemoryWorkspaceRepository())
        await assertThrowsValidationError(reason: "The workspace name is empty.") {
            _ = try await service.createWorkspace(named: "   ")
        }
    }

    // MARK: Resolve

    func testWorkspace_ReturnsTheStoredWorkspace() async throws {
        let repository = InMemoryWorkspaceRepository()
        let service = makeService(workspaceRepository: repository)
        let workspace = Workspace(identity: WorkspaceIdentity(), name: "Research")
        try await repository.save(workspace)

        let loaded = try await service.workspace(with: workspace.identity)

        XCTAssertEqual(loaded, workspace)
    }

    func testWorkspace_ReturnsNilForUnknownIdentity() async throws {
        let service = makeService(workspaceRepository: InMemoryWorkspaceRepository())
        let loaded = try await service.workspace(with: WorkspaceIdentity())
        XCTAssertNil(loaded)
    }

    // MARK: Attach conversation

    func testAddConversation_AttachesAndPersistsTheNewValue() async throws {
        let repository = InMemoryWorkspaceRepository()
        let service = makeService(workspaceRepository: repository)
        let workspace = try await service.createWorkspace(named: "Research")
        let identity = ConversationIdentity()

        let updated = try await service.addConversation(identity, to: workspace.identity)

        XCTAssertTrue(updated.contains(conversation: identity))
        let persisted = try await repository.workspace(with: workspace.identity)
        XCTAssertEqual(persisted, updated)
    }

    func testAddConversation_PreservesExistingConversationMembership() async throws {
        let repository = InMemoryWorkspaceRepository()
        let service = makeService(workspaceRepository: repository)
        let workspace = try await service.createWorkspace(named: "Research")
        let first = ConversationIdentity()
        let second = ConversationIdentity()

        let afterFirst = try await service.addConversation(first, to: workspace.identity)
        let afterSecond = try await service.addConversation(second, to: workspace.identity)

        XCTAssertTrue(afterFirst.contains(conversation: first))
        XCTAssertTrue(afterSecond.contains(conversation: first))
        XCTAssertTrue(afterSecond.contains(conversation: second))
    }

    func testAddConversation_UnknownWorkspaceFailsBeforeAnyWrite() async {
        let repository = InMemoryWorkspaceRepository()
        let service = makeService(workspaceRepository: repository)
        await assertThrowsValidationError(reason: "The workspace is not stored.") {
            _ = try await service.addConversation(ConversationIdentity(), to: WorkspaceIdentity())
        }
        let stored = try? await repository.allWorkspaces()
        XCTAssertEqual(stored?.isEmpty, true)
    }

    func testAddConversation_AlreadyAttachedMemberIsIdempotent() async throws {
        let repository = InMemoryWorkspaceRepository()
        let service = makeService(workspaceRepository: repository)
        let workspace = try await service.createWorkspace(named: "Research")
        let identity = ConversationIdentity()

        _ = try await service.addConversation(identity, to: workspace.identity)
        let updated = try await service.addConversation(identity, to: workspace.identity)

        XCTAssertEqual(updated.conversationIdentities, [identity])
    }

    // MARK: Attach provider

    func testAddProvider_AttachesAndPersistsTheNewValue() async throws {
        let repository = InMemoryWorkspaceRepository()
        let service = makeService(workspaceRepository: repository)
        let workspace = try await service.createWorkspace(named: "Research")
        let identity = ProviderIdentity()

        let updated = try await service.addProvider(identity, to: workspace.identity)

        XCTAssertTrue(updated.contains(provider: identity))
        let persisted = try await repository.workspace(with: workspace.identity)
        XCTAssertEqual(persisted, updated)
    }

    func testAddProvider_PreservesExistingProviderMembership() async throws {
        let repository = InMemoryWorkspaceRepository()
        let service = makeService(workspaceRepository: repository)
        let workspace = try await service.createWorkspace(named: "Research")
        let first = ProviderIdentity()
        let second = ProviderIdentity()

        let afterFirst = try await service.addProvider(first, to: workspace.identity)
        let afterSecond = try await service.addProvider(second, to: workspace.identity)

        XCTAssertTrue(afterFirst.contains(provider: first))
        XCTAssertTrue(afterSecond.contains(provider: first))
        XCTAssertTrue(afterSecond.contains(provider: second))
    }

    func testAddProvider_UnknownWorkspaceFailsBeforeAnyWrite() async {
        let repository = InMemoryWorkspaceRepository()
        let service = makeService(workspaceRepository: repository)
        await assertThrowsValidationError(reason: "The workspace is not stored.") {
            _ = try await service.addProvider(ProviderIdentity(), to: WorkspaceIdentity())
        }
        let stored = try? await repository.allWorkspaces()
        XCTAssertEqual(stored?.isEmpty, true)
    }

    // MARK: Boundary validation helper

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
        let service = makeService(workspaceRepository: FailingWorkspaceRepository())
        await assertSurfacesStorageUnavailable {
            _ = try await service.createWorkspace(named: "Research")
        }
    }

    func testResolve_FailureSurfacesAsRepositoryError() async {
        let service = makeService(workspaceRepository: FailingWorkspaceRepository())
        await assertSurfacesStorageUnavailable {
            _ = try await service.workspace(with: WorkspaceIdentity())
        }
    }

    func testAddConversation_FailureSurfacesAsRepositoryError() async {
        let service = makeService(workspaceRepository: FailingWorkspaceRepository())
        await assertSurfacesStorageUnavailable {
            _ = try await service.addConversation(ConversationIdentity(), to: WorkspaceIdentity())
        }
    }

    func testAddProvider_FailureSurfacesAsRepositoryError() async {
        let service = makeService(workspaceRepository: FailingWorkspaceRepository())
        await assertSurfacesStorageUnavailable {
            _ = try await service.addProvider(ProviderIdentity(), to: WorkspaceIdentity())
        }
    }

    // MARK: Sendability

    func testSendability_ShareAcrossConcurrencyDomain() async throws {
        let service = makeService(workspaceRepository: InMemoryWorkspaceRepository())
        let returned = await Task.detached {
            service
        }.value
        let workspace = try await returned.createWorkspace(named: "Research")
        XCTAssertEqual(workspace.name, "Research")
    }
}
