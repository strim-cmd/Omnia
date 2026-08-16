package com.omnia.app

import android.util.Log
import com.omnia.common.LogLevel
import com.omnia.common.Logger

/**
 * Logcat-backed [Logger]. Filters by [minLevel].
 *
 * Privacy policy: never pass credentials, API keys, message content, or
 * attachment content. Tagged, coarse-grained events only.
 */
class AndroidLogger(private val minLevel: LogLevel = LogLevel.INFO) : Logger {

    override fun log(level: LogLevel, tag: String, message: String, throwable: Throwable?) {
        if (level.ordinal < minLevel.ordinal) return
        val text = throwable?.let { "$message\n${Log.getStackTraceString(it)}" } ?: message
        Log.println(level.toAndroidPriority(), tag, text)
    }

    private fun LogLevel.toAndroidPriority(): Int = when (this) {
        LogLevel.VERBOSE -> Log.VERBOSE
        LogLevel.DEBUG -> Log.DEBUG
        LogLevel.INFO -> Log.INFO
        LogLevel.WARN -> Log.WARN
        LogLevel.ERROR -> Log.ERROR
    }
}
