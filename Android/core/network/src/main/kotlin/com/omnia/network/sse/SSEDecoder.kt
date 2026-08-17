package com.omnia.network.sse

/**
 * Stateful Server-Sent Events decoder. Handles arbitrary byte boundaries,
 * both `\r\n` (CRLF) and `\n` (LF) line endings, multi-line `data:` fields,
 * and final buffer flush on stream end.
 *
 * Usage:
 * ```
 * val decoder = SSEDecoder()
 * for (chunk in chunks) {
 *     decoder.append(chunk).forEach { event -> process(event) }
 * }
 * decoder.finish().forEach { event -> process(event) }
 * ```
 */
class SSEDecoder {
    private val buffer = StringBuilder()
    private val events = mutableListOf<SSEEvent>()

    /**
     * Feed raw bytes from the transport stream. Returns zero or more
     * parsed [SSEEvent]s. The decoder retains incomplete lines in its
     * internal buffer across calls.
     */
    fun append(chunk: ByteArray): List<SSEEvent> {
        buffer.append(String(chunk))
        flushNewlines()
        return drain()
    }

    /**
     * Flush the internal buffer on stream end. Returns any remaining
     * events that were terminated by EOF rather than a blank line.
     */
    fun finish(): List<SSEEvent> {
        events.clear()
        if (buffer.isNotEmpty()) {
            processBlock(buffer.toString())
            buffer.clear()
        }
        return events.toList()
    }

    private fun flushNewlines() {
        // Normalize CRLF to LF for simpler parsing
        val text = buffer.toString()
        buffer.clear()
        buffer.append(text.replace("\r\n", "\n"))
    }

    private fun drain(): List<SSEEvent> {
        events.clear()
        while (true) {
            val text = buffer.toString()
            val separatorIndex = text.indexOf("\n\n")
            if (separatorIndex < 0) break

            val block = text.substring(0, separatorIndex)
            buffer.clear()
            buffer.append(text.substring(separatorIndex + 2))

            processBlock(block)
        }
        return events.toList()
    }

    private fun processBlock(block: String) {
        val lines = block.split("\n")
        var eventType: String? = null
        var eventId: String? = null
        val dataBuilder = StringBuilder()

        for (line in lines) {
            when {
                line.startsWith(":") -> { /* comment, ignore */ }
                line.startsWith("event:") -> {
                    eventType = line.substringAfter("event:").trim()
                }
                line.startsWith("id:") -> {
                    eventId = line.substringAfter("id:").trim()
                }
                line.startsWith("data:") -> {
                    val raw = line.substringAfter("data:")
                    val value = if (raw.startsWith(" ")) raw.substring(1) else raw
                    if (dataBuilder.isNotEmpty()) {
                        dataBuilder.append("\n")
                    }
                    dataBuilder.append(value)
                }
                // Unknown fields are ignored per SSE spec
            }
        }

        if (dataBuilder.isNotEmpty()) {
            events.add(
                SSEEvent(
                    data = dataBuilder.toString(),
                    event = eventType,
                    id = eventId,
                )
            )
        }
    }
}
