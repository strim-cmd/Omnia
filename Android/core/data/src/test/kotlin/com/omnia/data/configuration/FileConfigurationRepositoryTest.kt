package com.omnia.data.configuration

import com.omnia.domain.ConfigurationKey
import com.omnia.domain.ConfigurationLevel
import com.omnia.domain.CredentialReference
import com.omnia.domain.ProviderAPIKind
import com.omnia.domain.RepositoryError
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

class FileConfigurationRepositoryTest {

    private lateinit var tempDir: File
    private lateinit var repo: FileConfigurationRepository

    @Before
    fun setup() {
        ConfigurationBootstrap.resetForTesting()
        ConfigurationBootstrap.ensureRegistered()
        tempDir = Files.createTempDirectory("ConfigRepoTests").toFile()
        repo = FileConfigurationRepository(tempDir)
    }

    @After
    fun teardown() {
        tempDir.deleteRecursively()
    }

    @Test
    fun store_then_value_roundTripsAStringValue() = runBlocking {
        val key = ConfigurationKey<String>("testKey")
        repo.store("hello", key, ConfigurationLevel.globalDefault)
        val loaded = repo.value(key, ConfigurationLevel.globalDefault)
        assertEquals("hello", loaded)
    }

    @Test
    fun store_then_value_roundTripsAnIntValue() = runBlocking {
        val key = ConfigurationKey<Int>("count")
        repo.store(42, key, ConfigurationLevel.globalDefault)
        val loaded = repo.value(key, ConfigurationLevel.globalDefault)
        assertEquals(42, loaded)
    }

    @Test
    fun store_then_value_roundTripsABooleanValue() = runBlocking {
        val key = ConfigurationKey<Boolean>("flag")
        repo.store(true, key, ConfigurationLevel.globalDefault)
        val loaded = repo.value(key, ConfigurationLevel.globalDefault)
        assertEquals(true, loaded)
    }

    @Test
    fun store_then_value_roundTripsCredentialReference() = runBlocking {
        val key = ConfigurationKey<CredentialReference>("credRef")
        val ref = CredentialReference("cred-abc-123")
        repo.store(ref, key, ConfigurationLevel.providerSettings)
        val loaded = repo.value(key, ConfigurationLevel.providerSettings)
        assertNotNull(loaded)
        assertEquals("cred-abc-123", loaded!!.id)
    }

    @Test
    fun store_then_value_roundTripsProviderAPIKind() = runBlocking {
        val key = ConfigurationKey<ProviderAPIKind>("apiKind")
        repo.store(ProviderAPIKind.gemini, key, ConfigurationLevel.providerSettings)
        val loaded = repo.value(key, ConfigurationLevel.providerSettings)
        assertEquals(ProviderAPIKind.gemini, loaded)
    }

    @Test
    fun store_replacesValueForSameKeyAndLevel() = runBlocking {
        val key = ConfigurationKey<String>("testKey")
        repo.store("first", key, ConfigurationLevel.globalDefault)
        repo.store("second", key, ConfigurationLevel.globalDefault)
        assertEquals("second", repo.value(key, ConfigurationLevel.globalDefault))
    }

    @Test
    fun store_isolatesSameKeyAcrossLevels() = runBlocking {
        val key = ConfigurationKey<String>("testKey")
        repo.store("global", key, ConfigurationLevel.globalDefault)
        repo.store("workspace", key, ConfigurationLevel.workspaceOverride)
        assertEquals("global", repo.value(key, ConfigurationLevel.globalDefault))
        assertEquals("workspace", repo.value(key, ConfigurationLevel.workspaceOverride))
    }

    @Test
    fun store_isolatesDifferentKeysAtSameLevel() = runBlocking {
        val key1 = ConfigurationKey<String>("key1")
        val key2 = ConfigurationKey<String>("key2")
        repo.store("value1", key1, ConfigurationLevel.globalDefault)
        repo.store("value2", key2, ConfigurationLevel.globalDefault)
        assertEquals("value1", repo.value(key1, ConfigurationLevel.globalDefault))
        assertEquals("value2", repo.value(key2, ConfigurationLevel.globalDefault))
    }

    @Test
    fun value_absentKeyReturnsNull() = runBlocking {
        val key = ConfigurationKey<String>("nonexistent")
        assertNull(repo.value(key, ConfigurationLevel.globalDefault))
    }

