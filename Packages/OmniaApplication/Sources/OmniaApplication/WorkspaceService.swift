import OmniaDomain

/// The workspace application service: create, resolve, and attach a
/// conversation or provider to a workspace's membership — the minimal workspace
/// edge of the MVP application (DES-011 §3.8).
///
/// The service orchestrates the frozen `WorkspaceRepository` and the `Workspace`
/// aggregate's value-typed membership methods (DES-009 §3.4, §3.5). It owns no
/// business rules: membership changes are the aggregate's `adding(conversation:)`
/// and `adding(provider:)` methods, and the service only sequences repository
/// operations (ARC-002, ARC-003). It is the minimal slice of the workspace
/// application services deferred by DES-011 §3.7 needed to make the MVP
/// conversation flow functional (PRD-008, The Integration Gap).
///
/// A workspace is created with a fresh `WorkspaceIdentity` from the Foundation
/// `Identifier` primitive; raw values are never used (DES-002, DES-004). An
/// empty workspace name and an attach to a workspace that is not stored are
/// rejected with the typed application error of DES-011 §3.6 — a missing
/// workspace is never a silent failure (ARC-001). Repository failures surface
/// as the Domain `RepositoryError`, never wrapped (DES-009 §3.9).
///
/// The repository is injected by the Composition Root; the service never
/// references an Infrastructure implementation (ARC-006, ARC-009). The workspace
/// selection — which workspace the application presents — is session state owned
/// at the application edge, not by this surface (DES-013 §3.5, ARC-009).
public struct WorkspaceService: Sendable {
    private let workspaceRepository: any WorkspaceRepository

    /// Creates a workspace service over the given repository contract.
    public init(workspaceRepository: any WorkspaceRepository) {
        self.workspaceRepository = workspaceRepository
    }

    /// Creates a workspace with a fresh identity and `name`, and persists it
    /// (DES-002, DES-011 §3.8).
    ///
    /// Input is validated at the boundary before any domain operation (ARC-009):
    /// an empty name is rejected with the typed application error of DES-011
    /// §3.6.
    public func createWorkspace(named name: String) async throws -> Workspace {
        try validate(name)
        let workspace = Workspace(identity: WorkspaceIdentity(), name: name)
        try await workspaceRepository.save(workspace)
        return workspace
    }

    /// Returns the workspace with `identity`, or `nil` when none is stored
    /// (DES-011 §3.8).
    ///
    /// This is the resolution operation the bootstrap and the membership
    /// operations build on (DES-013 §3.4).
    public func workspace(with identity: WorkspaceIdentity) async throws -> Workspace? {
        try await workspaceRepository.workspace(with: identity)
    }

    /// Attaches `identity` to the membership of `workspace` and returns the new
    /// value (DES-011 §3.8, DES-009 §3.4).
    ///
    /// The workspace is loaded, the aggregate's `adding(conversation:)` is
    /// applied, and the new value is persisted. A workspace that is not stored
    /// fails with the typed application error of DES-011 §3.6 before any storage
    /// (ARC-001).
    public func addConversation(
        _ identity: ConversationIdentity,
        to workspace: WorkspaceIdentity
    ) async throws -> Workspace {
        let updated = try await updatedWorkspace(for: workspace) {
            $0.adding(conversation: identity)
        }
        try await workspaceRepository.save(updated)
        return updated
    }

    /// Attaches `identity` to the membership of `workspace` and returns the new
    /// value (DES-011 §3.8, DES-009 §3.4).
    ///
    /// The same pattern as `addConversation(_:to:)` over the aggregate's
    /// `adding(provider:)`. A workspace that is not stored fails with the typed
    /// application error of DES-011 §3.6 before any storage (ARC-001).
    public func addProvider(
        _ identity: ProviderIdentity,
        to workspace: WorkspaceIdentity
    ) async throws -> Workspace {
        let updated = try await updatedWorkspace(for: workspace) {
            $0.adding(provider: identity)
        }
        try await workspaceRepository.save(updated)
        return updated
    }

    /// Validates `name` at the boundary (ARC-009, DES-011 §3.6).
    private func validate(_ name: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ApplicationValidationError.invalid(reason: "The workspace name is empty.")
        }
    }

    /// Loads the workspace with `identity` and applies `change` to it.
    ///
    /// A workspace that is not stored surfaces the typed application error of
    /// DES-011 §3.6 — a missing workspace is never a silent failure (ARC-001).
    private func updatedWorkspace(
        for identity: WorkspaceIdentity,
        applying change: (Workspace) -> Workspace
    ) async throws -> Workspace {
        guard let workspace = try await workspaceRepository.workspace(with: identity) else {
            throw ApplicationValidationError.invalid(reason: "The workspace is not stored.")
        }
        return change(workspace)
    }
}
