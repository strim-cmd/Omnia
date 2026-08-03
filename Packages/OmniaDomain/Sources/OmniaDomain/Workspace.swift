/// The Workspace aggregate: the unit of organization of the user's work across
/// conversations and providers (ARC-001 Workspace, ARC-003 Entity, DES-009
/// §3.4).
///
/// The aggregate manages workspace membership of conversations and providers
/// BY IDENTITY, never by embedding the aggregates themselves; this is what
/// keeps the internal dependency graph acyclic (ARC-007). Workspace preferences
/// and provider overrides belong to the configuration model and MUST NOT be
/// embedded in this aggregate (ARC-004, ARC-007).
///
/// Immutable and equal by content; a membership change produces a new value,
/// never an in-place mutation (ARC-001, ARC-003).
public struct Workspace: Equatable, Sendable {
    /// The workspace's stable identity.
    public let identity: WorkspaceIdentity
    /// The name shown to the user.
    public let name: String
    /// The conversations that belong to the workspace, by identity.
    public let conversationIdentities: Set<ConversationIdentity>
    /// The providers that belong to the workspace, by identity.
    public let providerIdentities: Set<ProviderIdentity>

    /// Creates a workspace with the given membership.
    public init(
        identity: WorkspaceIdentity,
        name: String,
        conversationIdentities: Set<ConversationIdentity> = [],
        providerIdentities: Set<ProviderIdentity> = []
    ) {
        self.identity = identity
        self.name = name
        self.conversationIdentities = conversationIdentities
        self.providerIdentities = providerIdentities
    }

    /// Returns whether `conversation` belongs to the workspace.
    public func contains(conversation identity: ConversationIdentity) -> Bool {
        conversationIdentities.contains(identity)
    }

    /// Returns whether `provider` belongs to the workspace.
    public func contains(provider identity: ProviderIdentity) -> Bool {
        providerIdentities.contains(identity)
    }

    /// Returns a workspace that also includes `conversation`.
    public func adding(conversation identity: ConversationIdentity) -> Workspace {
        Workspace(
            identity: self.identity,
            name: name,
            conversationIdentities: conversationIdentities.union([identity]),
            providerIdentities: providerIdentities
        )
    }

    /// Returns a workspace without `conversation`.
    public func removing(conversation identity: ConversationIdentity) -> Workspace {
        Workspace(
            identity: self.identity,
            name: name,
            conversationIdentities: conversationIdentities.subtracting([identity]),
            providerIdentities: providerIdentities
        )
    }

    /// Returns a workspace that also includes `provider`.
    public func adding(provider identity: ProviderIdentity) -> Workspace {
        Workspace(
            identity: self.identity,
            name: name,
            conversationIdentities: conversationIdentities,
            providerIdentities: providerIdentities.union([identity])
        )
    }

    /// Returns a workspace without `provider`.
    public func removing(provider identity: ProviderIdentity) -> Workspace {
        Workspace(
            identity: self.identity,
            name: name,
            conversationIdentities: conversationIdentities,
            providerIdentities: providerIdentities.subtracting([identity])
        )
    }
}
