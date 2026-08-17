package com.omnia.application

import com.omnia.domain.AttachmentError
import com.omnia.domain.AttachmentIdentity
import com.omnia.domain.AttachmentKind
import com.omnia.domain.AttachmentStorageProtocol
import com.omnia.domain.MessageAttachment
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class AttachmentServiceTest {

    private lateinit var storage: InMemoryAttachmentStorage
    private lateinit var service: AttachmentService

    @Before
    fun setup() {
        storage = InMemoryAttachmentStorage()
        service = AttachmentService(
            storage = storage,
            limits = AttachmentLimits(maximumCount = 3, maximumFileBytes = 1024, maximumAggregateBytes = 3072, maximumExtractedCharacters = 200_000),
        )
    }

    @Test
    fun stage_addsAttachment() {
        runBlocking {
            val candidates = listOf(AttachmentImportCandidate(fileName = "test.txt", data = "hello".toByteArray(), declaredMediaType = "text/plain"))
            val result = service.stage(candidates)
            assertEquals(1, result.size)
            assertEquals("test.txt", result[0].fileName)
        }
    }

    @Test
    fun stage_rejectsOverLimit() {
        runBlocking {
            try {
                val candidates = (1..5).map {
                    AttachmentImportCandidate(fileName = "file$it.txt", data = "data".toByteArray(), declaredMediaType = "text/plain")
                }
                service.stage(candidates)
                throw AssertionError("Expected TooManyFiles")
            } catch (e: AttachmentError.TooManyFiles) {
                // expected
            }
        }
    }

    @Test
    fun stage_rejectsEmptyFile() {
        runBlocking {
            try {
                service.stage(listOf(AttachmentImportCandidate(fileName = "empty.txt", data = ByteArray(0), declaredMediaType = "text/plain")))
                throw AssertionError("Expected Empty")
            } catch (e: AttachmentError.Empty) {
                // expected
            }
        }
    }

    @Test
    fun stage_rejectsOversizedFile() {
        runBlocking {
            try {
                service.stage(listOf(AttachmentImportCandidate(fileName = "big.txt", data = ByteArray(2048), declaredMediaType = "text/plain")))
                throw AssertionError("Expected FileTooLarge")
            } catch (e: AttachmentError.FileTooLarge) {
                // expected
            }
        }
    }

    @Test
    fun stage_supportsExistingAttachments() {
        runBlocking {
            val existing = listOf(
                MessageAttachment(
                    identity = AttachmentIdentity("existing"),
                    fileName = "existing.txt",
                    mediaType = "text/plain",
                    kind = AttachmentKind.plainText,
                    byteCount = 10,
                    storageKey = "existing-key",
                )
            )
            val result = service.stage(
                candidates = listOf(AttachmentImportCandidate(fileName = "new.txt", data = "new".toByteArray(), declaredMediaType = "text/plain")),
                existing = existing,
            )
            assertEquals(2, result.size)
        }
    }

    @Test
    fun detectKind_recognizesImagesAndText() {
        assertEquals(AttachmentKind.image, AttachmentService.detectKind("photo.jpg", null))
        assertEquals(AttachmentKind.image, AttachmentService.detectKind("photo.PNG", null))
        assertEquals(AttachmentKind.pdf, AttachmentService.detectKind("doc.pdf", null))
        assertEquals(AttachmentKind.plainText, AttachmentService.detectKind("readme.md", null))
    }

    @Test
    fun normalizeFileName_trimsAndTruncates() {
        assertEquals("test.txt", AttachmentService.normalizeFileName("  test.txt  "))
        assertEquals("a".repeat(160), AttachmentService.normalizeFileName("a".repeat(200)))
    }

    private class InMemoryAttachmentStorage : AttachmentStorageProtocol {
        private val data = mutableMapOf<String, ByteArray>()
        override suspend fun store(data: ByteArray, identity: AttachmentIdentity, fileExtension: String): String {
            val key = "${identity.id}.$fileExtension"
            this.data[key] = data
            return key
        }
        override suspend fun data(storageKey: String, maximumByteCount: Int): ByteArray =
            data[storageKey] ?: throw IllegalStateException("Not found: $storageKey")
        override suspend fun remove(storageKey: String) { data.remove(storageKey) }
        override suspend fun allStorageKeys(): Set<String> = data.keys.toSet()
    }
}
