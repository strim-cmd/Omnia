package com.omnia.security

import android.content.Context
import com.omnia.domain.Credential
import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageError
import com.omnia.domain.CredentialStorageProtocol
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import android.util.Base64

/**
 * Android Keystore-backed credential storage. Encrypts credentials with
 * AES/GCM using a non-exportable Keystore key.
 *
 * NOT VERIFIED under Robolectric — requires real Android Keystore.
 */
class SecureCredentialStorage(context: Context) : CredentialStorageProtocol {

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val keyAlias = "omnia_credential_key"

    init {
        ensureKeyExists()
    }

    override suspend fun store(credential: Credential, reference: CredentialReference) {
        credential.withValue { secret ->
            val key = getOrCreateKey()
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, key)
            val iv = cipher.iv
            val encrypted = cipher.doFinal(secret.toByteArray(Charsets.UTF_8))
            val payload = iv + encrypted
            val encoded = Base64.encodeToString(payload, Base64.NO_WRAP)
            prefs.edit().putString(reference.id, encoded).apply()
        }
    }

    override suspend fun credential(reference: CredentialReference): Credential {
        val encoded = prefs.getString(reference.id, null)
            ?: throw CredentialStorageError.CredentialNotFound
        return try {
            val payload = Base64.decode(encoded, Base64.NO_WRAP)
            val key = getOrCreateKey()
            val iv = payload.sliceArray(0 until GCM_IV_LENGTH)
            val ciphertext = payload.sliceArray(GCM_IV_LENGTH until payload.size)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
            cipher.init(Cipher.DECRYPT_MODE, key, spec)
            val decrypted = cipher.doFinal(ciphertext)
            Credential.of(String(decrypted, Charsets.UTF_8))
        } catch (e: Exception) {
            throw CredentialStorageError.StorageUnavailable
        }
    }

    override suspend fun removeCredential(reference: CredentialReference) {
        prefs.edit().remove(reference.id).apply()
    }

    suspend fun removeAllCredentials() {
        prefs.edit().clear().apply()
    }

    fun storedReferences(): Set<String> {
        return prefs.all.keys
    }

    private fun ensureKeyExists() {
        getOrCreateKey()
    }

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        keyStore.getEntry(keyAlias, null)?.let { entry ->
            return (entry as KeyStore.SecretKeyEntry).secretKey
        }
        val keyGen = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore"
        )
        keyGen.init(
            KeyGenParameterSpec.Builder(
                keyAlias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setUserAuthenticationRequired(false)
                .setRandomizedEncryptionRequired(true)
                .build()
        )
        return keyGen.generateKey()
    }

    companion object {
        private const val PREFS_NAME = "omnia_credentials"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_IV_LENGTH = 12
        private const val GCM_TAG_LENGTH = 128
    }
}
