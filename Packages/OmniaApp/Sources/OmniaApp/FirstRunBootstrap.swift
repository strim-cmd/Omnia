import OmniaApplication
import OmniaDomain

/// The first-run bootstrap of the application (DES-013 §3.4): resolves the
/// default workspace identity, creating the default workspace on first launch.
///
/// The resolved identity is recorded as the workspace identity's canonical
/// string under the documented application-owned key at the global-defaults
/// level — the app-edge constant of `AppEdgeConstants`. The operation is
/// idempotent across launches: a recorded identity that still resolves to a
/// stored workspace is re-resolved; a missing record, or a record pointing to a
/// workspace that is no longer stored, creates a fresh default workspace and
/// re-records its identity. The default workspace is created through the
/// workspace application service — never by constructing the aggregate (ARC-006)
/// — and the bootstrap is silent: no onboarding is shown (PRD-008 Non-Goals).
/// It runs entirely on the Linux build environment.
///
/// The bootstrap owns no business rules (ARC-002); it only sequences the
/// workspace and configuration services, and every failure surfaces as it is,
/// never wrapped (DES-009 §3.9).
public struct FirstRunBootstrap: Sendable {
    private let workspaceService: WorkspaceService
    private let configurationService: ConfigurationService

    /// Creates a bootstrap over the given services, delivered by the
    /// Composition Root.
    public init(
        workspaceService: WorkspaceService,
        configurationService: ConfigurationService
    ) {
        self.workspaceService = workspaceService
        self.configurationService = configurationService
    }

    /// Resolves the default workspace identity (DES-013 §3.4).
    ///
    /// - Returns: The resolved default workspace identity, ready to be delivered
    ///   as session state and as `RootView.workspace`.
    public func resolve() async throws -> WorkspaceIdentity {
        if let recorded = try await configurationService.value(
            for: AppEdgeConstants.defaultWorkspaceIdentityKey,
            at: .globalDefault
        ),
            let identity = WorkspaceIdentity(restoring: recorded),
            try await workspaceService.workspace(with: identity) != nil {
            return identity
        }
        let workspace = try await workspaceService.createWorkspace(
            named: AppEdgeConstants.defaultWorkspaceName
        )
        try await configurationService.store(
            workspace.identity.canonicalString,
            for: AppEdgeConstants.defaultWorkspaceIdentityKey,
            at: .globalDefault
        )
        return workspace.identity
    }
}
