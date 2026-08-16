package com.omnia.common

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ClockTest {

    @Test
    fun manualClock_advancesDeterministically() {
        val clock = ManualClock(startEpochMillis = 1_000L)
        assertEquals(1_000L, clock.nowMillis())
        assertEquals(1L, clock.nowEpochSeconds())

        clock.advanceBy(500L)
        assertEquals(1_500L, clock.nowMillis())
        assertEquals(1L, clock.nowEpochSeconds())
    }

    @Test
    fun manualClock_roundsDownForEpochSeconds() {
        val clock = ManualClock(startEpochMillis = 1_999L)
        assertEquals(1L, clock.nowEpochSeconds())
    }

    @Test
    fun manualClock_rejectsNegativeAdvance() {
        val clock = ManualClock()
        assertThrows(IllegalArgumentException::class.java) { clock.advanceBy(-1L) }
    }

    @Test
    fun systemClock_isMonotonicEnough() {
        val clock = SystemClock()
        val a = clock.nowMillis()
        val b = clock.nowMillis()
        assert(b >= a) { "system clock moved backwards" }
    }
}
