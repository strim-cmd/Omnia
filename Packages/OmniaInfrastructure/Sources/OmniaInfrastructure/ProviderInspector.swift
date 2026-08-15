import Foundation
import OmniaDomain

/// The generic model discovery and connection validation seam the Composition
/// Root resolves by provider API kind (DES-013 §3.3).
///
/// An inspector is bound to one endpoint and credential. It returns only
/// Domain model identities and safe typed errors; HTTP bodies, private URLs,
/// authorization headers, and credential values never cross this boundary.
public protocol ProviderInspector: Sendable {
    /// Loads the provider's model list, mapped to Domain model identities.
    func discoverModels() async throws -> [ModelReference]

    /// Validates the real endpoint/credential/model path without persisting
    /// the candidate credential, returning the validated model list.
    func testConnection(model: ModelReference?) async throws -> [ModelReference]
}

/// Credential source used only for an unsaved Test Connection request.
internal struct FixedCredentialStorage: CredentialStorageProtocol, Sendable {
    let credentialValue: Credential

    init(credential: Credential) {
        self.credentialValue = credential
    }

    func store(_ credential: Credential, for reference: CredentialReference) async throws {}

    func credential(for reference: CredentialReference) async throws -> Credential {
        credentialValue
    }

    func removeCredential(for reference: CredentialReference) async throws {}
}