    @Test
    fun remove_removesTheValue() = runBlocking {
        val key = ConfigurationKey<String>("testKey")
        repo.store("hello", key, ConfigurationLevel.globalDefault)
        repo.remove(key, ConfigurationLevel.globalDefault)
        assertNull(repo.value(key, ConfigurationLevel.globalDefault))
    }

    @Test
    fun remove_absentKeyIsNotAnError() = runBlocking {
        val key = ConfigurationKey<String>("nonexistent")
        repo.remove(key, ConfigurationLevel.globalDefault)
    }

    @Test
    fun remove_isIdempotent() = runBlocking {
        val key = ConfigurationKey<String>("testKey")
        repo.store("hello", key, ConfigurationLevel.globalDefault)
        repo.remove(key, ConfigurationLevel.globalDefault)
        repo.remove(key, ConfigurationLevel.globalDefault)
    }

    @Test
    fun removeAll_removesConfigurationDocumentsAndPreservesUnrelatedFiles() = runBlocking {
        val key = ConfigurationKey<String>("testKey")
        repo.store("hello", key, ConfigurationLevel.globalDefault)
        File(tempDir, "keep.txt").writeText("not json")
        repo.removeAll()
        assertNull(repo.value(key, ConfigurationLevel.globalDefault))
        assertTrue(File(tempDir, "keep.txt").exists())
    }

    @Test
    fun storedDocument_neverCarriesCredentialMaterial() = runBlocking {
        val key = ConfigurationKey<CredentialReference>("credRef")
        repo.store(CredentialReference("cred-ref-abc-123"), key, ConfigurationLevel.providerSettings)

        val files = tempDir.listFiles() ?: emptyArray()
        for (file in files) {
            if (file.extension == "json") {
                val content = file.readText()
                assertFalse("Credential material must not appear in stored documents",
                    content.lowercase().contains("secretkey") ||
                    content.lowercase().contains("apikey") ||
                    content.lowercase().contains("api_key"))
            }
        }
    }

    @Test
    fun storedDocument_neverContainsSupersensitivePlaintext() = runBlocking {
        val key = ConfigurationKey<CredentialReference>("credRef")
        repo.store(CredentialReference("cred-abc-123"), key, ConfigurationLevel.providerSettings)

        val secretApiKey = "sk-super-secret-api-key-value-never-in-config"
        val files = tempDir.listFiles() ?: emptyArray()
        for (file in files) {
            if (file.extension == "json") {
                val content = file.readText()
                assertFalse("Actual secret API key must never appear in configuration JSON",
                    content.contains(secretApiKey))
            }
        }
    }

    @Test
    fun freshInstance_loadsPreviouslyPersistedData() = runBlocking {
        repo.store("hello", ConfigurationKey<String>("key1"), ConfigurationLevel.globalDefault)
        repo.store(42, ConfigurationKey<Int>("key2"), ConfigurationLevel.workspaceOverride)
        repo.store(ProviderAPIKind.gemini, ConfigurationKey<ProviderAPIKind>("key3"), ConfigurationLevel.providerSettings)

        val freshRepo = FileConfigurationRepository(tempDir)
        ConfigurationBootstrap.ensureRegistered()

        assertEquals("hello", freshRepo.value(ConfigurationKey<String>("key1"), ConfigurationLevel.globalDefault))
        assertEquals(42, freshRepo.value(ConfigurationKey<Int>("key2"), ConfigurationLevel.workspaceOverride))
        assertEquals(ProviderAPIKind.gemini, freshRepo.value(ConfigurationKey<ProviderAPIKind>("key3"), ConfigurationLevel.providerSettings))
    }

    @Test
    fun persistedDocument_carriesExpectedEnvelope() = runBlocking {
        repo.store("value", ConfigurationKey<String>("testKey"), ConfigurationLevel.globalDefault)

        val files = tempDir.listFiles() ?: emptyArray()
        val jsonFile = files.first { it.extension == "json" }
        val content = jsonFile.readText()
        assertTrue("Persisted document must contain typeName field",
            content.contains("\"typeName\""))
        assertTrue("Persisted document must contain level field",
            content.contains("\"level\""))
        assertTrue("Persisted document must contain key field",
            content.contains("\"key\""))
    }
}
