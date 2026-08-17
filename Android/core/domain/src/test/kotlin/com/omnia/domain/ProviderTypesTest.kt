package com.omnia.domain

import com.omnia.common.SemanticVersion
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ProviderTypesTest {

    @Test
    fun provider_stateMachine_legalTransitions() {
        val p = Provider(connection())
        assertEquals(ProviderState.registered, p.state)

        p.transitionTo(ProviderState.validated)
        assertEquals(ProviderState.validated, p.state)

        p.transitionTo(ProviderState.initializing)
        assertEquals(ProviderState.initializing, p.state)

        p.transitionTo(ProviderState.ready)
        assertEquals(ProviderState.ready, p.state)

        p.transitionTo(ProviderState.unavailable)
        assertEquals(ProviderState.unavailable, p.state)

        p.transitionTo(ProviderState.initializing)
        assertEquals(ProviderState.initializing, p.state)

        p.transitionTo(ProviderState.ready)
        p.transitionTo(ProviderState.disabled)
        assertEquals(ProviderState.disabled, p.state)

        p.transitionTo(ProviderState.initializing)
        p.transitionTo(ProviderState.ready)
        p.transitionTo(ProviderState.removed)
        assertEquals(ProviderState.removed, p.state)
    }

    @Test(expected = ProviderLifecycleError.InvalidTransition::class)
    fun provider_rejectsIllegalTransition() {
        val p = Provider(connection())
        p.transitionTo(ProviderState.ready) // registered -> ready is illegal
    }

    @Test
    fun provider_canDeliver_checksCapabilities() {
        val p = Provider(connection(capabilities = ProviderCapabilities(setOf(Capability.textGeneration, Capability.streaming))))
        assertTrue(p.canDeliver(Capability.textGeneration))
        assertTrue(p.canDeliver(Capability.streaming))
        assertFalse(p.canDeliver(Capability.vision))
    }

    @Test
    fun provider_replacingConnection_preservesState() {
        val p = Provider(connection())
        p.transitionTo(ProviderState.validated)
        val updated = p.replacingConnection(connection(identity = ProviderIdentity("new-id")))
        assertEquals(ProviderState.validated, updated.state)
        assertEquals("new-id", updated.identity.id)
    }

    @Test
    fun provider_atState_restoresFromRepository() {
        val p = Provider.atState(connection(), ProviderState.ready)
        assertEquals(ProviderState.ready, p.state)
    }

    private fun connection(
        identity: ProviderIdentity = ProviderIdentity("test-provider"),
        capabilities: ProviderCapabilities = ProviderCapabilities(setOf(Capability.textGeneration, Capability.conversation, Capability.streaming)),
    ) = ProviderConnection(
        identity = identity,
        capabilities = capabilities,
        metadata = ProviderMetadata(displayName = "Test"),
        limits = ProviderLimits(),
        version = SemanticVersion.parse("1.0.0"),
    )
}
