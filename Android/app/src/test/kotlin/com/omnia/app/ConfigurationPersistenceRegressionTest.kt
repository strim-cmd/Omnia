package com.omnia.app

import com.omnia.application.ConfigureProviderRequest
import com.omnia.application.ProviderConnectionService
import com.omnia.common.SemanticVersion
import com.omnia.data.configuration.ConfigurationBootstrap
import com.omnia.data.configuration.FileConfigurationRepository
import com.omnia.data.provider.FileProviderRepository
import com.omnia.domain.Capability
import com.omnia.domain.ConfigurationLevel
import com.omnia.domain.Credential
import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageProtocol
import com.omnia.domain.ProviderAPIKind
import com.omnia.domain.ProviderCapabilities
import com.omnia.domain.ProviderLimits
import com.omnia.domain.ProviderLifecycleService
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

class ConfigurationPersistenceRegressionTest {

    private lateinit var tempDir: File
    private lateinit var configRepo: FileConfigurationRepository
    private lateinit var providerRepo: FileProviderRepository
    private lateinit var credentialStorage: FakeCredentialStorage
    private lateinit var lifecycleService: ProviderLifecycleService
    private lateinit var service: ProviderConnectionService

    @Before
    fun setup() {
        ConfigurationBootstrap.resetForTesting()
        ConfigurationBootstrap.ensureRegistered()
        tempDir = Files.createTempDirectory("PersistenceRegression").toFile()
        configRepo = FileConfigurationRepository(File(tempDir, "config"))
        providerRepo = FileProviderRepository(File(tempDir, "providers"))
        credentialStorage = FakeCredentialStorage()
        lifecycleService = ProviderLifecycleService()
        service = ProviderConnectionService(
            providerRepository = providerRepo,
            credentialStorage = credentialStorage,
            configurationRepository = configRepo,
            lifecycleService = lifecycleService,
        )
    }

    @After
    fun teardown() {
        tempDir.deleteRecursively()
    }

    @Test
    fun configure_then_apiKind_resolves() = runBlocking {
        val request = ConfigureProviderRequest(
            displayName = "Test Provider",
            capabilities = ProviderCapabilities(setOf(Capability.textGeneration)),
            limits = ProviderLimits(),
            version = SemanticVersion(1, 0, 0),
            credential = Credential.of("test-key-123"),
        )
        val provider = service.configure(
            request,
            endpoint = "https://api.example.com/v1",
            model = "gpt-4",
            apiKind = ProviderAPIKind.openAICompatible,
        )

        val resolved = service.apiKind(provider.identity)
        assertEquals(ProviderAPIKind.openAICompatible, resolved)
    }

    @Test
    fun configure_then_recreateGraph_apiKindStillResolves() = runBlocking {
        val request = ConfigureProviderRequest(
            displayName = "Test Provider",
            capabilities = ProviderCapabilities(setOf(Capability.textGeneration)),
            limits = ProviderLimits(),
            version = SemanticVersion(1, 0, 0),
            credential = Credential.of("test-key-456"),
        )
        val provider = service.configure(
            request,
            endpoint = "https://api.example.com/v1",
            model = "gemini-pro",
            apiKind = ProviderAPIKind.gemini,
        )

        val newConfigRepo = FileConfigurationRepository(File(tempDir, "config"))
        val newProviderRepo = FileProviderRepository(File(tempDir, "providers"))
        val newService = ProviderConnectionService(
            providerRepository = newProviderRepo,
            credentialStorage = credentialStorage,
            configurationRepository = newConfigRepo,
            lifecycleService = ProviderLifecycleService(),
        )

        val resolved = newService.apiKind(provider.identity)
        assertEquals(ProviderAPIKind.gemini, resolved)
    }

    @Test
    fun configure_then_recreateGraph_credentialReferenceResolves() = runBlocking {
        val request = ConfigureProviderRequest(
            displayName = "Test Provider",
            capabilities = ProviderCapabilities(setOf(Capability.textGeneration)),
            limits = ProviderLimits(),
            version = SemanticVersion(1, 0, 0),
            credential = Credential.of("secret-api-key-789"),
        )
        val provider = service.configure(
            request,
            endpoint = "https://api.example.com/v1",
            model = "gpt-4",
            apiKind = ProviderAPIKind.openAICompatible,
        )

        val newConfigRepo = FileConfigurationRepository(File(tempDir, "config"))
        val newProviderRepo = FileProviderRepository(File(tempDir, "providers"))
        val newService = ProviderConnectionService(
            providerRepository = newProviderRepo,
            credentialStorage = credentialStorage,
            configurationRepository = newConfigRepo,
            lifecycleService = ProviderLifecycleService(),
        )

        val credRef = newConfigRepo.value(
            ProviderConnectionService.credentialReferenceKey(provider.identity),
            ConfigurationLevel.providerSettings,
        )
        assertNotNull(credRef)
        val resolved = credentialStorage.credential(credRef!!)
        assertEquals("secret-api-key-789", resolved.withValue { it })
    }

    @Test
    fun providerSaveLoad_doesNotThrowClassCastException() = runBlocking {
        val request = ConfigureProviderRequest(
            displayName = "No Crash Provider",
            capabilities = ProviderCapabilities(setOf(Capability.textGeneration)),
            limits = ProviderLimits(),
            version = SemanticVersion(1, 0, 0),
            credential = Credential.of("crash-test-key"),
        )
        val provider = service.configure(
            request,
            endpoint = "https://api.test.com/v1",
            model = "test-model",
            apiKind = ProviderAPIKind.openAICompatible,
        )

        val loaded = service.allProviders()
        assertEquals(1, loaded.size)

        val resolvedKind = service.apiKind(provider.identity)
        assertEquals(ProviderAPIKind.openAICompatible, resolvedKind)

        val resolvedEndpoint = service.endpoint(provider.identity)
        assertEquals("https://api.test.com/v1", resolvedEndpoint)

        val resolvedModel = service.model(provider.identity)
        assertEquals("test-model", resolvedModel)
    }

    private class FakeCredentialStorage : CredentialStorageProtocol {
        val stores = mutableMapOf<String, Credential>()
        override suspend fun store(credential: Credential, reference: CredentialReference) {
            stores[reference.id] = credential
        }
        override suspend fun credential(reference: CredentialReference): Credential =
            stores[reference.id] ?: throw com.omnia.domain.CredentialStorageError.CredentialNotFound
        override suspend fun removeCredential(reference: CredentialReference) {
            stores.remove(reference.id)
        }
    }
}
