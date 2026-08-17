package com.omnia.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertThrows
import org.junit.Test

class ModelCapabilityProfileTest {

    @Test
    fun supportFor_returnsCorrectState() {
        val profile = ModelCapabilityProfile(
            supported = setOf(Capability.textGeneration),
            unsupported = setOf(Capability.vision),
        )
        assertEquals(ModelCapabilitySupport.supported, profile.supportFor(Capability.textGeneration))
        assertEquals(ModelCapabilitySupport.unsupported, profile.supportFor(Capability.vision))
        assertEquals(ModelCapabilitySupport.unknown, profile.supportFor(Capability.conversation))
    }

    @Test
    fun replacing_addsAndRemovesCorrectly() {
        val empty = ModelCapabilityProfile()
        val withSupport = empty.replacing(ModelCapabilitySupport.supported, Capability.vision)
        assertEquals(ModelCapabilitySupport.supported, withSupport.supportFor(Capability.vision))

        val removed = withSupport.replacing(ModelCapabilitySupport.unknown, Capability.vision)
        assertEquals(ModelCapabilitySupport.unknown, removed.supportFor(Capability.vision))
    }

    @Test
    fun overlappingSets_rejected() {
        assertThrows(IllegalArgumentException::class.java) {
            ModelCapabilityProfile(
                supported = setOf(Capability.textGeneration),
                unsupported = setOf(Capability.textGeneration),
            )
        }
    }
}

private fun assertThrows(clazz: Class<out Throwable>, block: () -> Unit) {
    try {
        block()
        throw AssertionError("Expected ${clazz.simpleName} but none was thrown")
    } catch (e: Exception) {
        if (!clazz.isInstance(e)) {
            throw AssertionError("Expected ${clazz.simpleName} but got ${e::class.simpleName}: ${e.message}")
        }
    }
}
