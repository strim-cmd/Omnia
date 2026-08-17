package com.omnia.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ConfigurationTypesTest {

    @Test
    fun key_rejectsBlankName() {
        assertThrows(IllegalArgumentException::class.java) {
            ConfigurationKey<String>(" ")
        }
    }

    @Test
    fun resolutionPolicy_highestPriorityWins() {
        val policy = ConfigurationResolutionPolicy()
        val key = ConfigurationKey<String>("test.key")
        val values = mapOf(
            ConfigurationLevel.workspaceOverride to mapOf(key to "workspace-value"),
            ConfigurationLevel.globalDefault to mapOf(key to "global-value"),
            ConfigurationLevel.capabilityPreference to mapOf(key to "cap-value"),
        )
        assertEquals("workspace-value", policy.resolve(key, values))
    }

    @Test
    fun resolutionPolicy_returnsNullWhenEmpty() {
        val policy = ConfigurationResolutionPolicy()
        val key = ConfigurationKey<String>("test.key")
        assertNull(policy.resolve(key, emptyMap()))
    }

    @Test
    fun resolutionOrder_isFixed() {
        val order = ConfigurationResolutionPolicy.resolutionOrder
        assertEquals(4, order.size)
        assertEquals(ConfigurationLevel.providerSettings, order[0])
        assertEquals(ConfigurationLevel.workspaceOverride, order[1])
        assertEquals(ConfigurationLevel.globalDefault, order[2])
        assertEquals(ConfigurationLevel.capabilityPreference, order[3])
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
