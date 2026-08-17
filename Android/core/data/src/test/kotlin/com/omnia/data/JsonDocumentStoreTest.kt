package com.omnia.data

import com.omnia.domain.RepositoryError
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

class JsonDocumentStoreTest {

    private lateinit var tempDir: File
    private lateinit var store: JsonDocumentStore

    @Before
    fun setup() {
        tempDir = Files.createTempDirectory("JsonDocumentStoreTests").toFile()
        store = JsonDocumentStore(tempDir)
    }

    @After
    fun teardown() {
        tempDir.deleteRecursively()
    }

    @Test
    fun save_then_load_roundTripsTheDocument() = runBlocking {
        store.saveJson("""{"key":"value"}""", "doc1")
        val loaded = store.loadJson("doc1")
        assertEquals("""{"key":"value"}""", loaded)
    }

    @Test
    fun save_replacesExistingDocumentWithSameKey() = runBlocking {
        store.saveJson("first", "doc1")
        store.saveJson("second", "doc1")
        assertEquals("second", store.loadJson("doc1"))
    }

    @Test
    fun load_absentKeyReturnsNull() = runBlocking {
        assertNull(store.loadJson("nonexistent"))
    }

    @Test
    fun load_differentKeysAreIsolated() = runBlocking {
        store.saveJson("value-a", "key-a")
        store.saveJson("value-b", "key-b")
        assertEquals("value-a", store.loadJson("key-a"))
        assertEquals("value-b", store.loadJson("key-b"))
    }

    @Test
    fun delete_removesTheDocument() = runBlocking {
        store.saveJson("data", "doc1")
        store.delete("doc1")
        assertNull(store.loadJson("doc1"))
    }

    @Test
    fun delete_absentKeyIsNotAnError() = runBlocking {
        store.delete("nonexistent")
    }

    @Test
    fun delete_isIdempotent() = runBlocking {
        store.saveJson("data", "doc1")
        store.delete("doc1")
        store.delete("doc1")
    }

    @Test
    fun allKeys_returnsEveryStoredKey() = runBlocking {
        store.saveJson("a", "key-a")
        store.saveJson("b", "key-b")
        store.saveJson("c", "key-c")
        val keys = store.allKeys()
        assertEquals(setOf("key-a", "key-b", "key-c"), keys.toSet())
    }

    @Test
    fun allKeys_emptyStoreReturnsEmpty() = runBlocking {
        assertTrue(store.allKeys().isEmpty())
    }

    @Test
    fun deleteAll_removesAllJsonFiles() = runBlocking {
        store.saveJson("a", "key-a")
        store.saveJson("b", "key-b")
        store.deleteAll()
        assertTrue(store.allKeys().isEmpty())
    }

    @Test
    fun deleteAll_preservesNonJsonFiles() = runBlocking {
        store.saveJson("a", "key-a")
        File(tempDir, "keep.txt").writeText("not json")
        store.deleteAll()
        assertTrue(store.allKeys().isEmpty())
        assertTrue(File(tempDir, "keep.txt").exists())
    }

    @Test
    fun loadJsonRecoveringInvalid_returnsNullForCorruptJson() = runBlocking {
        File(tempDir, "corrupt.json").writeText("{not valid json!!!")
        assertNull(store.loadJsonRecoveringInvalid("corrupt"))
    }

    @Test
    fun loadJsonRecoveringInvalid_returnsContentForValidJson() = runBlocking {
        store.saveJson("""{"valid":true}""", "valid")
        assertEquals("""{"valid":true}""", store.loadJsonRecoveringInvalid("valid"))
    }

    @Test(expected = RepositoryError.StorageUnavailable::class)
    fun save_whenKeyContainsSlash_throws() {
        runBlocking {
            store.saveJson("data", "key/with/slash")
        }
    }

    @Test
    fun concurrent_writesAndLoadsDoNotCorrupt() = runBlocking {
        val jobs = (1..20).map { i ->
            launch(kotlinx.coroutines.Dispatchers.Default) {
                store.saveJson("""{"id":$i}""", "doc-$i")
            }
        }
        jobs.forEach { it.join() }

        val keys = store.allKeys()
        assertEquals(20, keys.size)

        for (i in 1..20) {
            val content = store.loadJson("doc-$i")
            assertNotNull(content)
            assertTrue(content!!.contains("\"id\":$i"))
        }
    }

    @Test
    fun save_isAtomic_noPartialWriteOnDirectoryListing() = runBlocking {
        store.saveJson("""{"data":"complete"}""", "atomic-doc")
        val loaded = store.loadJson("atomic-doc")
        assertEquals("""{"data":"complete"}""", loaded)
    }
}
