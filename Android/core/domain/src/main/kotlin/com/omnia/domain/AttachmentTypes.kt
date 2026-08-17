package com.omnia.domain

/**
 * Durable attachment kind taxonomy.
 */
enum class AttachmentKind {
    image,
    pdf,
    plainText,
}

/**
 * Durable metadata carried in conversation history. Never contains file bytes
 * or extracted text — only an opaque [storageKey] for the storage backend.
 */
data class MessageAttachment(
    val identity: AttachmentIdentity,
    val fileName: String,
    val mediaType: String,
    val kind: AttachmentKind,
    val byteCount: Int,
    val storageKey: String,
)

/**
 * Transient validated payload ready for storage or transmission.
 */
data class PreparedAttachmentContent(
    val data: ByteArray,
    val fileName: String,
    val mediaType: String,
    val kind: AttachmentKind,
    val fileExtension: String,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is PreparedAttachmentContent) return false
        return data.contentEquals(other.data) && fileName == other.fileName
    }

    override fun hashCode(): Int = fileName.hashCode() * 31 + data.contentHashCode()
}

/**
 * Payload carried for a single request resolution. Either raw image bytes
 * or extracted text.
 */
sealed class AttachmentPayload {
    data class Image(val data: ByteArray, val mediaType: String) : AttachmentPayload() {
        override fun equals(other: Any?): Boolean {
            if (this === other) return true
            if (other !is Image) return false
            return data.contentEquals(other.data) && mediaType == other.mediaType
        }
        override fun hashCode(): Int = data.contentHashCode() + mediaType.hashCode()
    }

    data class ExtractedText(val text: String) : AttachmentPayload()
}

/**
 * A durable reference paired with its transient payload for a single request.
 */
data class ResolvedAttachment(
    val attachment: MessageAttachment,
    val payload: AttachmentPayload,
)

/**
 * Normalized attachment errors. Carries only leaf filenames, counts, and
 * limits — never private paths or contents.
 */
sealed class AttachmentError(message: String) : Exception(message) {
    data class UnsupportedType(val fileName: String) : AttachmentError("Unsupported file type: $fileName")
    data class Unreadable(val fileName: String) : AttachmentError("Cannot read file: $fileName")
    data class PhotoLoadFailed(val fileName: String) : AttachmentError("Failed to load photo: $fileName")
    data class Empty(val fileName: String) : AttachmentError("File is empty: $fileName")
    data class FileTooLarge(val fileName: String, val limit: Int) :
        AttachmentError("File '$fileName' exceeds ${limit / 1024 / 1024}MB limit")

    data class AggregateTooLarge(val limit: Int) :
        AttachmentError("Total attachment size exceeds ${limit / 1024 / 1024}MB limit")

    data class TooManyFiles(val limit: Int) :
        AttachmentError("Too many files: limit is $limit")

    data class Duplicate(val fileName: String) :
        AttachmentError("Duplicate file: $fileName")

    data class CapabilityUnsupported(val kind: AttachmentKind) :
        AttachmentError("Attachment kind '$kind' is not supported by the selected model")

    data class CapabilityUnknown(val kind: AttachmentKind) :
        AttachmentError("Attachment kind '$kind' capability is unknown for the selected model")

    data object ProviderRejected : AttachmentError("Provider rejected the attachments")

    data class ExtractionFailed(val fileName: String) :
        AttachmentError("Text extraction failed for: $fileName")

    data class ExtractedTextTooLarge(val fileName: String, val limit: Int) :
        AttachmentError("Extracted text from '$fileName' exceeds $limit character limit")

    data object StorageUnavailable : AttachmentError("Attachment storage is unavailable")
}
