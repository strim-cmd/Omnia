package com.omnia.data.configuration

import com.omnia.domain.ConfigurationKey
import com.omnia.domain.ConfigurationLevel
import com.omnia.domain.CredentialReference
import com.omnia.domain.ModelCapabilityProfile
import com.omnia.domain.ModelReference
import com.omnia.domain.ProviderAPIKind
import com.omnia.domain.ProviderIdentity
import com.omnia.domain.ProviderModelSelection
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.encodeToJsonElement
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

class ConfigurationBootstrapTest {

    private lateinit var tempDir: File
    private lateinit var repo: FileConfigurationRepository

    @Before
    fun setup() {
        ConfigurationBootstrap.resetForTesting()
        ConfigurationBootstrap.ensureRegistered()
        tempDir = Files.createTempDirectory("BootstrapTests").toFile()
        repo = FileConfigurationRepository(tempDir)
    }

    @After
    fun teardown() {
        tempDir.deleteRecursively()
    }

    @Test
    fun providerAPIKind_openAICompatible_roundTrips() = runBlocking {
        val key = ConfigurationKey<ProviderAPIKind>("apiKind")
        repo.store(ProviderAPIKind.openAICompatible, key, ConfigurationLevel.providerSettings)
        val loaded = repo.value(key, ConfigurationLevel.providerSettings)
        assertEquals(ProviderAPIKind.openAICompatible, loaded)
    }

    @Test
    fun providerAPIKind_gemini_roundTrips() = runBlocking {
        val key = ConfigurationKey<ProviderAPIKind>("apiKind")
        repo.store(ProviderAPIKind.gemini, key, ConfigurationLevel.providerSettings)
        val loaded = repo.value(key, ConfigurationLevel.providerSettings)
        assertEquals(ProviderAPIKind.gemini, loaded)
    }

    @Test
    fun credentialReference_roundTrips() = runBlocking {
        val key = ConfigurationKey<CredentialReference>("credRef")
        val ref = CredentialReference("test-cred-id-abc")
        repo.store(ref, key, ConfigurationLevel.providerSettings)
        val loaded = repo.value(key, ConfigurationLevel.providerSettings)
        assertNotNull(loaded)
        assertEquals("test-cred-id-abc", loaded!!.id)
    }

    @Test
    fun freshRepositoryInstance_loadsPersistedData() = runBlocking {
        val apiKindKey = ConfigurationKey<ProviderAPIKind>("apiKind")
        val credKey = ConfigurationKey<CredentialReference>("credRef")
        repo.store(ProviderAPIKind.gemini, apiKindKey, ConfigurationLevel.providerSettings)
        repo.store(CredentialReference("fresh-cred-id"), credKey, ConfigurationLevel.providerSettings)

        val freshRepo = FileConfigurationRepository(tempDir)

        assertEquals(
            ProviderAPIKind.gemini,
            freshRepo.value(apiKindKey, ConfigurationLevel.providerSettings),
        )
        assertEquals(
            "fresh-cred-id",
            freshRepo.value(credKey, ConfigurationLevel.providerSettings)!!.id,
        )
    }

    @Test
    fun providerModelSelection_roundTrips() = runBlocking {
        val key = ConfigurationKey<ProviderModelSelection>("selection")
        val selection = ProviderModelSelection(
            provider = ProviderIdentity("prov-1"),
            model = ModelReference("gpt-4"),
        )
        repo.store(selection, key, ConfigurationLevel.globalDefault)
        val loaded = repo.value(key, ConfigurationLevel.globalDefault)
        assertNotNull(loaded)
        assertEquals("prov-1", loaded!!.provider.id)
        assertEquals("gpt-4", loaded.model.name)
    }

    @Test
    fun modelCapabilityProfile_roundTrips() = runBlocking {
        val key = ConfigurationKey<ModelCapabilityProfile>("profile")
        val profile = ModelCapabilityProfile(
            supported = setOf(com.omnia.domain.Capability.vision),
            unsupported = setOf(com.omnia.domain.Capability.audio),
        )
        repo.store(profile, key, ConfigurationLevel.providerSettings)
        val loaded = repo.value(key, ConfigurationLevel.providerSettings)
        assertNotNull(loaded)
        assertEquals(setOf(com.omnia.domain.Capability.vision), loaded!!.supported)
        assertEquals(setOf(com.omnia.domain.Capability.audio), loaded.unsupported)
    }

