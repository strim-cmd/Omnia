package com.omnia.common

/**
 * Source of the current time. Framework-independent so that every consumer can
 * be tested deterministically with a manual clock.
 */
interface Clock {
    /** Milliseconds since the Unix epoch. */
    fun nowMillis(): Long

    /** Seconds since the Unix epoch. */
    fun nowEpochSeconds(): Long
}

/** [Clock] backed by the system clock. */
class SystemClock : Clock {
    override fun nowMillis(): Long = System.currentTimeMillis()
    override fun nowEpochSeconds(): Long = System.currentTimeMillis() / 1_000L
}

/**
 * Deterministic [Clock] for tests and previews. Time only moves forward when
 * [advanceBy] is called.
 */
class ManualClock(startEpochMillis: Long = 0L) : Clock {
    private var currentEpochMillis: Long = startEpochMillis

    override fun nowMillis(): Long = currentEpochMillis

    override fun nowEpochSeconds(): Long = currentEpochMillis / 1_000L

    fun advanceBy(millis: Long) {
        require(millis >= 0L) { "advanceBy must be non-negative, was $millis" }
        currentEpochMillis += millis
    }
}
