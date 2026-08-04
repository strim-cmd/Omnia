import Foundation
import OmniaDomain

/// The stored representation of a `Workspace` aggregate (DES-010 §3.3, ARC-009).
///
/// The DTO carries the aggregate exactly as the Domain defines it (DES-009
/// §3.4): the identity, the name, and the conversation and provider membership
/// BY IDENTITY. Membership is stored as sorted arrays — sets have no intrinsic
/// order, and the sorted form makes the persisted representation deterministic
/// and round-trip-stable across versions (DES-004 §4, ARC-005).
internal struct WorkspaceDTO: Codable, Sendable {
    let identity: WorkspaceIdentity
    let name: String
    let conversationIdentities: [ConversationIdentity]
    let providerIdentities: [ProviderIdentity]
}

/// Maps a `Workspace` aggregate to and from its stored representation
/// (DES-010 §3.3).
///
/// The serializer owns no business rules (ARC-005): it stores and restores the
/// aggregate exactly as the Domain defines it, preserving content and equality.
internal struct WorkspaceSerializer: Sendable {
    /// Returns the stored representation of `workspace`.
    func toDTO(_ workspace: Workspace) -> WorkspaceDTO {
        WorkspaceDTO(
            identity: workspace.identity,
            name: workspace.name,
            conversationIdentities: workspace.conversationIdentities
                .sorted { $0.canonicalString < $1.canonicalString },
            providerIdentities: workspace.providerIdentities
                .sorted { $0.canonicalString < $1.canonicalString }
        )
    }

    /// Restores a `Workspace` from its stored representation.
    ///
    /// Restoration is total: every stored field is validated during `Codable`
    /// decoding (identities restore only through their canonical form), so this
    /// mapping never fails — unlike the serializers whose stored forms carry
    /// string-encoded values validated on restore.
    func fromDTO(_ dto: WorkspaceDTO) -> Workspace {
        Workspace(
            identity: dto.identity,
            name: dto.name,
            conversationIdentities: Set(dto.conversationIdentities),
            providerIdentities: Set(dto.providerIdentities)
        )
    }

    /// Encodes `workspace` to its deterministic JSON stored form.
    ///
    /// - Throws: `RepositoryError.storageUnavailable` when the aggregate cannot
    ///   be encoded.
    func encode(_ workspace: Workspace) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(toDTO(workspace))
    }

    /// Restores a `Workspace` from its JSON stored form.
    ///
    /// - Throws: `RepositoryError.storageUnavailable` when the stored form is
    ///   not a valid `Workspace` representation.
    func decode(from data: Data) throws -> Workspace {
        let dto: WorkspaceDTO
        do {
            dto = try JSONDecoder().decode(WorkspaceDTO.self, from: data)
        } catch {
            throw RepositoryError.storageUnavailable
        }
        return fromDTO(dto)
    }
}
