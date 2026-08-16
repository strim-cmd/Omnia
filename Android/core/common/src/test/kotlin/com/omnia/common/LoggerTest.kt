package com.omnia.common

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test

class LoggerTest {

    @Test
    fun recordingLogger_retainsEntriesInOrder() {
        val clock = ManualClock(startEpochMillis = 42L)
        val logger = RecordingLogger(clock = clock)

        logger.info("TAG", "hello")
        logger.error("TAG", "boom", IllegalStateException("x"))

        assertEquals(2, logger.entries.size)
        assertEquals(LogLevel.INFO, logger.entries[0].level)
        assertEquals("hello", logger.entries[0].message)
        assertEquals(42L, logger.entries[0].timestampEpochMillis)
        assertEquals(LogLevel.ERROR, logger.entries[1].level)
        assertNull(logger.entries[0].throwable)
        assertEquals(IllegalStateException("x").message, logger.entries[1].throwable?.message)
    }

    @Test
    fun noOpLogger_doesNotFail() {
        val logger = NoOpLogger()
        logger.debug("TAG", "ignored")
        logger.warn("TAG", "ignored")
        logger.error("TAG", "ignored")
    }

    @Test
    fun logLevel_isExhaustive() {
        assertSame(LogLevel.VERBOSE, LogLevel.valueOf("VERBOSE"))
        assertSame(LogLevel.DEBUG, LogLevel.valueOf("DEBUG"))
        assertSame(LogLevel.INFO, LogLevel.valueOf("INFO"))
        assertSame(LogLevel.WARN, LogLevel.valueOf("WARN"))
        assertSame(LogLevel.ERROR, LogLevel.valueOf("ERROR"))
    }
}
