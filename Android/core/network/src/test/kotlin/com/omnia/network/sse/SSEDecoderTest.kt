package com.omnia.network.sse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SSEDecoderTest {

    @Test
    fun singleEventCRLF() {
        val decoder = SSEDecoder()
        val result = decoder.append("data: hello\n\n".toByteArray())
        assertEquals(1, result.size)
        assertEquals("hello", result[0].data)
    }

    @Test
    fun singleEventLF() {
        val decoder = SSEDecoder()
        val result = decoder.append("data: hello\n\n".toByteArray())
        assertEquals(1, result.size)
        assertEquals("hello", result[0].data)
    }

    @Test
    fun twoEvents() {
        val decoder = SSEDecoder()
        val result = decoder.append("data: first\n\ndata: second\n\n".toByteArray())
        assertEquals(2, result.size)
        assertEquals("first", result[0].data)
        assertEquals("second", result[1].data)
    }

    @Test
    fun splitAcrossChunks() {
        val decoder = SSEDecoder()
        val r1 = decoder.append("data: hel".toByteArray())
        assertEquals(0, r1.size)
        val r2 = decoder.append("lo\n\n".toByteArray())
        assertEquals(1, r2.size)
        assertEquals("hello", r2[0].data)
    }

    @Test
    fun splitMidCRLF() {
        val decoder = SSEDecoder()
        val r1 = decoder.append("data: hi\r".toByteArray())
        assertEquals(0, r1.size)
        val r2 = decoder.append("\n\n".toByteArray())
        assertEquals(1, r2.size)
        assertEquals("hi", r2[0].data)
    }

    @Test
    fun multilineData() {
        val decoder = SSEDecoder()
        val result = decoder.append("data: line1\ndata: line2\n\n".toByteArray())
        assertEquals(1, result.size)
        assertEquals("line1\nline2", result[0].data)
    }

    @Test
    fun eventField() {
        val decoder = SSEDecoder()
        val result = decoder.append("event: message\ndata: hello\n\n".toByteArray())
        assertEquals(1, result.size)
        assertEquals("message", result[0].event)
        assertEquals("hello", result[0].data)
    }

    @Test
    fun idField() {
        val decoder = SSEDecoder()
        val result = decoder.append("id: 42\ndata: hello\n\n".toByteArray())
        assertEquals(1, result.size)
        assertEquals("42", result[0].id)
        assertEquals("hello", result[0].data)
    }

    @Test
    fun commentIgnored() {
        val decoder = SSEDecoder()
        val result = decoder.append(": this is a comment\ndata: hello\n\n".toByteArray())
        assertEquals(1, result.size)
        assertEquals("hello", result[0].data)
    }

    @Test
    fun byteBoundarySplitEveryChar() {
        val decoder = SSEDecoder()
        val input = "data: test\n\n"
        val allEvents = mutableListOf<SSEEvent>()
        for (b in input.toByteArray()) {
            allEvents.addAll(decoder.append(byteArrayOf(b)))
        }
        assertEquals(1, allEvents.size)
        assertEquals("test", allEvents[0].data)
    }

    @Test
    fun byteBoundarySplitEveryTwoChars() {
        val decoder = SSEDecoder()
        val input = "data: boundary\n\n"
        val allEvents = mutableListOf<SSEEvent>()
        val bytes = input.toByteArray()
        var i = 0
        while (i < bytes.size) {
            val end = minOf(i + 2, bytes.size)
            allEvents.addAll(decoder.append(bytes.copyOfRange(i, end)))
            i += 2
        }
        assertEquals(1, allEvents.size)
        assertEquals("boundary", allEvents[0].data)
    }

    @Test
    fun multipleBlankLines() {
        val decoder = SSEDecoder()
        val result = decoder.append("data: a\n\n\ndata: b\n\n".toByteArray())
        assertEquals(2, result.size)
        assertEquals("a", result[0].data)
        assertEquals("b", result[1].data)
    }

    @Test
    fun finishFlushesPartialEvent() {
        val decoder = SSEDecoder()
        decoder.append("data: leftover".toByteArray())
        val result = decoder.finish()
        assertEquals(1, result.size)
        assertEquals("leftover", result[0].data)
    }

    @Test
    fun emptyBufferFinishReturnsEmpty() {
        val decoder = SSEDecoder()
        val result = decoder.finish()
        assertTrue(result.isEmpty())
    }

    @Test
    fun realWorldOpenAIChunk() {
        val decoder = SSEDecoder()
        val chunk1 = "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\n"
        val chunk2 = "data: {\"choices\":[{\"delta\":{\"content\":\" world\"}}]}\n\n"
        val chunk3 = "data: [DONE]\n\n"

        val allEvents = mutableListOf<SSEEvent>()
        allEvents.addAll(decoder.append(chunk1.toByteArray()))
        allEvents.addAll(decoder.append(chunk2.toByteArray()))
        allEvents.addAll(decoder.append(chunk3.toByteArray()))

        assertEquals(3, allEvents.size)
        assertTrue(allEvents[0].data.contains("Hello"))
        assertTrue(allEvents[1].data.contains("world"))
        assertEquals("[DONE]", allEvents[2].data)
    }

    @Test
    fun realWorldGeminiChunk() {
        val decoder = SSEDecoder()
        val chunk = "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"Hi\"}]}}]}\n\n"
        val result = decoder.append(chunk.toByteArray())
        assertEquals(1, result.size)
        assertTrue(result[0].data.contains("Hi"))
    }

    @Test
    fun mixedEventTypes() {
        val decoder = SSEDecoder()
        val input = "event: open\ndata: {}\n\nevent: message\ndata: {\"text\":\"hi\"}\n\n"
        val result = decoder.append(input.toByteArray())
        assertEquals(2, result.size)
        assertEquals("open", result[0].event)
        assertEquals("message", result[1].event)
    }

    @Test
    fun lfThenCrlf混合() {
        val decoder = SSEDecoder()
        val r1 = decoder.append("data: a\n\n".toByteArray())
        val r2 = decoder.append("data: b\r\n\r\n".toByteArray())
        assertEquals(1, r1.size)
        assertEquals(1, r2.size)
        assertEquals("a", r1[0].data)
        assertEquals("b", r2[0].data)
    }
}
