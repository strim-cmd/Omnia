/// The credential storage protocol: store, retrieve, and remove credentials by
/// reference (ARC-007, ARC-009, DES-009 §3.7).
///
/// The protocol is the boundary that keeps provider authentication separate
/// from Omnia credential storage (ARC-004): a provider decides how access is
/// authorized; Omnia decides how credentials are stored. It is a contract — the
/// secure-storage implementation belongs to the Infrastructure layer (ARC-009)
/// and is delivered to consumers by the Composition Root (ARC-002, ARC-006).
///
/// Credentials never leave the device, and secrets never enter logs or
/// analytics (ARC-001, ARC-004, ARC-005).
public protocol CredentialStorageProtocol: Sendable {
    /// Stores `credential` under `reference`, replacing any previous value.
    func store(_ credential: Credential, for reference: CredentialReference) async throws

    /// Returns the credential stored under `reference`.
    ///
    /// Throws `CredentialStorageError.credentialNotFound` when no credential is
    /// stored for the reference.
    func credential(for reference: CredentialReference) async throws -> Credential

    /// Removes the credential stored under `reference`, if any.
    func removeCredential(for reference: CredentialReference) async throws
}

/// The failures a credential storage can report (DES-009 §3.7).
///
/// The concrete storage failures of the Infrastructure layer are translated
/// into these Domain terms; they never carry credential material.
public enum CredentialStorageError: Error, Equatable, Sendable {
    /// No credential is stored for the given reference.
    case credentialNotFound
    /// The secure storage could not be reached.
    case storageUnavailable
}
