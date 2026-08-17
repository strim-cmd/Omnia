package com.omnia.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class StreamingTypesTest {

    @Test
    fun activeAppendsContent() {
        val s = StreamingState.Active(content = "")
        val s2 = s.appending("Hello ")
        val s3 = s2.appending("world")
        assertTrue(s3 is StreamingState.Active)
        assertEquals("Hello world", (s3 as StreamingState.Active).content)
        assertEquals("Hello world", s3.partialContent)
    }

    @Test
    fun completingFromActive_producesCompleteMessage() {
        val s = StreamingState.Active(content = "Hello")
        val c = s.completing()
        assertTrue(c is StreamingState.Complete)
        assertEquals("Hello", (c as StreamingState.Complete).message.content)
        assertNull(c.partialContent)
    }

    @Test
    fun interruptingFromActive_preservesPartial() {
        val s = StreamingState.Active(content = "Partial")
        val i = s.interrupting()
        assertTrue(i is StreamingState.Interrupted)
        assertEquals("Partial", (i as StreamingState.Interrupted).content)
        assertEquals("Partial", i.partialContent)
    }

    @Test(expected = StreamingStateError.NotActive::class)
    fun appendingFromComplete_throws() {
        val c = StreamingState.Active(content = "x").completing()
        c.appending("more")
    }

    @Test(expected = StreamingStateError.NotActive::class)
    fun completingFromInterrupted_throws() {
        val i = StreamingState.Active(content = "x").interrupting()
        i.completing()
    }

    @Test
    fun terminalCheck() {
        assertTrue(StreamingState.Active(content = "").isTerminal.not())
        assertTrue(StreamingState.Complete(Message(role = MessageRole.assistant, content = "")).isTerminal)
        assertTrue(StreamingState.Interrupted(content = "").isTerminal)
    }
}
