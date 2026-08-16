package com.omnia.common

/**
 * Framework-independent logging contract. The platform layer (app) provides the
 * real sink (Logcat); tests use [RecordingLogger] or [NoOpLogger].
 *
 * Privacy policy: callers must never pass credentials, API keys, message
 * content, or attachment content to [log]. Tagged, coarse-grained events only.
 */
interface Logger {
    fun log(level: LogLevel, tag: String, message: String, throwable: Throwable? = null)

    fun debug(tag: String, message: String, throwable: Throwable? = null) =
        log(LogLevel.DEBUG, tag, message, throwable)

    fun info(tag: String, message: String, throwable: Throwable? = null) =
        log(LogLevel.INFO, tag, message, throwable)

    fun warn(tag: String, message: String, throwable: Throwable? = null) =
        log(LogLevel.WARN, tag, message, throwable)

    fun error(tag: String, message: String, throwable: Throwable? = null) =
        log(LogLevel.ERROR, tag, message, throwable)
}

enum class LogLevel { VERBOSE, DEBUG, INFO, WARN, ERROR }

/** A single structured log event, retained by [RecordingLogger]. */
data class LogEntry(
    val level: LogLevel,
    val tag: String,
    val message: String,
    val throwable: Throwable?,
    val timestampEpochMillis: Long,
)

/** Discards everything. Useful for tests that assert on behavior, not logs. */
class NoOpLogger : Logger {
    override fun log(level: LogLevel, tag: String, message: String, throwable: Throwable?) = Unit
}

/** Retains every entry in order; deterministic substitute for tests. */
class RecordingLogger(
    private val clock: Clock = ManualClock(),
    private val onEntry: (LogEntry) -> Unit = {},
) : Logger {
    private val buffer = mutableListOf<LogEntry>()

    val entries: List<LogEntry> get() = buffer.toList()

    override fun log(level: LogLevel, tag: String, message: String, throwable: Throwable?) {
        val entry = LogEntry(
            level = level,
            tag = tag,
            message = message,
            throwable = throwable,
            timestampEpochMillis = clock.nowMillis(),
        )
        buffer += entry
        onEntry(entry)
    }
}
