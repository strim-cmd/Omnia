import Foundation
import OmniaFoundation
import XCTest
@testable import OmniaDomain

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

final class WorkspaceRepositoryTests: XCTestCase {

    func testSaveThenGet_ReturnsTheStoredWorkspace() async throws {
        let repository = InMemoryWorkspaceRepository()
        let identity = WorkspaceIdentity()
        let workspace = Workspace(identity: identity, name: "Research")

        try await repository.save(workspace)
        let loaded = try await repository.workspace(with: identity)

        XCTAssertEqual(loaded, workspace)
    }

    func testGet_MissingIdentityReturnsNil() async throws {
        let repository = InMemoryWorkspaceRepository()
        let loaded = try await repository.workspace(with: WorkspaceIdentity())
        XCTAssertNil(loaded)
    }

    func testSave_ReplacesTheValueWithTheSameIdentity() async throws {
        let repository = InMemoryWorkspaceRepository()
        let identity = WorkspaceIdentity()

        try await repository.save(Workspace(identity: identity, name: "Research"))
        let updated = Workspace(identity: identity, name: "Personal", providerIdentities: [ProviderIdentity()])
        try await repository.save(updated)

        let loaded = try await repository.workspace(with: identity)
        XCTAssertEqual(loaded, updated)
    }

    func testAllWorkspaces_ReturnsEveryStoredWorkspace() async throws {
        let repository = InMemoryWorkspaceRepository()
        let a = Workspace(identity: WorkspaceIdentity(), name: "A")
        let b = Workspace(identity: WorkspaceIdentity(), name: "B")
        try await repository.save(a)
        try await repository.save(b)

        let all = try await repository.allWorkspaces()
        XCTAssertEqual(Set(all.map(\.identity)), Set([a.identity, b.identity]))
    }

    func testDelete_RemovesTheStoredWorkspace() async throws {
        let repository = InMemoryWorkspaceRepository()
        let identity = WorkspaceIdentity()
        try await repository.save(Workspace(identity: identity, name: "Research"))

        try await repository.delete(identity)

        let loaded = try await repository.workspace(with: identity)
        XCTAssertNil(loaded)
        let all = try await repository.allWorkspaces()
        XCTAssertTrue(all.isEmpty)
    }

    func testDelete_IsIdempotent() async throws {
        let repository = InMemoryWorkspaceRepository()
        let identity = WorkspaceIdentity()
        try await repository.delete(identity)
        try await repository.delete(identity)
        let loaded = try await repository.workspace(with: identity)
        XCTAssertNil(loaded)
    }
}
