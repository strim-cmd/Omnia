package com.omnia.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class IdentityTypesTest {

    @Test
    fun providerIdentity_equality() {
        assertEquals(ProviderIdentity("p1"), ProviderIdentity("p1"))
        assertNotEquals(ProviderIdentity("p1"), ProviderIdentity("p2"))
    }

    @Test
    fun conversationIdentity_equality() {
        assertEquals(ConversationIdentity("c1"), ConversationIdentity("c1"))
        assertNotEquals(ConversationIdentity("c1"), ConversationIdentity("c2"))
    }

    @Test
    fun workspaceIdentity_equality() {
        assertEquals(WorkspaceIdentity("w1"), WorkspaceIdentity("w1"))
        assertNotEquals(WorkspaceIdentity("w1"), WorkspaceIdentity("w2"))
    }

    @Test
    fun credentialReference_equality() {
        assertEquals(CredentialReference("cr1"), CredentialReference("cr1"))
        assertNotEquals(CredentialReference("cr1"), CredentialReference("cr2"))
    }

    @Test
    fun modelReference_isValueBased() {
        val a = ModelReference(name = "gpt-4o")
        val b = ModelReference(name = "gpt-4o")
        assertEquals(a, b)
        assertEquals(a.hashCode(), b.hashCode())
    }

    @Test(expected = IllegalArgumentException::class)
    fun modelReference_rejectsBlank() {
        ModelReference(name = "")
    }
}
