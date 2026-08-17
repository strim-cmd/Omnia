package com.omnia.application

import com.omnia.domain.ConfigurationKey
import com.omnia.domain.ConfigurationLevel
import com.omnia.domain.ConfigurationRepository
import com.omnia.domain.ConfigurationResolutionPolicy

class ConfigurationService(
    private val repository: ConfigurationRepository,
    private val resolutionPolicy: ConfigurationResolutionPolicy = ConfigurationResolutionPolicy(),
) {
    suspend fun <T : Any> store(value: T, key: ConfigurationKey<T>, level: ConfigurationLevel) {
        require(key.name.isNotEmpty()) { "Configuration key name must not be empty" }
        repository.store(value, key, level)
    }

    suspend fun <T : Any> value(key: ConfigurationKey<T>, level: ConfigurationLevel): T? {
        require(key.name.isNotEmpty()) { "Configuration key name must not be empty" }
        return repository.value(key, level)
    }

    suspend fun <T : Any> resolved(key: ConfigurationKey<T>): T? {
        require(key.name.isNotEmpty()) { "Configuration key name must not be empty" }
        val values = mutableMapOf<ConfigurationLevel, MutableMap<ConfigurationKey<T>, T>>()
        for (level in ConfigurationResolutionPolicy.resolutionOrder) {
            val v = repository.value(key, level)
            if (v != null) {
                values.getOrPut(level) { mutableMapOf() }[key] = v
            }
        }
        return resolutionPolicy.resolve(key, values)
    }

    suspend fun <T : Any> remove(key: ConfigurationKey<T>, level: ConfigurationLevel) {
        require(key.name.isNotEmpty()) { "Configuration key name must not be empty" }
        repository.remove(key, level)
    }
}
