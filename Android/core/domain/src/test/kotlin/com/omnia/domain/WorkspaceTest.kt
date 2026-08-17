package com.omnia.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WorkspaceTest {

    @Test
    fun containsConversation() {
        val ws = workspace()
        val convId = ConversationIdentity(id = "c1")
        assertFalse(ws.contains(convId))
        val updated = ws.adding(convId)
        assertTrue(updated.contains(convId))
    }

    @Test
    fun containsProvider() {
        val ws = workspace()
        val provId = ProviderIdentity(id = "p1")
        assertFalse(ws.contains(provId))
        val updated = ws.adding(provId)
        assertTrue(updated.contains(provId))
    }

    @Test
    fun removingConversation_removes() {
        val ws = workspace().adding(ConversationIdentity("c1"))
        val updated = ws.removing(ConversationIdentity("c1"))
        assertFalse(updated.contains(ConversationIdentity("c1")))
    }

    @Test
    fun removingProvider_removes() {
        val ws = workspace().adding(ProviderIdentity("p1"))
        val updated = ws.removing(ProviderIdentity("p1"))
        assertFalse(updated.contains(ProviderIdentity("p1")))
    }

    @Test
    fun addingDuplicateIsIdempotent() {
        val ws = workspace().adding(ConversationIdentity("c1")).adding(ConversationIdentity("c1"))
        assertEquals(1, ws.conversationIdentities.size)
    }

    @Test(expected = IllegalArgumentException::class)
    fun blankNameRejected() {
        Workspace(identity = WorkspaceIdentity("ws-1"), name = "  ")
    }

    private fun workspace() = Workspace(
        identity = WorkspaceIdentity(id = "ws-1"),
        name = "Test Workspace",
    )
}
