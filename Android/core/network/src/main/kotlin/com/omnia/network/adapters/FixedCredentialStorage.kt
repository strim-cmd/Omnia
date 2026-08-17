package com.omnia.network.adapters

import com.omnia.domain.Credential
import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageProtocol
import com.omnia.domain.CredentialStorageError

/**
 * Non-persisting credential source for unsaved Test Connection requests.
 * The credential remains opaque and is never written to storage.
 */
class FixedCredentialStorage(private val credentialValue: Credential) : CredentialStorageProtocol {
    override suspend fun store(credential: Credential, reference: CredentialReference) {}
    override suspend fun credential(reference: CredentialReference): Credential = credentialValue
    override suspend fun removeCredential(reference: CredentialReference) {}
}
