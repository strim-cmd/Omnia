package com.omnia.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CapabilityTest {

    @Test
    fun allCasesExist() {
        assertEquals(11, Capability.entries.size)
    }

    @Test
    fun realizedCapabilities_containExpectedSet() {
        val realized = Capability.realized
        assertTrue(Capability.textGeneration in realized)
        assertTrue(Capability.conversation in realized)
        assertTrue(Capability.streaming in realized)
        assertEquals(3, realized.size)
    }
}
