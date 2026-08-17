package com.omnia.application

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DataManagementServiceTest {

    @Test
    fun clearAll_invokesOperation() = runBlocking {
        var invoked = false
        val service = DataManagementService { invoked = true }
        service.clearAll()
        assertTrue(invoked)
    }

    @Test
    fun clearAll_propagatesException() = runBlocking {
        val service = DataManagementService { throw RuntimeException("storage error") }
        try {
            service.clearAll()
            throw AssertionError("Expected exception")
        } catch (e: RuntimeException) {
            assertEquals("storage error", e.message)
        }
    }

    @Test
    fun clearAll_invokesExactlyOnce() = runBlocking {
        var count = 0
        val service = DataManagementService { count++ }
        service.clearAll()
        service.clearAll()
        assertEquals(2, count)
    }

    @Test
    fun clearAll_wipesAllDataThroughLambda() = runBlocking {
        val mutableStore = mutableMapOf(
            "conversations" to mutableListOf("conv-1", "conv-2"),
            "providers" to mutableListOf("prov-1"),
            "credentials" to mutableListOf("cred-1", "cred-2"),
        )
        val service = DataManagementService {
            mutableStore["conversations"]?.clear()
            mutableStore["providers"]?.clear()
            mutableStore["credentials"]?.clear()
        }

        assertTrue(mutableStore["conversations"]!!.isNotEmpty())

        service.clearAll()

        assertTrue(mutableStore["conversations"]!!.isEmpty())
        assertTrue(mutableStore["providers"]!!.isEmpty())
        assertTrue(mutableStore["credentials"]!!.isEmpty())
    }
}
