import XCTest
import OmniaDomain
@testable import OmniaInfrastructure

final class SecureCredentialStorageTests: XCTestCase {

    private func makeStorage() -> SecureCredentialStorage {
        SecureCredentialStorage(backend: InMemoryCredentialStorageBackend())
    }

    // MARK: - Store / retrieve round-trip

    func testStoreAndRetrieve_RoundTripsTheCredential() async throws {
        let storage = makeStorage()
        let reference = CredentialReference()
        let credential = Credential(secret: "sk-roundtrip")

        try await storage.store(credential, for: reference)
        let retrieved = try await storage.credential(for: reference)

        XCTAssertEqual(retrieved, credential)
        retrieved.withValue { XCTAssertEqual($0, "sk-roundtrip") }
    }

    func testStore_ReplacesThePreviousValue() async throws {
        let storage = makeStorage()
        let reference = CredentialReference()

        try await storage.store(Credential(secret: "first"), for: reference)
        try await storage.store(Credential(secret: "second"), for: reference)

        let retrieved = try await storage.credential(for: reference)
        retrieved.withValue { XCTAssertEqual($0, "second") }
    }

    func testStore_ReferencesAreIndependent() async throws {
        let storage = makeStorage()
        let first = CredentialReference()
        let second = CredentialReference()

        try await storage.store(Credential(secret: "first-only"), for: first)

        do {
            _ = try await storage.credential(for: second)
            XCTFail("Expected credentialNotFound for the unstored reference")
        } catch CredentialStorageError.credentialNotFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Not found

    func testRetrieve_ThrowsNotFoundWhenNothingStored() async {
        let storage = makeStorage()
        let reference = CredentialReference()

        do {
            _ = try await storage.credential(for: reference)
            XCTFail("Expected credentialNotFound")
        } catch CredentialStorageError.credentialNotFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Remove

    func testRemove_DeletesTheStoredCredential() async throws {
        let storage = makeStorage()
        let reference = CredentialReference()

        try await storage.store(Credential(secret: "to-remove"), for: reference)
        try await storage.removeCredential(for: reference)

        do {
            _ = try await storage.credential(for: reference)
            XCTFail("Expected credentialNotFound after removal")
        } catch CredentialStorageError.credentialNotFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRemove_IsIdempotent() async throws {
        let storage = makeStorage()
        let reference = CredentialReference()

        try await storage.removeCredential(for: reference)
        try await storage.removeCredential(for: reference)
    }

    // MARK: - Default backend selection

    func testDefaultInitializer_RoundTripsAndCleansUp() async throws {
        let storage = SecureCredentialStorage()
        let reference = CredentialReference()
        let credential = Credential(secret: "sk-default-backend")

        try await storage.store(credential, for: reference)
        let retrieved = try await storage.credential(for: reference)
        XCTAssertEqual(retrieved, credential)

        try await storage.removeCredential(for: reference)
        do {
            _ = try await storage.credential(for: reference)
            XCTFail("Expected credentialNotFound after cleanup")
        } catch CredentialStorageError.credentialNotFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Redaction

    func testCredential_NeverRevealsTheSecretInAnyRepresentation() async throws {
        let storage = makeStorage()
        let reference = CredentialReference()
        let secret = "sk-super-secret-value"
        try await storage.store(Credential(secret: secret), for: reference)

        let retrieved = try await storage.credential(for: reference)

        XCTAssertEqual(retrieved.description, "Credential(<redacted>)")
        XCTAssertEqual(retrieved.debugDescription, "Credential(<redacted>)")
        XCTAssertFalse(String(describing: retrieved).contains(secret))
        XCTAssertFalse(String(describing: retrieved).contains("sk-"))
        XCTAssertFalse("\(retrieved)".contains(secret))
    }

    func testStorage_IsShareableAcrossConcurrencyDomains() async throws {
        let storage = makeStorage()
        let reference = CredentialReference()
        try await storage.store(Credential(secret: "sk-concurrent"), for: reference)

        let retrieved: Credential? = await Task.detached {
            try? await storage.credential(for: reference)
        }.value
        XCTAssertEqual(retrieved, Credential(secret: "sk-concurrent"))
    }
}
