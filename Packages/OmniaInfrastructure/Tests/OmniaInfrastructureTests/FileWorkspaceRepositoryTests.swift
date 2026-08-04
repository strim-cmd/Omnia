import Foundation
import XCTest
import OmniaDomain
@testable import OmniaInfrastructure

final class FileWorkspaceRepositoryTests: XCTestCase {

    private var directoryURL: URL!

    override func setUp() {
        super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileWorkspaceRepositoryTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
        super.tearDown()
    }

    private func makeRepository() -> FileWorkspaceRepository {
        FileWorkspaceRepository(directory: directoryURL)
    }

    // MARK: - Save / Load round-trip

    func testSaveThenLoad_RoundTripsTheWorkspace() async throws {
        let repository = makeRepository()
        let workspace = Workspace(
            identity: WorkspaceIdentity(),
            name: "Design",
            conversationIdentities: [ConversationIdentity(), ConversationIdentity()],
            providerIdentities: [ProviderIdentity()]
        )

        try await repository.save(workspace)
        let loaded = try await repository.workspace(with: workspace.identity)

        XCTAssertEqual(loaded, workspace)
    }

    func testSave_ReplacesExistingWorkspaceWithSameIdentity() async throws {
        let repository = makeRepository()
        let identity = WorkspaceIdentity()
        let first = Workspace(identity: identity, name: "First")
        let second = Workspace(identity: identity, name: "Second")

        try await repository.save(first)
        try await repository.save(second)

        let loaded = try await repository.workspace(with: identity)
        XCTAssertEqual(loaded, second)
    }

    // MARK: - Load absent

    func testWorkspace_WithAbsentIdentityReturnsNil() async throws {
        let repository = makeRepository()

        let loaded = try await repository.workspace(with: WorkspaceIdentity())

        XCTAssertNil(loaded)
    }

    // MARK: - List

    func testAllWorkspaces_ReturnsEveryStoredWorkspace() async throws {
        let repository = makeRepository()
        let a = Workspace(identity: WorkspaceIdentity(), name: "Alpha")
        let b = Workspace(identity: WorkspaceIdentity(), name: "Beta")

        try await repository.save(a)
        try await repository.save(b)

        let workspaces = try await repository.allWorkspaces()

        XCTAssertEqual(
            Set(workspaces.map { $0.identity.canonicalString }),
            Set([a.identity.canonicalString, b.identity.canonicalString])
        )
    }

    func testAllWorkspaces_EmptyRepositoryReturnsEmpty() async throws {
        let repository = makeRepository()

        let workspaces = try await repository.allWorkspaces()

        XCTAssertTrue(workspaces.isEmpty)
    }

    // MARK: - Delete

    func testDelete_RemovesTheWorkspace() async throws {
        let repository = makeRepository()
        let workspace = Workspace(identity: WorkspaceIdentity(), name: "Gone")

        try await repository.save(workspace)
        try await repository.delete(workspace.identity)

        let loaded = try await repository.workspace(with: workspace.identity)
        let workspaces = try await repository.allWorkspaces()
        XCTAssertNil(loaded)
        XCTAssertTrue(workspaces.isEmpty)
    }

    func testDelete_AbsentIdentityIsNotAnError() async throws {
        let repository = makeRepository()

        try await repository.delete(WorkspaceIdentity())
    }

    func testDelete_IsIdempotent() async throws {
        let repository = makeRepository()
        let workspace = Workspace(identity: WorkspaceIdentity(), name: "Gone")

        try await repository.save(workspace)
        try await repository.delete(workspace.identity)
        try await repository.delete(workspace.identity)
    }

    // MARK: - Storage-error translation

    func testSave_WhenDirectoryCannotBeReached_ThrowsStorageUnavailable() async throws {
        let blockingFileURL = directoryURL.appendingPathComponent("blocking-file")
        try Data("not a directory".utf8).write(to: blockingFileURL)
        let repository = FileWorkspaceRepository(directory: blockingFileURL)

        do {
            try await repository.save(Workspace(identity: WorkspaceIdentity(), name: "x"))
            XCTFail("Expected RepositoryError.storageUnavailable")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }
}
