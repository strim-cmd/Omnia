package com.omnia.network.adapters

import com.omnia.domain.Credential
import com.omnia.domain.CredentialReference
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Verifies that FixedCredentialStorage never persists, stores, or removes
 * any credential data. It is a non-persisting credential source for
 * unsaved Test Connection requests.
 */
class FixedCredentialStorageTest {

    @Test
    fun credentialReturnsFixedValue() = runTest {
        val credential = Credential.of("my-secret-key")
        val storage = FixedCredentialStorage(credential)
        val ref = CredentialReference(id = "test-ref")

        val result = storage.credential(ref)
        result.withValue { assertEquals("my-secret-key", it) }
    }

    @Test
    fun storeDoesNothing() = runTest {
        val storage = FixedCredentialStorage(Credential.of("original"))
        val ref = CredentialReference(id = "ref-1")

        storage.store(Credential.of("should-not-persist"), ref)

        val result = storage.credential(ref)
        result.withValue { assertEquals("original", it) }
    }

    @Test
    fun removeCredentialDoesNothing() = runTest {
        val storage = FixedCredentialStorage(Credential.of("my-key"))
        val ref = CredentialReference(id = "ref-1")

        storage.removeCredential(ref)

        val result = storage.credential(ref)
        result.withValue { assertEquals("my-key", it) }
    }

    @Test
    fun differentReferencesReturnSameValue() = runTest {
        val storage = FixedCredentialStorage(Credential.of("fixed-key"))
        val ref1 = CredentialReference(id = "ref-1")
        val ref2 = CredentialReference(id = "ref-2")

        storage.credential(ref1).withValue { assertEquals("fixed-key", it) }
        storage.credential(ref2).withValue { assertEquals("fixed-key", it) }
    }
}
