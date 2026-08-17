package com.omnia.security

import com.omnia.domain.Credential
import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageError
import com.omnia.domain.CredentialStorageProtocol

/**
 * In-memory credential storage for JVM tests. Not suitable for production.
 */
class InMemoryCredentialStorage : CredentialStorageProtocol {
    private val storage = mutableMapOf<String, Credential>()
    private val lock = Any()

    override suspend fun store(credential: Credential, reference: CredentialReference) {
        synchronized(lock) {
            storage[reference.id] = credential
        }
    }

    override suspend fun credential(reference: CredentialReference): Credential {
        synchronized(lock) {
            return storage[reference.id]
                ?: throw CredentialStorageError.CredentialNotFound
        }
    }

    override suspend fun removeCredential(reference: CredentialReference) {
        synchronized(lock) {
            storage.remove(reference.id)
        }
    }

    suspend fun removeAllCredentials() {
        synchronized(lock) {
            storage.clear()
        }
    }

    fun storedReferences(): Set<String> {
        synchronized(lock) {
            return storage.keys.toSet()
        }
    }
}
