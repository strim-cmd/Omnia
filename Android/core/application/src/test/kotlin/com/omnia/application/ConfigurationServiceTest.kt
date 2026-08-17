package com.omnia.application

import com.omnia.domain.ConfigurationKey
import com.omnia.domain.ConfigurationLevel
import com.omnia.domain.ConfigurationRepository
import com.omnia.domain.ConfigurationResolutionPolicy
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

class ConfigurationServiceTest {

    private lateinit var repository: InMemoryConfigurationRepository
    private lateinit var service: ConfigurationService

    @Before
    fun setup() {
        repository = InMemoryConfigurationRepository()
        service = ConfigurationService(repository)
    }

    @Test
    fun store_andRetrieve() = runBlocking {
        val key = ConfigurationKey<String>("test.key")
        service.store("value", key, ConfigurationLevel.globalDefault)
        assertEquals("value", service.value(key, ConfigurationLevel.globalDefault))
    }

    @Test
    fun remove_removesValue() = runBlocking {
        val key = ConfigurationKey<String>("test.key")
        service.store("value", key, ConfigurationLevel.globalDefault)
        service.remove(key, ConfigurationLevel.globalDefault)
        assertNull(service.value(key, ConfigurationLevel.globalDefault))
    }

    @Test
    fun resolved_returnsHighestPriorityValue() = runBlocking {
        val key = ConfigurationKey<String>("test.key")
        service.store("global", key, ConfigurationLevel.globalDefault)
        service.store("workspace", key, ConfigurationLevel.workspaceOverride)
        assertEquals("workspace", service.resolved(key))
    }

    @Test
    fun resolved_returnsNullWhenEmpty() = runBlocking {
        val key = ConfigurationKey<String>("test.key")
        assertNull(service.resolved(key))
    }

    @Test(expected = IllegalArgumentException::class)
    fun store_rejectsBlankKey() = runBlocking {
        service.store("value", ConfigurationKey(""), ConfigurationLevel.globalDefault)
    }

    private class InMemoryConfigurationRepository : ConfigurationRepository {
        private val store = mutableMapOf<ConfigurationLevel, MutableMap<ConfigurationKey<*>, Any>>()

        @Suppress("UNCHECKED_CAST")
        override suspend fun <T : Any> store(value: T, key: ConfigurationKey<T>, level: ConfigurationLevel) {
            store.getOrPut(level) { mutableMapOf() }[key] = value
        }

        @Suppress("UNCHECKED_CAST")
        override suspend fun <T : Any> value(key: ConfigurationKey<T>, level: ConfigurationLevel): T? {
            return store[level]?.get(key) as? T
        }

        @Suppress("UNCHECKED_CAST")
        override suspend fun <T : Any> remove(key: ConfigurationKey<T>, level: ConfigurationLevel) {
            store[level]?.remove(key)
        }
    }
}
