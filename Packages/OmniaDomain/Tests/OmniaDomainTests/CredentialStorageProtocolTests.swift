import Foundation
import XCTest
@testable import OmniaDomain

private let canonicalProviderA = "550E8400-E29B-41D4-A716-446655440000"
private let canonicalProviderB = "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"

private actor InMemoryCredentialStorage: CredentialStorageProtocol {
    private var storage: [CredentialReference: Credential] = [:]

    func store(_ credential: Credential, for reference: CredentialReference) {
        storage[reference] = credential
    }

    func credential(for reference: CredentialReference) throws -> Credential {
        guard let credential = storage[reference] else {
            throw CredentialStorageError.credentialNotFound
        }
        return credential
    }

    func removeCredential(for reference: CredentialReference) {
        storage.removeValue(forKey: reference)
    }
}

final class CredentialStorageProtocolTests: XCTestCase {

    func testStoreAndRetrieve_RoundTripsTheCredential() async throws {
        let storage = InMemoryCredentialStorage()
        let reference = CredentialReference()
        let credential = Credential(secret: "sk-roundtrip")

        await storage.store(credential, for: reference)
        let retrieved = try await storage.credential(for: reference)

        XCTAssertEqual(retrieved, credential)
    }

    func testStore_ReplacesThePreviousValue() async throws {
        let storage = InMemoryCredentialStorage()
        let reference = CredentialReference()

        await storage.store(Credential(secret: "first"), for: reference)
        await storage.store(Credential(secret: "second"), for: reference)

        let retrieved = try await storage.credential(for: reference)
        retrieved.withValue { XCTAssertEqual($0, "second") }
    }

    func testRetrieve_ThrowsNotFoundWhenNothingStored() async {
        let storage = InMemoryCredentialStorage()
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

    func testStore_ReferencesAreIndependent() async throws {
        let storage = InMemoryCredentialStorage()
        let first = try XCTUnwrap(CredentialReference(restoring: canonicalProviderA))
        let second = try XCTUnwrap(CredentialReference(restoring: canonicalProviderB))

        await storage.store(Credential(secret: "provider-a"), for: first)

        do {
            _ = try await storage.credential(for: second)
            XCTFail("Expected credentialNotFound for the unstored reference")
        } catch CredentialStorageError.credentialNotFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRemove_DeletesTheStoredCredential() async throws {
        let storage = InMemoryCredentialStorage()
        let reference = CredentialReference()

        await storage.store(Credential(secret: "to-remove"), for: reference)
        await storage.removeCredential(for: reference)

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
        let storage = InMemoryCredentialStorage()
        let reference = CredentialReference()
        await storage.removeCredential(for: reference)
        await storage.removeCredential(for: reference)
    }

    func testStorageError_IsEquatable() {
        XCTAssertEqual(
            CredentialStorageError.credentialNotFound,
            CredentialStorageError.credentialNotFound
        )
        XCTAssertNotEqual(
            CredentialStorageError.credentialNotFound,
            CredentialStorageError.storageUnavailable
        )
    }

    func testSendability_ShareStorageAcrossConcurrencyDomain() async throws {
        let storage = InMemoryCredentialStorage()
        let reference = CredentialReference()
        await storage.store(Credential(secret: "sk-concurrent"), for: reference)

        let retrieved: Credential? = await Task.detached {
            try? await storage.credential(for: reference)
        }.value
        XCTAssertEqual(retrieved, Credential(secret: "sk-concurrent"))
    }
}
