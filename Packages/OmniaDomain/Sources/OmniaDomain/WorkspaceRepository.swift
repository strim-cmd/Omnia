/// The repository contract for the `Workspace` aggregate (DES-009 §3.5,
/// ARC-003 Repository).
///
/// The contract hides the storage implementation: consumers depend on this
/// protocol, never on a storage technology (ARC-003). It stores and restores
/// the whole aggregate by identity; it owns no business rules — storage never
/// owns business logic (ARC-005). Stored data is user-owned and remains
/// exportable and removable by the user (ARC-005).
///
/// Implementations belong to OmniaInfrastructure and are delivered by the
/// Composition Root; they are out of scope for this package (ARC-002, ARC-006,
/// ARC-009).
public protocol WorkspaceRepository: Sendable {
    /// Saves `workspace`, replacing any previously stored value with the same
    /// identity.
    func save(_ workspace: Workspace) async throws

    /// Returns the workspace with `identity`, or `nil` when none is stored.
    func workspace(with identity: WorkspaceIdentity) async throws -> Workspace?

    /// Returns all stored workspaces.
    func allWorkspaces() async throws -> [Workspace]

    /// Removes the stored workspace with `identity`.
    ///
    /// Removing a workspace that is not stored is not an error; the operation
    /// is idempotent.
    func delete(_ identity: WorkspaceIdentity) async throws
}
