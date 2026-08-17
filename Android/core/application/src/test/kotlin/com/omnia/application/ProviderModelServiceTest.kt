package com.omnia.application

import com.omnia.domain.Capability
import com.omnia.domain.ConfigurationKey
import com.omnia.domain.ConfigurationLevel
import com.omnia.domain.ConfigurationRepository
import com.omnia.domain.ModelCapabilityProfile
import com.omnia.domain.ModelCapabilitySupport
import com.omnia.domain.ModelCatalogError
import com.omnia.domain.ModelReference
import com.omnia.domain.ProviderCapabilities
import com.omnia.domain.ProviderIdentity
import com.omnia.domain.ProviderLifecycleService
import com.omnia.domain.ProviderModelSelection
import com.omnia.domain.ProviderState
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ProviderModelServiceTest {

    private lateinit var configRepo: FakeConfigRepo
    private lateinit var configService: ConfigurationService
    private lateinit var lifecycle: ProviderLifecycleService
    private lateinit var service: ProviderModelService

    private val provider = ProviderIdentity("p1")

    @Before
    fun setup() {
        configRepo = FakeConfigRepo()
        configService = ConfigurationService(configRepo)
        lifecycle = ProviderLifecycleService()
        service = ProviderModelService(
            configurationService = configService,
            lifecycleService = lifecycle,
        )
    }

    @Test
    fun cachedCatalog_emptyWhenNothingCached() = runBlocking {
        val catalog = service.cachedCatalog(provider)
        assertEquals(ProviderModelCatalogStatus.empty, catalog.status)
        assertTrue(catalog.models.isEmpty())
    }

    @Test
    fun refreshCatalog_discoversAndCachesModels() = runBlocking {
        val svc = ProviderModelService(
            configurationService = configService,
            lifecycleService = lifecycle,
            discoverModels = { listOf(ModelReference("gpt-4"), ModelReference("gpt-3.5-turbo")) },
        )
        val catalog = svc.refreshCatalog(provider)
        assertEquals(ProviderModelCatalogStatus.loaded, catalog.status)
        assertEquals(2, catalog.models.size)
    }

    @Test
    fun refreshCatalog_failureReturnsStale() = runBlocking {
        // Use same instance — cache is in-memory within one ProviderModelService
        val svc = ProviderModelService(
            configurationService = configService,
            lifecycleService = lifecycle,
            discoverModels = { listOf(ModelReference("gpt-4")) },
        )
        svc.refreshCatalog(provider)

        // Replace discoverModels to fail — but we can't, so create a new one with same configService
        // The cache lives in the instance, so we need to use recordValidatedModels instead
        val failSvc = ProviderModelService(
            configurationService = configService,
            lifecycleService = lifecycle,
            discoverModels = { throw ModelCatalogException(ModelCatalogError.unreachable) },
        )
        // Manually seed the in-memory cache to simulate a previously cached state
        failSvc.recordValidatedModels(listOf(ModelReference("gpt-4")), provider)

        val catalog = failSvc.refreshCatalog(provider)
        assertTrue(catalog.status is ProviderModelCatalogStatus.stale)
    }

    @Test
    fun refreshCatalog_failureWithNoCacheReturnsFailed() = runBlocking {
        val failSvc = ProviderModelService(
            configurationService = configService,
            lifecycleService = lifecycle,
            discoverModels = { throw ModelCatalogException(ModelCatalogError.unreachable) },
        )
        val catalog = failSvc.refreshCatalog(provider)
        assertTrue(catalog.status is ProviderModelCatalogStatus.failed)
    }

    @Test
    fun refreshCatalog_fallbackModelIncluded() = runBlocking {
        val svc = ProviderModelService(
            configurationService = configService,
            lifecycleService = lifecycle,
            configuredModel = { ModelReference("fallback-model") },
            discoverModels = { emptyList() },
        )
        val catalog = svc.refreshCatalog(provider)
        assertEquals(1, catalog.models.size)
        assertEquals("fallback-model", catalog.models[0].name)
    }

    @Test
    fun refreshCatalog_deduplicatesFallback() = runBlocking {
        val svc = ProviderModelService(
            configurationService = configService,
            lifecycleService = lifecycle,
            configuredModel = { ModelReference("gpt-4") },
            discoverModels = { listOf(ModelReference("gpt-4")) },
        )
        val catalog = svc.refreshCatalog(provider)
        assertEquals(1, catalog.models.size)
    }

    @Test
    fun offeredModels_returnsCached() = runBlocking {
        val svc = ProviderModelService(
            configurationService = configService,
            lifecycleService = lifecycle,
            discoverModels = { listOf(ModelReference("m1"), ModelReference("m2")) },
        )
        svc.refreshCatalog(provider)
        val models = svc.offeredModels(provider)
        assertEquals(2, models.size)
    }

    @Test
    fun recordValidatedModels_storesNormalized() = runBlocking {
        service.recordValidatedModels(
            listOf(ModelReference("  gpt-4  "), ModelReference("gpt-3.5-turbo")),
            provider,
        )
        val models = service.offeredModels(provider)
        assertEquals(2, models.size)
        assertEquals("gpt-3.5-turbo", models[0].name)
        assertEquals("gpt-4", models[1].name)
    }

    @Test
    fun defaultSelection_storesAndRetrieves() = runBlocking {
        val sel = ProviderModelSelection(provider, ModelReference("gpt-4"))
        service.setDefaultSelection(sel)
        assertEquals(sel, service.defaultSelection())
    }

    @Test
    fun defaultSelection_nullClears() = runBlocking {
        val sel = ProviderModelSelection(provider, ModelReference("gpt-4"))
        service.setDefaultSelection(sel)
        service.setDefaultSelection(null)
        assertNull(service.defaultSelection())
    }

    @Test
    fun isAvailable_falseWhenProviderNotReady() = runBlocking {
        val sel = ProviderModelSelection(provider, ModelReference("gpt-4"))
        assertFalse(service.isAvailable(sel))
    }

    @Test
    fun isAvailable_falseWhenModelNotInCatalog() = runBlocking {
        lifecycle.register(
            com.omnia.domain.ProviderConnection(
                identity = provider,
                capabilities = ProviderCapabilities(setOf(Capability.streaming)),
                metadata = com.omnia.domain.ProviderMetadata("Test"),
                limits = com.omnia.domain.ProviderLimits(),
                version = com.omnia.common.SemanticVersion(1, 0, 0),
            )
        )
        lifecycle.transition(provider, ProviderState.validated)
        lifecycle.transition(provider, ProviderState.initializing)
        lifecycle.transition(provider, ProviderState.ready)

        val sel = ProviderModelSelection(provider, ModelReference("gpt-4"))
        assertFalse(service.isAvailable(sel))
    }

    @Test
    fun isAvailable_trueWhenReadyAndModelInCatalog() = runBlocking {
        val svc = ProviderModelService(
            configurationService = configService,
            lifecycleService = lifecycle,
            discoverModels = { listOf(ModelReference("gpt-4")) },
        )
        svc.refreshCatalog(provider)

        lifecycle.register(
            com.omnia.domain.ProviderConnection(
                identity = provider,
                capabilities = ProviderCapabilities(setOf(Capability.streaming)),
                metadata = com.omnia.domain.ProviderMetadata("Test"),
                limits = com.omnia.domain.ProviderLimits(),
                version = com.omnia.common.SemanticVersion(1, 0, 0),
            )
        )
        lifecycle.transition(provider, ProviderState.validated)
        lifecycle.transition(provider, ProviderState.initializing)
        lifecycle.transition(provider, ProviderState.ready)

        val sel = ProviderModelSelection(provider, ModelReference("gpt-4"))
        assertTrue(svc.isAvailable(sel))
    }

    @Test
    fun setCapabilityOverride_storesAndRetrieves() = runBlocking {
        val sel = ProviderModelSelection(provider, ModelReference("gpt-4"))
        val profile = ModelCapabilityProfile(supported = setOf(Capability.vision))
        service.setCapabilityOverride(profile, sel)
        val support = service.effectiveSupport(Capability.vision, sel, ProviderCapabilities(emptySet()))
        assertEquals(ModelCapabilitySupport.supported, support)
    }

    @Test
    fun effectiveSupport_visionDefaultsToUnknown() = runBlocking {
        val sel = ProviderModelSelection(provider, ModelReference("gpt-4"))
        val support = service.effectiveSupport(Capability.vision, sel, ProviderCapabilities(emptySet()))
        assertEquals(ModelCapabilitySupport.unknown, support)
    }

    @Test
    fun effectiveSupport_documentInputDefaultsToUnknown() = runBlocking {
        val sel = ProviderModelSelection(provider, ModelReference("gpt-4"))
        val support = service.effectiveSupport(Capability.documentInput, sel, ProviderCapabilities(emptySet()))
        assertEquals(ModelCapabilitySupport.unknown, support)
    }

    @Test
    fun effectiveSupport_textGenerationFallsThroughToProvider() = runBlocking {
        val sel = ProviderModelSelection(provider, ModelReference("gpt-4"))
        val support = service.effectiveSupport(
            Capability.textGeneration,
            sel,
            ProviderCapabilities(setOf(Capability.textGeneration)),
        )
        assertEquals(ModelCapabilitySupport.supported, support)
    }

    @Test
    fun effectiveSupport_overrideOverridesProvider() = runBlocking {
        val sel = ProviderModelSelection(provider, ModelReference("gpt-4"))
        val profile = ModelCapabilityProfile(unsupported = setOf(Capability.textGeneration))
        service.setCapabilityOverride(profile, sel)
        val support = service.effectiveSupport(
            Capability.textGeneration,
            sel,
            ProviderCapabilities(setOf(Capability.textGeneration)),
        )
        assertEquals(ModelCapabilitySupport.unsupported, support)
    }

    @Test
    fun effectiveSupport_unknownOverrideFallsThrough() = runBlocking {
        val sel = ProviderModelSelection(provider, ModelReference("gpt-4"))
        val profile = ModelCapabilityProfile()
        service.setCapabilityOverride(profile, sel)
        val support = service.effectiveSupport(
            Capability.textGeneration,
            sel,
            ProviderCapabilities(setOf(Capability.textGeneration)),
        )
        assertEquals(ModelCapabilitySupport.supported, support)
    }

    @Test
    fun effectiveSupport_providerLackingCapabilityReturnsUnsupported() = runBlocking {
        val sel = ProviderModelSelection(provider, ModelReference("gpt-4"))
        val support = service.effectiveSupport(
            Capability.textGeneration,
            sel,
            ProviderCapabilities(emptySet()),
        )
        assertEquals(ModelCapabilitySupport.unsupported, support)
    }

    // --- helpers ---

    private class FakeConfigRepo : ConfigurationRepository {
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
    }
}
