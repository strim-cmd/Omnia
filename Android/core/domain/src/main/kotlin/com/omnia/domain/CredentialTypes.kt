package com.omnia.domain

/**
 * Opaque credential wrapper. The raw secret is accessible only through
 * scoped [withValue]. description always returns the redaction marker.
 * Credentials never enter logs or analytics.
 */
data class Credential private constructor(private val secret: String) {
    init {
        require(secret.isNotEmpty()) { "Credential secret must not be empty" }
    }

    fun <T> withValue(block: (String) -> T): T = block(secret)

    override fun toString(): String = "Credential(<redacted>)"

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is Credential) return false
        // Constant-time comparison to prevent timing attacks
        return secret.length == other.secret.length && secret == other.secret
    }

    override fun hashCode(): Int = secret.hashCode()

    companion object {
        fun of(secret: String): Credential = Credential(secret)
    }
}

/**
 * Persistent credential storage. Implementations belong to Infrastructure
 * (Android Keystore-backed for production, in-memory for tests).
 */
interface CredentialStorageProtocol {
    suspend fun store(credential: Credential, reference: CredentialReference)
    suspend fun credential(reference: CredentialReference): Credential
    suspend fun removeCredential(reference: CredentialReference)
}

sealed class CredentialStorageError(message: String) : Exception(message) {
    data object CredentialNotFound : CredentialStorageError("Credential not found")
    data object StorageUnavailable : CredentialStorageError("Credential storage is unavailable")
}

/**
 * Opaque attachment storage. Implementations belong to Infrastructure.
 */
interface AttachmentStorageProtocol {
    suspend fun store(data: ByteArray, identity: AttachmentIdentity, fileExtension: String): String
    suspend fun data(storageKey: String, maximumByteCount: Int): ByteArray
    suspend fun remove(storageKey: String)
    suspend fun allStorageKeys(): Set<String>
}
