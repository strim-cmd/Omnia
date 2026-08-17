package com.omnia.data.attachment

import com.omnia.domain.AttachmentError
import com.omnia.domain.AttachmentIdentity
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

class FileAttachmentStorageTest {

    private lateinit var tempDir: File
    private lateinit var storage: FileAttachmentStorage

    @Before
    fun setup() {
        tempDir = Files.createTempDirectory("AttachmentTests").toFile()
        storage = FileAttachmentStorage(tempDir)
    }

    @After
    fun teardown() {
        tempDir.deleteRecursively()
    }

    @Test
    fun store_then_data_roundTripsBytes() = runBlocking {
        val bytes = "Hello, World!".toByteArray()
        val key = storage.store(bytes, AttachmentIdentity("att-1"), "txt")
        val loaded = storage.data(key, 1024)
        assertArrayEquals(bytes, loaded)
    }

    @Test
    fun store_keyIsOpaqueFilename() = runBlocking {
        val bytes = "data".toByteArray()
        val key = storage.store(bytes, AttachmentIdentity("att-1"), "png")
        assertFalse(key.contains("/"))
        assertFalse(key.contains("\\"))
        assertTrue(key.startsWith("att-1.png"))
    }

    @Test
    fun allStorageKeys_containsStoredKey() = runBlocking {
        val bytes = "data".toByteArray()
        val key = storage.store(bytes, AttachmentIdentity("att-1"), "txt")
        val keys = storage.allStorageKeys()
        assertTrue(key in keys)
    }

    @Test
    fun data_withLowerMaximumByteCount_throwsStorageUnavailable() = runBlocking {
        val bytes = ByteArray(100) { it.toByte() }
        val key = storage.store(bytes, AttachmentIdentity("att-1"), "bin")
        try {
            storage.data(key, 10)
            fail("Should have thrown")
        } catch (e: AttachmentError.StorageUnavailable) {
            // expected
        }
    }

    @Test
    fun data_withPathTraversal_throwsStorageUnavailable() = runBlocking {
        val bytes = "data".toByteArray()
        val key = storage.store(bytes, AttachmentIdentity("att-1"), "txt")
        try {
            storage.data("../$key", 1024)
            fail("Should have thrown")
        } catch (e: AttachmentError.StorageUnavailable) {
            // expected
        }
    }

    @Test
    fun remove_deletesTheFile() = runBlocking {
        val bytes = "data".toByteArray()
        val key = storage.store(bytes, AttachmentIdentity("att-1"), "txt")
        storage.remove(key)
        assertTrue(storage.allStorageKeys().isEmpty())
    }

    @Test
    fun remove_isIdempotent() = runBlocking {
        val bytes = "data".toByteArray()
        val key = storage.store(bytes, AttachmentIdentity("att-1"), "txt")
        storage.remove(key)
        storage.remove(key)
    }

    @Test
    fun store_dataIsCopiedIntoOwnedDirectory() = runBlocking {
        val source = File(tempDir, "source.txt")
        source.writeText("original content")
        val bytes = source.readBytes()

        val key = storage.store(bytes, AttachmentIdentity("att-1"), "txt")

        source.delete()
        val loaded = storage.data(key, 1024)
        assertArrayEquals("original content".toByteArray(), loaded)
    }

    @Test(expected = AttachmentError.StorageUnavailable::class)
    fun data_nonexistentKey_throws() {
        runBlocking {
            storage.data("nonexistent.txt", 1024)
        }
    }

    @Test
    fun freshInstance_loadsPreviouslyPersistedData() = runBlocking {
        val bytes = "persisted content".toByteArray()
        val key = storage.store(bytes, AttachmentIdentity("att-1"), "txt")

        val freshStorage = FileAttachmentStorage(tempDir)
        val loaded = freshStorage.data(key, 1024)
        assertArrayEquals(bytes, loaded)
        assertTrue(key in freshStorage.allStorageKeys())
    }
}
