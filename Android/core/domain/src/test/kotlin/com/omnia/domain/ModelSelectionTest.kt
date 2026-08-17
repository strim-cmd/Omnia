package com.omnia.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ModelSelectionTest {

    @Test
    fun selection_carriesProviderAndModelPair() {
        val provider = ProviderIdentity(id = "openai")
        val model = ModelReference(name = "gpt-4o")
        val selection = ProviderModelSelection(provider = provider, model = model)

        assertEquals(provider, selection.provider)
        assertEquals(model, selection.model)
    }

    @Test
    fun selection_isValueBased() {
        val a = ProviderModelSelection(ProviderIdentity("openai"), ModelReference("gpt-4o"))
        val b = ProviderModelSelection(ProviderIdentity("openai"), ModelReference("gpt-4o"))
        assertEquals(a, b)
        assertEquals(a.hashCode(), b.hashCode())
    }

    @Test
    fun selection_rejectsBlankIdentifiers() {
        assertThrows(IllegalArgumentException::class.java) {
            ProviderModelSelection(ProviderIdentity(" "), ModelReference("gpt-4o"))
        }
        assertThrows(IllegalArgumentException::class.java) {
            ProviderModelSelection(ProviderIdentity("openai"), ModelReference(""))
        }
    }

    @Test
    fun distinctSelectionsAreNotEqual() {
        val a = ProviderModelSelection(ProviderIdentity("openai"), ModelReference("gpt-4o"))
        val b = ProviderModelSelection(ProviderIdentity("openai"), ModelReference("gpt-4o-mini"))
        assertNotEquals(a, b)
    }
}
