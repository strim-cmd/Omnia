package com.omnia.application

import com.omnia.common.SemanticVersion
import com.omnia.domain.Credential
import com.omnia.domain.ProviderCapabilities
import com.omnia.domain.ProviderLimits

/**
 * Request to configure a new provider. The credential is transient — it will
 * be stored by reference and the Credential value discarded.
 */
data class ConfigureProviderRequest(
    val displayName: String,
    val capabilities: ProviderCapabilities,
    val limits: ProviderLimits,
    val version: SemanticVersion,
    val credential: Credential,
)

/**
 * Request to update an existing provider's declaration. No credential —
 * editing never requires re-entering the secret.
 */
data class ProviderUpdateRequest(
    val displayName: String,
    val capabilities: ProviderCapabilities,
    val limits: ProviderLimits,
    val version: SemanticVersion,
)

/**
 * Request to send a message. Uses the G-01 runtime truth vocabulary:
 * explicit [modelSelection] rather than stale userSelection/workspacePreference.
 */
data class SendMessageRequest(
    val conversation: com.omnia.domain.ConversationIdentity,
    val message: com.omnia.domain.Message,
    val modelSelection: com.omnia.domain.ProviderModelSelection? = null,
)

/**
 * Attachment import candidate — a file loaded from the platform picker
 * but not yet staged or validated.
 */
data class AttachmentImportCandidate(
    val data: ByteArray,
    val fileName: String,
    val declaredMediaType: String?,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is AttachmentImportCandidate) return false
        return data.contentEquals(other.data) && fileName == other.fileName
    }

    override fun hashCode(): Int = fileName.hashCode() * 31 + data.contentHashCode()
}

/**
 * Deterministic attachment limits matching current Omnia v1.0.0.
 */
data class AttachmentLimits(
    val maximumCount: Int = 8,
    val maximumFileBytes: Int = 10 * 1024 * 1024,     // 10 MB
    val maximumAggregateBytes: Int = 25 * 1024 * 1024, // 25 MB
    val maximumExtractedCharacters: Int = 200_000,      // 200K chars
)