    @Test
    fun unknownType_throwsControlledError() = runBlocking {
        val json = kotlinx.serialization.json.Json { encodeDefaults = true; prettyPrint = false }
        val doc = mapOf(
            "providerSettings-unknownType" to json.encodeToString(
                ConfigurationEntrySchema.serializer(),
                ConfigurationEntrySchema(
                    key = "unknownType",
                    level = "providerSettings",
                    payload = json.encodeToString(kotlinx.serialization.json.JsonPrimitive("someValue")),
                    typeName = "com.omnia.domain.NonExistentType",
                ),
            ),
        )
        for ((name, content) in doc) {
            File(tempDir, "$name.json").writeText(content)
        }

        val key = ConfigurationKey<String>("unknownType")
        try {
            repo.value(key, ConfigurationLevel.providerSettings)
            fail("Should throw for unregistered type")
        } catch (e: com.omnia.domain.RepositoryError.CorruptedRecord) {
            val causeMessage = e.cause?.message ?: ""
            assertTrue(
                "Expected 'not registered' in cause message, got: $causeMessage",
                causeMessage.contains("not registered")
            )
        }
    }

    @Test
    fun backwardCompat_credentialReference_toString_format_decodes() = runBlocking {
        val json = Json { encodeDefaults = true; prettyPrint = false }
        val toStringPayload = "CredentialReference(id=legacy-cred-123)"
        val doc = json.encodeToString(
            ConfigurationEntrySchema.serializer(),
            ConfigurationEntrySchema(
                key = "providerCredential.test",
                level = "providerSettings",
                payload = json.encodeToString(JsonPrimitive(toStringPayload)),
                typeName = "com.omnia.domain.CredentialReference",
            ),
        )
        File(tempDir, "providerSettings-providerCredential.test.json").writeText(doc)

        val key = ConfigurationKey<CredentialReference>("providerCredential.test")
        val loaded = repo.value(key, ConfigurationLevel.providerSettings)
        assertNotNull(loaded)
        assertEquals("legacy-cred-123", loaded!!.id)
    }

    @Test
    fun backwardCompat_providerAPIKind_enum_toString_decodes() = runBlocking {
        val json = Json { encodeDefaults = true; prettyPrint = false }
        val doc = json.encodeToString(
            ConfigurationEntrySchema.serializer(),
            ConfigurationEntrySchema(
                key = "providerAPIKind.test",
                level = "providerSettings",
                payload = json.encodeToString(JsonPrimitive("gemini")),
                typeName = "com.omnia.domain.ProviderAPIKind",
            ),
        )
        File(tempDir, "providerSettings-providerAPIKind.test.json").writeText(doc)

        val key = ConfigurationKey<ProviderAPIKind>("providerAPIKind.test")
        val loaded = repo.value(key, ConfigurationLevel.providerSettings)
        assertEquals(ProviderAPIKind.gemini, loaded)
    }

    @Test
    fun backwardCompat_providerModelSelection_toString_format_decodes() = runBlocking {
        val json = Json { encodeDefaults = true; prettyPrint = false }
        val toStringPayload = "ProviderModelSelection(provider=ProviderIdentity(id=prov-back), model=ModelReference(name=model-back))"
        val doc = json.encodeToString(
            ConfigurationEntrySchema.serializer(),
            ConfigurationEntrySchema(
                key = "defaultModelSelection",
                level = "globalDefault",
                payload = json.encodeToString(JsonPrimitive(toStringPayload)),
                typeName = "com.omnia.domain.ProviderModelSelection",
            ),
        )
        File(tempDir, "globalDefault-defaultModelSelection.json").writeText(doc)

        val key = ConfigurationKey<ProviderModelSelection>("defaultModelSelection")
        val loaded = repo.value(key, ConfigurationLevel.globalDefault)
        assertNotNull(loaded)
        assertEquals("prov-back", loaded!!.provider.id)
        assertEquals("model-back", loaded.model.name)
    }
}
