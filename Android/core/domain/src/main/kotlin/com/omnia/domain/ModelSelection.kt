package com.omnia.domain

/**
 * Selection vocabulary — the G-01 runtime truth. A message is sent with a
 * (provider, model) pair, never the stale userSelection/workspacePreference/
 * capabilityPreference vocabulary.
 *
 * This type is persisted per-conversation and carried through the generation
 * pipeline.
 */
data class ProviderModelSelection(
    val provider: ProviderIdentity,
    val model: ModelReference,
) {
    init {
        require(provider.id.isNotBlank()) { "provider id must not be blank" }
        require(model.name.isNotBlank()) { "model name must not be blank" }
    }
}

/**
 * Source descriptor for how a model entry was obtained.
 */
enum class ModelDescriptorSource {
    discovered,
    configuredFallback,
    userDeclared,
}

/**
 * Capability support assessment for a single capability within a model.
 */
enum class ModelCapabilitySupport {
    supported,
    unsupported,
    unknown,
}

/**
 * Per-model capability profile. The domain resolves capability support as:
 * model override first, then vision/documentInput remain unknown unless
 * explicitly declared, then fall through to provider capabilities.
 *
 * Invariant: supported set never overlaps with unsupported set.
 */
data class ModelCapabilityProfile(
    val supported: Set<Capability> = emptySet(),
    val unsupported: Set<Capability> = emptySet(),
) {
    init {
        require(supported.intersect(unsupported).isEmpty()) {
            "supported and unsupported sets must not overlap"
        }
    }

    fun supportFor(capability: Capability): ModelCapabilitySupport = when (capability) {
        in supported -> ModelCapabilitySupport.supported
        in unsupported -> ModelCapabilitySupport.unsupported
        else -> ModelCapabilitySupport.unknown
    }

    fun replacing(support: ModelCapabilitySupport, capability: Capability): ModelCapabilityProfile {
        val newSupported = supported.toMutableSet()
        val newUnsupported = unsupported.toMutableSet()
        when (support) {
            ModelCapabilitySupport.supported -> {
                newSupported.add(capability)
                newUnsupported.remove(capability)
            }
            ModelCapabilitySupport.unsupported -> {
                newUnsupported.add(capability)
                newSupported.remove(capability)
            }
            ModelCapabilitySupport.unknown -> {
                newSupported.remove(capability)
                newUnsupported.remove(capability)
            }
        }
        return ModelCapabilityProfile(supported = newSupported.toSet(), unsupported = newUnsupported.toSet())
    }
}

/**
 * Complete descriptor for a discovered or configured model.
 */
data class ModelDescriptor(
    val selection: ProviderModelSelection,
    val capabilities: ModelCapabilityProfile = ModelCapabilityProfile(),
    val source: ModelDescriptorSource,
)
