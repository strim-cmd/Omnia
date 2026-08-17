package com.omnia.domain

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test

class ProviderLifecycleServiceTest {

    @Test
    fun register_andRetrieve() = runBlocking {
        val service = ProviderLifecycleService()
        val conn = testConnection()
        val id = service.register(conn)
        assertEquals(ProviderIdentity("test-provider"), id)

        val provider = service.provider(id)
        assertEquals(ProviderState.registered, provider?.state)
    }

    @Test
    fun transition_validFlow() = runBlocking {
        val service = ProviderLifecycleService()
        val id = service.register(testConnection())
        service.transition(id, ProviderState.validated)
        service.transition(id, ProviderState.initializing)
        service.transition(id, ProviderState.ready)
        assertEquals(ProviderState.ready, service.state(id))
    }

    @Test
    fun unregister_idempotent() = runBlocking {
        val service = ProviderLifecycleService()
        val id = service.register(testConnection())
        service.unregister(id)
        service.unregister(id)
        assertEquals(null, service.provider(id))
    }

    @Test
    fun providersReady_filtersCorrectly() = runBlocking {
        val service = ProviderLifecycleService()
        service.register(testConnection(ProviderIdentity("ready"), setOf(Capability.textGeneration)))
        service.register(testConnection(ProviderIdentity("notready"), setOf(Capability.textGeneration)))
        service.transition(ProviderIdentity("ready"), ProviderState.validated)
        service.transition(ProviderIdentity("ready"), ProviderState.initializing)
        service.transition(ProviderIdentity("ready"), ProviderState.ready)

        val ready = service.providersReady(Capability.textGeneration)
        assertEquals(1, ready.size)
        assertEquals("ready", ready[0].id)
    }

    private fun testConnection(
        identity: ProviderIdentity = ProviderIdentity("test-provider"),
        capabilities: Set<Capability> = setOf(Capability.textGeneration, Capability.conversation, Capability.streaming),
    ) = ProviderConnection(
        identity = identity,
        capabilities = ProviderCapabilities(capabilities),
        metadata = ProviderMetadata(displayName = "Test"),
        limits = ProviderLimits(),
        version = com.omnia.common.SemanticVersion.parse("1.0.0"),
    )
}
