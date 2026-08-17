package com.omnia.application

import com.omnia.domain.ConversationIdentity
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ConversationDraftServiceTest {

    private lateinit var configurationService: ConfigurationService
    private lateinit var draftService: ConversationDraftService

    @Before
    fun setup() {
        val repo = InMemoryConfigurationRepository()
        configurationService = ConfigurationService(repo)
        draftService = ConversationDraftService(configurationService)
    }

    @Test
    fun draft_returnsEmptyByDefault() = runBlocking {
        val draft = draftService.draft(ConversationIdentity("c1"))
        assertEquals("", draft)
    }

    @Test
    fun save_andRetrieve() = runBlocking {
        val conv = ConversationIdentity("c1")
        draftService.save("Hello world", conv)
        assertEquals("Hello world", draftService.draft(conv))
    }

    @Test
    fun save_blankRemovesDraft() = runBlocking {
        val conv = ConversationIdentity("c1")
        draftService.save("Hello", conv)
        draftService.save("  ", conv)
        assertEquals("", draftService.draft(conv))
    }

    @Test
    fun remove_removesDraft() = runBlocking {
        val conv = ConversationIdentity("c1")
        draftService.save("Hello", conv)
        draftService.remove(conv)
        assertEquals("", draftService.draft(conv))
    }

    private class InMemoryConfigurationRepository : com.omnia.domain.ConfigurationRepository {
        private val store = mutableMapOf<com.omnia.domain.ConfigurationLevel, MutableMap<com.omnia.domain.ConfigurationKey<*>, Any>>()
        @Suppress("UNCHECKED_CAST")
        override suspend fun <T : Any> store(value: T, key: com.omnia.domain.ConfigurationKey<T>, level: com.omnia.domain.ConfigurationLevel) {
            store.getOrPut(level) { mutableMapOf() }[key] = value
        }
        @Suppress("UNCHECKED_CAST")
        override suspend fun <T : Any> value(key: com.omnia.domain.ConfigurationKey<T>, level: com.omnia.domain.ConfigurationLevel): T? =
            store[level]?.get(key) as? T
        @Suppress("UNCHECKED_CAST")
        override suspend fun <T : Any> remove(key: com.omnia.domain.ConfigurationKey<T>, level: com.omnia.domain.ConfigurationLevel) {
            store[level]?.remove(key)
        }
    }
}
