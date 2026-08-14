import OmniaDomain

/// The platform backend seam behind `SecureCredentialStorage` (DES-010 §3.4).
///
/// The seam keeps the platform backends replaceable — the Keychain backend
/// serves Apple platforms and the in-memory backend serves the Linux build and
/// automated tests — with no change to the Domain contract (ARC-005). Backends
/// translate their underlying failures into the Domain terms
/// `CredentialStorageError.credentialNotFound` and `.storageUnavailable`
/// (DES-009 §3.7, §3.9), and never log, print, or emit credential material
/// (ARC-001, ARC-005).
internal protocol CredentialStorageBackend: Sendable {
    /// Stores `credential` under `reference`, replacing any previous value.
    func store(_ credential: Credential, for reference: CredentialReference) async throws

    /// Returns the credential stored under `reference`.
    ///
    /// Throws `CredentialStorageError.credentialNotFound` when no credential is
    /// stored for the reference.
    func credential(for reference: CredentialReference) async throws -> Credential

    /// Removes the credential stored under `reference`, if any.
    func removeCredential(for reference: CredentialReference) async throws

    /// Removes every credential in Omnia's app-owned secure-storage namespace.
    func removeAllCredentials() async throws
}

/// The concrete `CredentialStorageProtocol` over the platform backend seam
/// (DES-010 §3.4, ARC-005).
///
/// The implementation stores, retrieves, and removes `Credential` values by
/// their `CredentialReference` (DES-009 §3.7). The default initializer selects
/// the platform backend: the Keychain backend on Apple platforms and the
/// in-memory backend on the Linux build and automated tests (ARC-005). It
/// honors the contract failures exactly — `credentialNotFound` when no
/// credential is stored for a reference and `storageUnavailable` when the
/// backend cannot be reached (DES-009 §3.9) — and never logs, prints, or
/// transmits secrets (ARC-001, ARC-005).
public struct SecureCredentialStorage: CredentialStorageProtocol, Sendable {
    private let backend: any CredentialStorageBackend

    /// Creates the credential storage over the platform-appropriate backend:
    /// the Keychain on Apple platforms, the in-memory backend elsewhere.
    public init() {
        #if canImport(Security)
        self.backend = KeychainCredentialStorageBackend()
        #else
        self.backend = InMemoryCredentialStorageBackend()
        #endif
    }

    /// Creates the credential storage over `backend`; used by tests and by the
    /// Composition Root to bind a specific backend.
    internal init(backend: any CredentialStorageBackend) {
        self.backend = backend
    }

    public func store(_ credential: Credential, for reference: CredentialReference) async throws {
        try await backend.store(credential, for: reference)
    }

    public func credential(for reference: CredentialReference) async throws -> Credential {
        try await backend.credential(for: reference)
    }

    public func removeCredential(for reference: CredentialReference) async throws {
        try await backend.removeCredential(for: reference)
    }

    /// Removes every credential owned by Omnia. This concrete maintenance
    /// surface is used only by the explicitly confirmed Clear Data operation.
    public func removeAllCredentials() async throws {
        try await backend.removeAllCredentials()
    }
}
