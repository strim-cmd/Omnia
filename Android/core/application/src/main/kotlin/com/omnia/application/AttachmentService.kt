package com.omnia.application

import com.omnia.domain.AttachmentError
import com.omnia.domain.AttachmentIdentity
import com.omnia.domain.AttachmentKind
import com.omnia.domain.AttachmentPayload
import com.omnia.domain.AttachmentStorageProtocol
import com.omnia.domain.Capability
import com.omnia.domain.MessageAttachment
import com.omnia.domain.ModelCapabilitySupport
import com.omnia.domain.ProviderModelSelection
import com.omnia.domain.ResolvedAttachment

/**
 * Attachment service — coordinates staging, validation, resolution,
 * and cleanup of file attachments.
 *
 * Atomicity: [stage] tracks all newly stored files and rolls back
 * (removes them from storage) if any candidate fails. The existing
 * staged set is never mutated on failure.
 */
class AttachmentService(
    private val storage: AttachmentStorageProtocol,
    private val limits: AttachmentLimits = AttachmentLimits(),
    private val effectiveSupport: suspend (Capability, ProviderModelSelection) -> ModelCapabilitySupport = { _, _ -> ModelCapabilitySupport.unknown },
) {
    /**
     * Atomically stages a batch of candidates. Validates count, per-file
     * size, aggregate size, emptiness. Returns the staged attachments.
     */
    @Throws(AttachmentError::class)
    suspend fun stage(
        candidates: List<AttachmentImportCandidate>,
        existing: List<MessageAttachment> = emptyList(),
    ): List<MessageAttachment> {
        val totalCount = existing.size + candidates.size
        if (totalCount > limits.maximumCount) {
            throw AttachmentError.TooManyFiles(limits.maximumCount)
        }

        val staged = mutableListOf<MessageAttachment>()
        val newlyStored = mutableListOf<String>()

        try {
            for (candidate in candidates) {
                if (candidate.data.isEmpty()) {
                    throw AttachmentError.Empty(candidate.fileName)
                }
                if (candidate.data.size > limits.maximumFileBytes) {
                    throw AttachmentError.FileTooLarge(candidate.fileName, limits.maximumFileBytes)
                }

                val totalBytes = existing.sumOf { it.byteCount } +
                    staged.sumOf { it.byteCount } + candidate.data.size
                if (totalBytes > limits.maximumAggregateBytes) {
                    throw AttachmentError.AggregateTooLarge(limits.maximumAggregateBytes)
                }

                val identity = AttachmentIdentity(id = generateId())
                val kind = detectKind(candidate.fileName, candidate.declaredMediaType)
                val ext = fileExtension(candidate.fileName)

                val storageKey = storage.store(candidate.data, identity, ext)
                newlyStored.add(storageKey)

                staged.add(
                    MessageAttachment(
                        identity = identity,
                        fileName = normalizeFileName(candidate.fileName),
                        mediaType = candidate.declaredMediaType ?: "application/octet-stream",
                        kind = kind,
                        byteCount = candidate.data.size,
                        storageKey = storageKey,
                    )
                )
            }
            return existing + staged
        } catch (e: Exception) {
            // Rollback: remove all newly stored files
            for (key in newlyStored) {
                try {
                    storage.remove(key)
                } catch (_: Exception) { }
            }
            throw e
        }
    }

    /**
     * Validates staged attachments against limits AND the specific
     * provider/model route's capability support.
     */
    @Throws(AttachmentError::class)
    suspend fun validate(
        attachments: List<MessageAttachment>,
        selection: ProviderModelSelection,
    ) {
        if (attachments.size > limits.maximumCount) {
            throw AttachmentError.TooManyFiles(limits.maximumCount)
        }
        val totalBytes = attachments.sumOf { it.byteCount }
        if (totalBytes > limits.maximumAggregateBytes) {
            throw AttachmentError.AggregateTooLarge(limits.maximumAggregateBytes)
        }
        for (attachment in attachments) {
            val requiredCapability = capabilityFor(attachment.kind)
            val support = effectiveSupport(requiredCapability, selection)
            when (support) {
                ModelCapabilitySupport.supported -> { /* OK */ }
                ModelCapabilitySupport.unsupported -> throw AttachmentError.CapabilityUnsupported(attachment.kind)
                ModelCapabilitySupport.unknown -> throw AttachmentError.CapabilityUnknown(attachment.kind)
            }
        }
    }

    /**
     * Resolves durable attachment references into transient payloads.
     * Reads bytes from storage, creates Image or ExtractedText payloads.
     */
    @Throws(AttachmentError::class)
    suspend fun resolve(
        attachments: List<MessageAttachment>,
    ): List<ResolvedAttachment> {
        return attachments.map { attachment ->
            val data = try {
                storage.data(attachment.storageKey, limits.maximumFileBytes)
            } catch (e: Exception) {
                throw AttachmentError.Unreadable(attachment.fileName)
            }

            val payload = when (attachment.kind) {
                AttachmentKind.image -> AttachmentPayload.Image(
                    data = data,
                    mediaType = attachment.mediaType,
                )
                AttachmentKind.pdf, AttachmentKind.plainText -> AttachmentPayload.ExtractedText(
                    text = String(data, Charsets.UTF_8),
                )
            }

            ResolvedAttachment(attachment = attachment, payload = payload)
        }
    }

    /** Removes attachment bytes from storage. */
    suspend fun remove(attachment: MessageAttachment) {
        try {
            storage.remove(attachment.storageKey)
        } catch (_: Exception) { }
    }

    /** Removes multiple attachments. */
    suspend fun remove(attachments: List<MessageAttachment>) {
        for (attachment in attachments) {
            remove(attachment)
        }
    }

    /** Finds and removes stored files not referenced by any persisted message. */
    suspend fun cleanupOrphans(referencedBy: List<MessageAttachment>): Int {
        val referencedKeys = referencedBy.map { it.storageKey }.toSet()
        val allKeys = storage.allStorageKeys()
        val orphans = allKeys - referencedKeys
        for (key in orphans) {
            try {
                storage.remove(key)
            } catch (_: Exception) { }
        }
        return orphans.size
    }

    companion object {
        fun capabilityFor(kind: AttachmentKind): Capability = when (kind) {
            AttachmentKind.image -> Capability.vision
            AttachmentKind.pdf, AttachmentKind.plainText -> Capability.documentInput
        }

        fun normalizeFileName(fileName: String): String {
            val name = fileName.substringAfterLast('/').substringAfterLast('\\')
            return name.trim().take(160)
        }

        fun detectKind(fileName: String, mediaType: String?): AttachmentKind {
            val ext = fileExtension(fileName).lowercase()
            val mime = mediaType?.lowercase() ?: ""
            return when {
                ext in IMAGE_EXTENSIONS || mime.startsWith("image/") -> AttachmentKind.image
                ext == "pdf" || mime == "application/pdf" -> AttachmentKind.pdf
                ext in TEXT_EXTENSIONS || mime.startsWith("text/") -> AttachmentKind.plainText
                else -> AttachmentKind.plainText // Default to text for extraction
            }
        }

        fun fileExtension(fileName: String): String {
            val name = fileName.substringAfterLast('/').substringAfterLast('\\')
            val dotIndex = name.lastIndexOf('.')
            return if (dotIndex > 0 && dotIndex < name.length - 1) {
                name.substring(dotIndex + 1)
            } else {
                ""
            }
        }

        private val IMAGE_EXTENSIONS = setOf("jpg", "jpeg", "png", "gif", "webp", "heic", "heif")
        private val TEXT_EXTENSIONS = setOf("txt", "md", "csv", "json", "xml", "yaml", "yml", "toml")
    }

    private fun generateId(): String = java.util.UUID.randomUUID().toString()
}
