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
}
