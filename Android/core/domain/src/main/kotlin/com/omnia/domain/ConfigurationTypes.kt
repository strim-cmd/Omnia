package com.omnia.domain

/**
 * Typed, per-level key-value configuration. Resolution order:
 * providerSettings -> workspaceOverride -> globalDefault -> capabilityPreference.
 *
 * The service resolves by iterating the fixed order; the highest-priority
 * level that sets the key wins.
 */
data class ConfigurationKey<T>(val name: String) {
    init {
        require(name.isNotBlank()) { "ConfigurationKey name must not be blank" }
    }
}

enum class ConfigurationLevel {
    providerSettings,
    workspaceOverride,
    globalDefault,
    capabilityPreference,
}

data class ConfigurationValue<T>(
    val value: T,
    val level: ConfigurationLevel,
)

/**
 * Typed configuration repository. Implementations belong to Infrastructure.
 */
interface ConfigurationRepository {
    suspend fun <T : Any> store(value: T, key: ConfigurationKey<T>, level: ConfigurationLevel)
    suspend fun <T : Any> value(key: ConfigurationKey<T>, level: ConfigurationLevel): T?
    suspend fun <T : Any> remove(key: ConfigurationKey<T>, level: ConfigurationLevel)
}

/**
 * Pure deterministic resolution policy. Highest-priority level wins.
 */
class ConfigurationResolutionPolicy {
    companion object {
        val resolutionOrder: List<ConfigurationLevel> = listOf(
            ConfigurationLevel.providerSettings,
            ConfigurationLevel.workspaceOverride,
            ConfigurationLevel.globalDefault,
            ConfigurationLevel.capabilityPreference,
        )
    }

    /**
     * Resolves a key across all levels. Returns the value from the
     * highest-priority level that provides one, or null.
     */
    fun <T : Any> resolve(
        key: ConfigurationKey<T>,
        values: Map<ConfigurationLevel, Map<ConfigurationKey<T>, T>>,
    ): T? {
        for (level in resolutionOrder) {
            val levelValues = values[level] ?: continue
            val value = levelValues[key]
            if (value != null) return value
        }
        return null
    }
}
