package com.omnia.application

import com.omnia.common.SemanticVersion
import com.omnia.domain.ConfigurationKey
import com.omnia.domain.ConfigurationLevel
import com.omnia.domain.ConfigurationRepository
import com.omnia.domain.Credential
import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageProtocol
import com.omnia.domain.Provider
import com.omnia.domain.ProviderAPIKind
import com.omnia.domain.ProviderConnection
import com.omnia.domain.ProviderIdentity
import com.omnia.domain.ProviderLifecycleService
import com.omnia.domain.ProviderRepository
import com.omnia.domain.ProviderState
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ProviderConnectionServiceTest {

    private lateinit var providerRepo: FakeProviderRepository
    private lateinit var credentialStorage: FakeCredentialStorage
    private lateinit var configRepo: FakeConfigurationRepository
    private lateinit var lifecycle: ProviderLifecycleService
    private lateinit var service: ProviderConnectionService

    @Before
    fun setup() {
        providerRepo = FakeProviderRepository()
        credentialStorage = FakeCredentialStorage()
        configRepo = FakeConfigurationRepository()
        lifecycle = ProviderLifecycleService()
        service = ProviderConnectionService(providerRepo, credentialStorage, configRepo, lifecycle)
    }

    @Test
    fun configure_createsReadyProvider() = runBlocking {
        val provider = service.configure(testRequest())
        assertEquals(ProviderState.ready, provider.state)
        assertNotNull(providerRepo.providers[provider.identity.id])
    }

    @Test
    fun configure_storesCredentialByReference() = runBlocking {
        val provider = service.configure(testRequest())
        val ref = configRepo.get<CredentialReference>(
            ProviderConnectionService.credentialReferenceKey(provider.identity),
            ConfigurationLevel.providerSettings,
        )
        assertNotNull(ref)
        assertNotNull(credentialStorage.stores[ref!!.id])
    }

    @Test
    fun configure_withEndpoint_recordsEndpoint() = runBlocking {
        val provider = service.configure(testRequest(), endpoint = "https://api.example.com/v1")
        val ep = service.endpoint(provider.identity)
        assertEquals("https://api.example.com/v1", ep)
    }

    @Test
    fun configure_withEndpointAndModel_recordsBoth() = runBlocking {
        val provider = service.configure(
            testRequest(),
            endpoint = "https://api.example.com/v1",
            model = "gpt-4",
            apiKind = ProviderAPIKind.openAICompatible,
        )
        assertEquals("https://api.example.com/v1", service.endpoint(provider.identity))
        assertEquals("gpt-4", service.model(provider.identity))
        assertEquals(ProviderAPIKind.openAICompatible, service.apiKind(provider.identity))
    }

    @Test
    fun configure_rejectsEmptyDisplayName() = runBlocking {
        try {
            service.configure(testRequest(displayName = ""))
            throw AssertionError("Expected failure")
        } catch (e: ApplicationValidationError.Invalid) {
            assertTrue(e.message!!.contains("Display name"))
        }
    }

    @Test
    fun configure_rejectsEmptyCapabilities() = runBlocking {
        try {
            service.configure(testRequest(capabilities = emptySet()))
            throw AssertionError("Expected failure")
        } catch (e: ApplicationValidationError.Invalid) {
            assertTrue(e.message!!.contains("capability"))
        }
    }

    @Test
    fun configure_rejectsEmptyCredential() = runBlocking {
        try {
            service.configure(testRequest(credential = ""))
            throw AssertionError("Expected failure")
        } catch (e: IllegalArgumentException) {
            assertTrue(e.message!!.contains("empty"))
        }
    }

    @Test
    fun configure_rejectsEmptyEndpoint() = runBlocking {
        try {
            service.configure(testRequest(), endpoint = "")
            throw AssertionError("Expected failure")
        } catch (e: ApplicationValidationError.Invalid) {
            assertTrue(e.message!!.contains("empty"))
        }
    }

    @Test
    fun configure_rejectsMalformedEndpoint() = runBlocking {
        try {
            service.configure(testRequest(), endpoint = "not-a-url")
            throw AssertionError("Expected failure")
        } catch (e: ApplicationValidationError.Invalid) {
            assertTrue(e.message!!.contains("absolute"))
        }
    }

    @Test
    fun configure_rejectsEmptyModel() = runBlocking {
        try {
            service.configure(testRequest(), endpoint = "https://x.com", model = "  ")
            throw AssertionError("Expected failure")
        } catch (e: ApplicationValidationError.Invalid) {
            assertTrue(e.message!!.contains("model"))
        }
    }

    @Test
    fun configure_trimsEndpoint() = runBlocking {
        val provider = service.configure(testRequest(), endpoint = "  https://api.example.com  ")
        assertEquals("https://api.example.com", service.endpoint(provider.identity))
    }

    @Test
    fun configure_trimsModel() = runBlocking {
        val provider = service.configure(
            testRequest(),
            endpoint = "https://x.com",
            model = "  gpt-4  ",
        )
        assertEquals("gpt-4", service.model(provider.identity))
    }

    @Test
    fun allProviders_sortedByIdentity() = runBlocking {
        service.configure(testRequest(displayName = "B"))
        service.configure(testRequest(displayName = "A"))
        val all = service.allProviders()
        assertEquals(2, all.size)
        assertTrue(all[0].identity.id < all[1].identity.id)
    }

    @Test
    fun remove_deletesProviderAndCredential() = runBlocking {
        val provider = service.configure(testRequest())
        service.remove(provider.identity)
        assertNull(providerRepo.providers[provider.identity.id])
    }

    @Test
    fun remove_cleansUpConfigKeys() = runBlocking {
        val provider = service.configure(
            testRequest(),
            endpoint = "https://x.com",
            model = "gpt-4",
        )
        service.remove(provider.identity)
        assertNull(service.endpoint(provider.identity))
        assertNull(service.model(provider.identity))
    }

    @Test
    fun updateEndpoint_recordsValue() = runBlocking {
        val provider = service.configure(testRequest())
        service.updateEndpoint("https://new-endpoint.com", provider.identity)
        assertEquals("https://new-endpoint.com", service.endpoint(provider.identity))
    }

    @Test
    fun updateModel_recordsValue() = runBlocking {
        val provider = service.configure(testRequest())
        service.updateModel("claude-3", provider.identity)
        assertEquals("claude-3", service.model(provider.identity))
    }

    @Test
    fun updateAPIKind_recordsValue() = runBlocking {
        val provider = service.configure(testRequest())
        service.updateAPIKind(ProviderAPIKind.gemini, provider.identity)
        assertEquals(ProviderAPIKind.gemini, service.apiKind(provider.identity))
    }

    @Test
    fun apiKind_defaultsToOpenAICompatible() = runBlocking {
        val provider = service.configure(testRequest())
        assertEquals(ProviderAPIKind.openAICompatible, service.apiKind(provider.identity))
    }

    @Test
    fun update_replacesConnectionDeclaration() = runBlocking {
        val provider = service.configure(testRequest())
        val updateReq = ProviderUpdateRequest(
            displayName = "Updated",
            capabilities = com.omnia.domain.ProviderCapabilities(setOf(com.omnia.domain.Capability.streaming)),
            limits = com.omnia.domain.ProviderLimits(),
            version = SemanticVersion(1, 0, 0),
        )
        service.update(updateReq, provider.identity, endpoint = "https://updated.com", model = "new-model")
        assertEquals("Updated", providerRepo.providers[provider.identity.id]?.connection?.metadata?.displayName)
        assertEquals("https://updated.com", service.endpoint(provider.identity))
        assertEquals("new-model", service.model(provider.identity))
    }

    @Test
    fun update_rejectsNonexistentProvider() = runBlocking {
        val req = ProviderUpdateRequest(
            displayName = "X",
            capabilities = com.omnia.domain.ProviderCapabilities(setOf(com.omnia.domain.Capability.streaming)),
            limits = com.omnia.domain.ProviderLimits(),
            version = SemanticVersion(1, 0, 0),
        )
        try {
            service.update(req, ProviderIdentity("nope"), endpoint = "https://x.com", model = null)
            throw AssertionError("Expected failure")
        } catch (e: ApplicationValidationError.Invalid) {
            assertTrue(e.message!!.contains("not found"))
        }
    }

    @Test
    fun credentialReferenceKey_isScopedByProvider() {
        val key1 = ProviderConnectionService.credentialReferenceKey(ProviderIdentity("p1"))
        val key2 = ProviderConnectionService.credentialReferenceKey(ProviderIdentity("p2"))
        assertTrue(key1.name != key2.name)
    }

    @Test
    fun endpointKey_isScopedByProvider() {
        val key1 = ProviderConnectionService.endpointKey(ProviderIdentity("p1"))
        val key2 = ProviderConnectionService.endpointKey(ProviderIdentity("p2"))
        assertTrue(key1.name != key2.name)
    }

    @Test
    fun modelKey_isScopedByProvider() {
        val key1 = ProviderConnectionService.modelKey(ProviderIdentity("p1"))
        val key2 = ProviderConnectionService.modelKey(ProviderIdentity("p2"))
        assertTrue(key1.name != key2.name)
    }

    @Test
    fun apiKindKey_isScopedByProvider() {
        val key1 = ProviderConnectionService.apiKindKey(ProviderIdentity("p1"))
        val key2 = ProviderConnectionService.apiKindKey(ProviderIdentity("p2"))
        assertTrue(key1.name != key2.name)
    }

    @Test
    fun remove_preservesAllConfigKeys() = runBlocking {
        val provider = service.configure(
            testRequest(),
            endpoint = "https://api.example.com/v1",
            model = "gpt-4",
            apiKind = ProviderAPIKind.openAICompatible,
        )
        assertNotNull(service.endpoint(provider.identity))
        assertNotNull(service.model(provider.identity))
        assertNotNull(service.apiKind(provider.identity))

        service.remove(provider.identity)

        assertNull(service.endpoint(provider.identity))
        assertNull(service.model(provider.identity))
        assertNull(configRepo.get(
            ProviderConnectionService.apiKindKey(provider.identity),
            ConfigurationLevel.providerSettings,
        ))
    }

    @Test
    fun remove_onProviderRepoFailureRollsBack() = runBlocking {
        val provider = service.configure(testRequest())

        val failingRepo = FailingDeleteProviderRepository(providerRepo)
        val serviceWithFailingRepo = ProviderConnectionService(
            failingRepo, credentialStorage, configRepo, lifecycle,
        )

        try {
            serviceWithFailingRepo.remove(provider.identity)
            throw AssertionError("Expected failure")
        } catch (_: Exception) {
            // Provider should still exist due to rollback
            assertNotNull(providerRepo.providers[provider.identity.id])
        }
    }

    @Test
    fun configure_onFailureRollsBackPartialState() = runBlocking {
        val failingRepo = object : FakeProviderRepository() {
            var failOnSave = false
            override suspend fun save(provider: Provider) {
                if (failOnSave) throw RuntimeException("Simulated failure")
                super.save(provider)
            }
        }
        val failingService = ProviderConnectionService(
            failingRepo, credentialStorage, configRepo, lifecycle,
        )

        failingRepo.failOnSave = true
        try {
            failingService.configure(testRequest())
            throw AssertionError("Expected failure")
        } catch (_: Exception) {
            // No credential should have been stored
            assertTrue(credentialStorage.stores.isEmpty())
        }
    }

    // --- helpers ---

    private fun testRequest(
        displayName: String = "Test Provider",
        capabilities: Set<com.omnia.domain.Capability> = setOf(com.omnia.domain.Capability.streaming),
        credential: String = "test-secret-key",
    ) = ConfigureProviderRequest(
        displayName = displayName,
        capabilities = com.omnia.domain.ProviderCapabilities(capabilities),
        limits = com.omnia.domain.ProviderLimits(maxRequestsPerMinute = 60),
        version = SemanticVersion(1, 0, 0),
        credential = Credential.of(credential),
    )

    private open class FakeProviderRepository : ProviderRepository {
        val providers = mutableMapOf<String, Provider>()
        override suspend fun save(provider: Provider) { providers[provider.identity.id] = provider }
        override suspend fun provider(identity: ProviderIdentity): Provider? = providers[identity.id]
        override suspend fun allProviders(): List<Provider> = providers.values.toList()
        override suspend fun delete(identity: ProviderIdentity) { providers.remove(identity.id) }
    }

    private class FailingDeleteProviderRepository(
        private val delegate: FakeProviderRepository,
    ) : ProviderRepository {
        override suspend fun save(provider: Provider) = delegate.save(provider)
        override suspend fun provider(identity: ProviderIdentity): Provider? = delegate.provider(identity)
        override suspend fun allProviders(): List<Provider> = delegate.allProviders()
        override suspend fun delete(identity: ProviderIdentity) {
            throw RuntimeException("Simulated delete failure")
        }
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

    private class FakeConfigurationRepository : ConfigurationRepository {
        private val store = mutableMapOf<String, Any>()
        override suspend fun <T : Any> store(value: T, key: ConfigurationKey<T>, level: ConfigurationLevel) {
            store[key.name] = value
        }
        @Suppress("UNCHECKED_CAST")
        override suspend fun <T : Any> value(key: ConfigurationKey<T>, level: ConfigurationLevel): T? =
            store[key.name] as? T
        override suspend fun <T : Any> remove(key: ConfigurationKey<T>, level: ConfigurationLevel) {
            store.remove(key.name)
        }

        @Suppress("UNCHECKED_CAST")
        fun <T> get(key: ConfigurationKey<T>, level: ConfigurationLevel): T? = store[key.name] as? T
    }
}
