package com.omnia.security

import com.omnia.domain.Credential
import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageError
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class InMemoryCredentialStorageTest {

    private lateinit var storage: InMemoryCredentialStorage

    @Before
    fun setup() {
        storage = InMemoryCredentialStorage()
    }

    @Test
    fun store_and_retrieve_roundTripsTheCredential() = runBlocking {
        val ref = CredentialReference("ref-1")
        val credential = Credential.of("my-secret-key")
        storage.store(credential, ref)

        val loaded = storage.credential(ref)
        loaded.withValue { secret ->
            assertEquals("my-secret-key", secret)
        }
    }

    @Test
    fun store_replacesThePreviousValue() = runBlocking {
        val ref = CredentialReference("ref-1")
        storage.store(Credential.of("first"), ref)
        storage.store(Credential.of("second"), ref)

        storage.credential(ref).withValue { secret ->
            assertEquals("second", secret)
        }
    }

    @Test
    fun store_referencesAreIndependent() = runBlocking {
        val ref1 = CredentialReference("ref-1")
        val ref2 = CredentialReference("ref-2")
        storage.store(Credential.of("secret-1"), ref1)
        storage.store(Credential.of("secret-2"), ref2)

        storage.credential(ref1).withValue { assertEquals("secret-1", it) }
        storage.credential(ref2).withValue { assertEquals("secret-2", it) }
    }

    @Test(expected = CredentialStorageError.CredentialNotFound::class)
    fun retrieve_throwsNotFoundWhenNothingStored() {
        runBlocking {
            storage.credential(CredentialReference("nonexistent"))
        }
    }

    @Test
    fun remove_deletesTheStoredCredential() = runBlocking {
        val ref = CredentialReference("ref-1")
        storage.store(Credential.of("secret"), ref)
        storage.removeCredential(ref)

        try {
            storage.credential(ref)
            fail("Should have thrown")
        } catch (e: CredentialStorageError.CredentialNotFound) {
            // expected
        }
    }

    @Test
    fun remove_isIdempotent() = runBlocking {
        val ref = CredentialReference("ref-1")
        storage.store(Credential.of("secret"), ref)
        storage.removeCredential(ref)
        storage.removeCredential(ref)
    }

    @Test
    fun removeAllCredentials_deletesEveryCredentialAndIsIdempotent() = runBlocking {
        storage.store(Credential.of("s1"), CredentialReference("ref-1"))
        storage.store(Credential.of("s2"), CredentialReference("ref-2"))

        storage.removeAllCredentials()
        assertEquals(0, storage.storedReferences().size)

        storage.removeAllCredentials()
    }

    @Test
    fun storedReferences_returnsAllStoredReferenceIds() = runBlocking {
        storage.store(Credential.of("s1"), CredentialReference("ref-1"))
        storage.store(Credential.of("s2"), CredentialReference("ref-2"))

        val refs = storage.storedReferences()
        assertEquals(setOf("ref-1", "ref-2"), refs)
    }

    @Test
    fun credential_neverRevealsTheSecretInToString() = runBlocking {
        val credential = Credential.of("super-secret")
        assertFalse(credential.toString().contains("super-secret"))
        assertTrue(credential.toString().contains("redacted"))
    }

    @Test
    fun removeAllCredentials_purgesOrphanedReferencesFromCredentialStore() = runBlocking {
        storage.store(Credential.of("s1"), CredentialReference("ref-1"))
        storage.store(Credential.of("s2"), CredentialReference("ref-2"))
        storage.store(Credential.of("s3"), CredentialReference("ref-3"))

        storage.removeAllCredentials()

        assertEquals(0, storage.storedReferences().size)
        for (ref in listOf("ref-1", "ref-2", "ref-3")) {
            try {
                storage.credential(CredentialReference(ref))
                fail("Should have thrown after purge for ref: $ref")
            } catch (e: CredentialStorageError.CredentialNotFound) {
                // expected
            }
        }
    }

    @Test
    fun storedReferences_returnsEmptyAfterPurge() = runBlocking {
        storage.store(Credential.of("s1"), CredentialReference("ref-1"))
        storage.removeAllCredentials()
        assertTrue(storage.storedReferences().isEmpty())
    }
}
