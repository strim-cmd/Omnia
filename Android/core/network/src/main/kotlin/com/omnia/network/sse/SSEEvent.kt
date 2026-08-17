package com.omnia.network.sse

/**
 * A single parsed SSE event. `data` may span multiple lines (joined by newlines).
 * `event` and `id` are optional per the SSE spec.
 */
data class SSEEvent(
    val data: String,
    val event: String? = null,
    val id: String? = null,
)
