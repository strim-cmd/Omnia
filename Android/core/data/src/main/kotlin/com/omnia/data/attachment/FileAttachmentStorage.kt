package com.omnia.data.attachment

import com.omnia.domain.AttachmentError
import com.omnia.domain.AttachmentStorageProtocol
import java.io.File

class FileAttachmentStorage(private val directory: File) : AttachmentStorageProtocol {

    override suspend fun store(data: ByteArray, identity: com.omnia.domain.AttachmentIdentity, fileExtension: String): String {
        val normalizedExtension = fileExtension.lowercase()
        require(normalizedExtension.isNotEmpty())
        require(normalizedExtension.length <= 12)
        require(normalizedExtension.all { ch -> ch.isLetterOrDigit() && ch.code < 128 })

        val key = "${identity.id}.$normalizedExtension"
        try {
            directory.mkdirs()
            val file = validatedFile(key)
            file.writeBytes(data)
            return key
        } catch (e: Exception) {
            if (e is AttachmentError) throw e
            throw AttachmentError.StorageUnavailable
        }
    }

    override suspend fun data(storageKey: String, maximumByteCount: Int): ByteArray {
        require(maximumByteCount >= 0)
        try {
            val file = validatedFile(storageKey)
            if (!file.exists()) throw AttachmentError.StorageUnavailable
            val bytes = file.readBytes()
            if (bytes.size > maximumByteCount) throw AttachmentError.StorageUnavailable
            return bytes
        } catch (e: Exception) {
            if (e is AttachmentError) throw e
            throw AttachmentError.StorageUnavailable
        }
    }

    override suspend fun remove(storageKey: String) {
        try {
            val file = validatedFile(storageKey)
            if (file.exists()) file.delete()
        } catch (e: Exception) {
            if (e is AttachmentError) throw e
            throw AttachmentError.StorageUnavailable
        }
    }

    override suspend fun allStorageKeys(): Set<String> {
        try {
            if (!directory.exists()) return emptySet()
            return directory.listFiles()
                ?.filter { it.isFile }
                ?.map { it.name }
                ?.toSet()
                ?: emptySet()
        } catch (e: Exception) {
            if (e is AttachmentError) throw e
            throw AttachmentError.StorageUnavailable
        }
    }

    private fun validatedFile(key: String): File {
        require(key.isNotEmpty()) { "storage key must not be empty" }
        require(key == File(key).name) { "storage key must be a bare filename" }
        require(!key.contains("/") && !key.contains("\\")) { "storage key must not contain path separators" }
        val candidate = File(directory, key).canonicalFile
        require(candidate.parentFile?.canonicalPath == directory.canonicalFile.canonicalPath) {
            "storage key must not escape the attachment directory"
        }
        return candidate
    }
}
