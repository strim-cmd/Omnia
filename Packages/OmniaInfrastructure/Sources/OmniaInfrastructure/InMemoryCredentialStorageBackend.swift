import OmniaDomain

/// The in-memory `CredentialStorageBackend` (DES-010 §3.4).
///
/// Serves the Linux build and automated tests, where the Keychain is not
/// available, with no change to the Domain contract (ARC-005). The actor
/// isolates the mutable dictionary so the storage is safe to share across
/// concurrency domains.
internal actor InMemoryCredentialStorageBackend: CredentialStorageBackend {
    private var storage: [CredentialReference: Credential] = [:]

    func store(_ credential: Credential, for reference: CredentialReference) async throws {
        storage[reference] = credential
    }

    func credential(for reference: CredentialReference) async throws -> Credential {
        guard let credential = storage[reference] else {
            throw CredentialStorageError.credentialNotFound
        }
        return credential
    }

    func removeCredential(for reference: CredentialReference) async throws {
        storage.removeValue(forKey: reference)
    }

    func removeAllCredentials() async throws {
        storage.removeAll()
    }
}
