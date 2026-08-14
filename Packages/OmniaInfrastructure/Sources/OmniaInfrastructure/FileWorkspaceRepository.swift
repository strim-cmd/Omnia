import Foundation
import OmniaDomain

/// The concrete `WorkspaceRepository` over the file-based storage engine and
/// the Workspace serializer (DES-010 §3.1, ARC-005).
///
/// The repository stores and restores the whole Workspace aggregate by identity
/// through the storage engine, which persists the serializer's DTO as a single
/// JSON document (DES-010 §3.2). It owns no business rules (ARC-005): the
/// aggregate is stored and restored exactly as the Domain defines it, and
/// stored data remains exportable and removable by the user (ARC-005). Every
/// storage failure is surfaced as `RepositoryError.storageUnavailable` (DES-009
/// §3.9).
///
/// The repository owns its document directory: each repository type must root
/// its store in its own directory, because documents are addressed by identity
/// key alone and different aggregates must not share a namespace.
public final class FileWorkspaceRepository: WorkspaceRepository, Sendable {
    private let store: JSONDocumentStore
    private let serializer: WorkspaceSerializer

    /// Creates a repository rooted at `directory`, which holds its JSON
    /// documents. The directory is created lazily on the first save.
    public init(directory: URL) {
        self.store = JSONDocumentStore(directoryURL: directory)
        self.serializer = WorkspaceSerializer()
    }

    /// Saves `workspace`, replacing any previously stored value with the same
    /// identity.
    public func save(_ workspace: Workspace) async throws {
        try store.save(serializer.toDTO(workspace), key: workspace.identity.canonicalString)
    }

    /// Returns the workspace with `identity`, or `nil` when none is stored.
    public func workspace(with identity: WorkspaceIdentity) async throws -> Workspace? {
        guard let dto: WorkspaceDTO = try store.load(key: identity.canonicalString) else {
            return nil
        }
        return serializer.fromDTO(dto)
    }

    /// Returns all stored workspaces, in a stable order.
    public func allWorkspaces() async throws -> [Workspace] {
        var workspaces: [Workspace] = []
        for key in try store.allKeys() {
            guard let dto: WorkspaceDTO = try store.loadRecoveringInvalid(key: key) else {
                continue
            }
            workspaces.append(serializer.fromDTO(dto))
        }
        return workspaces
    }

    /// Removes the stored workspace with `identity`.
    ///
    /// Removing a workspace that is not stored is not an error; the operation
    /// is idempotent.
    public func delete(_ identity: WorkspaceIdentity) async throws {
        try store.delete(key: identity.canonicalString)
    }
}
