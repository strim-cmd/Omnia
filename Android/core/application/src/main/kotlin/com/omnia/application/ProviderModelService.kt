package com.omnia.application

import com.omnia.domain.ConfigurationKey
import com.omnia.domain.ConfigurationLevel
import com.omnia.domain.ModelCapabilityProfile
import com.omnia.domain.ModelCapabilitySupport
import com.omnia.domain.ModelCatalogError
import com.omnia.domain.ModelReference
import com.omnia.domain.ProviderCapabilities
import com.omnia.domain.ProviderIdentity
import com.omnia.domain.ProviderLifecycleService
import com.omnia.domain.ProviderModelSelection
import com.omnia.domain.ProviderState
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class ProviderModelService(
    private val configurationService: ConfigurationService,
    private val lifecycleService: ProviderLifecycleService,
    private val configuredModel: suspend (ProviderIdentity) -> ModelReference? = { null },
    private val discoverModels: suspend (ProviderIdentity) -> List<ModelReference> = { emptyList() },
) {
    private val lock = Mutex()
    private val cachedCatalogs = mutableMapOf<ProviderIdentity, List<ModelReference>>()

    suspend fun cachedCatalog(identity: ProviderIdentity): ProviderModelCatalog {
        val cached = cachedCatalogs[identity] ?: emptyList()
        val fallback = try { configuredModel(identity) } catch (_: Exception) { null }
        val merged = merge(cached, fallback)
        val status = when {
            merged.isNotEmpty() -> ProviderModelCatalogStatus.loaded
            else -> ProviderModelCatalogStatus.empty
        }
        return ProviderModelCatalog(provider = identity, models = merged, status = status)
    }

    suspend fun refreshCatalog(identity: ProviderIdentity): ProviderModelCatalog {
        return try {
            val discovered = discoverModels(identity)
            val fallback = try { configuredModel(identity) } catch (_: Exception) { null }
            val merged = merge(discovered, fallback)
            lock.withLock { cachedCatalogs[identity] = merged }
            ProviderModelCatalog(
                provider = identity,
                models = merged,
                status = ProviderModelCatalogStatus.loaded,
            )
        } catch (e: ModelCatalogException) {
            val cached = lock.withLock { cachedCatalogs[identity] ?: emptyList() }
            val fallback = try { configuredModel(identity) } catch (_: Exception) { null }
            val merged = merge(cached, fallback)
            ProviderModelCatalog(
                provider = identity,
                models = merged,
                status = ProviderModelCatalogStatus.stale(e.error),
            )
        }
    }

    suspend fun offeredModels(identity: ProviderIdentity): List<ModelReference> {
        return lock.withLock { cachedCatalogs[identity] } ?: emptyList()
    }

    suspend fun recordValidatedModels(models: List<ModelReference>, identity: ProviderIdentity) {
        val normalized = normalized(models)
        lock.withLock { cachedCatalogs[identity] = normalized }
    }

    suspend fun defaultSelection(): ProviderModelSelection? =
        configurationService.resolved(DEFAULT_SELECTION_KEY)

    suspend fun setDefaultSelection(selection: ProviderModelSelection?) {
        if (selection != null) {
            configurationService.store(selection, DEFAULT_SELECTION_KEY, ConfigurationLevel.globalDefault)
        } else {
            configurationService.remove(DEFAULT_SELECTION_KEY, ConfigurationLevel.globalDefault)
        }
    }

    suspend fun isAvailable(selection: ProviderModelSelection): Boolean {
        val state = lifecycleService.state(selection.provider) ?: return false
        if (state != ProviderState.ready) return false
        val models = offeredModels(selection.provider)
        return models.any { it.name == selection.model.name }
    }

    suspend fun setCapabilityOverride(
        profile: ModelCapabilityProfile?,
        selection: ProviderModelSelection,
    ) {
        val key = capabilityOverrideKey(selection)
        if (profile != null) {
            configurationService.store(profile, key, ConfigurationLevel.providerSettings)
        } else {
            configurationService.remove(key, ConfigurationLevel.providerSettings)
        }
    }

    suspend fun effectiveSupport(
        capability: com.omnia.domain.Capability,
        selection: ProviderModelSelection,
        providerCapabilities: ProviderCapabilities,
    ): ModelCapabilitySupport {
        val override = configurationService.value(
            capabilityOverrideKey(selection),
            ConfigurationLevel.providerSettings,
        )
        if (override != null) {
            val support = override.supportFor(capability)
            if (support != ModelCapabilitySupport.unknown) return support
        }
        if (capability == com.omnia.domain.Capability.vision ||
            capability == com.omnia.domain.Capability.documentInput
        ) {
            return ModelCapabilitySupport.unknown
        }
        return if (providerCapabilities.contains(capability)) {
            ModelCapabilitySupport.supported
        } else {
            ModelCapabilitySupport.unsupported
        }
    }

    private fun merge(
        discovered: List<ModelReference>,
        fallback: ModelReference?,
    ): List<ModelReference> {
        val result = discovered.toMutableList()
        if (fallback != null && result.none { it.name == fallback.name }) {
            result.add(fallback)
        }
        return normalized(result)
    }

    private fun normalized(models: List<ModelReference>): List<ModelReference> =
        models.map { ModelReference(name = it.name.trim()) }
            .distinctBy { it.name }
            .sortedBy { it.name }

    private fun capabilityOverrideKey(selection: ProviderModelSelection): ConfigurationKey<ModelCapabilityProfile> =
        ConfigurationKey("models.capabilities.${selection.provider.id}.${selection.model.name}")

    companion object {
        private val DEFAULT_SELECTION_KEY = ConfigurationKey<ProviderModelSelection>("defaultModelSelection")
    }
}

data class ProviderModelCatalog(
    val provider: ProviderIdentity,
    val models: List<ModelReference>,
    val status: ProviderModelCatalogStatus,
)

sealed class ProviderModelCatalogStatus {
    data object loading : ProviderModelCatalogStatus()
    data object loaded : ProviderModelCatalogStatus()
    data object empty : ProviderModelCatalogStatus()
    data object configuredFallback : ProviderModelCatalogStatus()
    data object cached : ProviderModelCatalogStatus()
    data class unavailable(val error: ModelCatalogError) : ProviderModelCatalogStatus()
    data class stale(val error: ModelCatalogError) : ProviderModelCatalogStatus()
    data class failed(val error: ModelCatalogError) : ProviderModelCatalogStatus()
}

class ModelCatalogException(val error: ModelCatalogError) : Exception("Model catalog error: $error")
