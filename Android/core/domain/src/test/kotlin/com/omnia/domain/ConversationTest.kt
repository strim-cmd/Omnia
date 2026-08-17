package com.omnia.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class ConversationTest {

    @Test
    fun newConversation_startsIdleWithEmptyHistory() {
        val c = conversation()
        assertEquals(ConversationStreamingState.Idle, c.streamingState)
        assertTrue(c.history.isEmpty())
        assertNull(c.partialContent)
        assertFalse(c.isStreaming)
        assertFalse(c.isInterrupted)
        assertFalse(c.hasCompletedGeneration)
    }

    @Test
    fun append_addsMessageToHistory() {
        val c = conversation().append(userMessage("hello"), 1L)
        assertEquals(1, c.history.size)
        assertEquals("hello", c.history[0].content)
        assertEquals(1L, c.updatedAtEpochMillis)
    }

    @Test(expected = ConversationStreamError.StreamInProgress::class)
    fun append_throwsWhenStreaming() {
        conversation().beginStreaming().append(userMessage("nope"))
    }

    @Test
    fun selectModel_rejectsDuringStream() {
        assertThrows(ConversationStreamError.StreamInProgress::class.java) {
            conversation().beginStreaming().selectModel(
                ProviderModelSelection(ProviderIdentity("p"), ModelReference("m"))
            )
        }
    }

    @Test
    fun beginStreaming_transitionsToStreaming() {
        val c = conversation().beginStreaming()
        assertTrue(c.isStreaming)
        assertEquals("", c.partialContent)
    }

    @Test
    fun beginStreaming_resumesFromInterruptedWithPartial() {
        val c = conversation()
            .beginStreaming()
            .appendPartial("partial ")
            .interruptStreaming()
        assertEquals("partial ", c.partialContent)
        assertTrue(c.isInterrupted)

        val resumed = c.beginStreaming()
        assertTrue(resumed.isStreaming)
        assertEquals("partial ", resumed.partialContent)
    }

    @Test(expected = ConversationStreamError.StreamInProgress::class)
    fun beginStreaming_throwsWhenAlreadyStreaming() {
        conversation().beginStreaming().beginStreaming()
    }

    @Test
    fun appendPartial_accumulatesContent() {
        val c = conversation().beginStreaming()
            .appendPartial("Hello")
            .appendPartial(" world")
        assertEquals("Hello world", c.partialContent)
    }

    @Test(expected = ConversationStreamError.NotStreaming::class)
    fun appendPartial_throwsWhenNotStreaming() {
        conversation().appendPartial("nope")
    }

    @Test
    fun completeStreaming_appendsAssistantMessageAndResetsToIdle() {
        val c = conversation().beginStreaming()
            .appendPartial("response")
            .completeStreaming(42L)
        assertEquals(ConversationStreamingState.Idle, c.streamingState)
        assertEquals(1, c.history.size)
        assertEquals("response", c.history[0].content)
        assertEquals(MessageRole.assistant, c.history[0].role)
        assertTrue(c.hasCompletedGeneration)
        assertEquals(42L, c.updatedAtEpochMillis)
    }

    @Test
    fun interruptStreaming_preservesPartialAsInterrupted() {
        val c = conversation().beginStreaming()
            .appendPartial("partial")
            .interruptStreaming()
        assertTrue(c.isInterrupted)
        assertEquals("partial", c.partialContent)
        assertFalse(c.hasCompletedGeneration)
    }

    @Test(expected = ConversationStreamError.NotStreaming::class)
    fun completeStreaming_throwsWhenNotStreaming() {
        conversation().completeStreaming()
    }

    @Test
    fun rename_truncatesTo160Chars() {
        val long = "A".repeat(200)
        val c = conversation().rename(long)
        assertEquals(160, c.title?.length)
        assertEquals(ConversationTitleOrigin.user, c.titleOrigin)
    }

    @Test
    fun autoTitle_derivesFromFirstUserMessage() {
        val c = conversation()
            .append(userMessage("What is AI?"), 1L)
        assertEquals("What is AI?", c.autoTitle())
    }

    @Test
    fun autoTitle_truncatesTo80Chars() {
        val text = "A".repeat(100)
        val c = conversation().append(userMessage(text), 1L)
        assertEquals(80, c.autoTitle()?.length)
    }

    @Test
    fun autoTitle_returnsNullWithNoMessages() {
        assertNull(conversation().autoTitle())
    }

    @Test
    fun mergeMetadata_preservesUserTitle() {
        val userRenamed = conversation().rename("My Title")
        val stored = conversation().autoTitleStoredAs("Auto Title")
        val merged = userRenamed.mergeMetadata(stored)
        assertEquals("My Title", merged.title)
        assertEquals(ConversationTitleOrigin.user, merged.titleOrigin)
    }

    @Test
    fun mergeMetadata_adoptsAutoTitleWhenAutomatic() {
        val auto = conversation().copy(title = null, titleOrigin = ConversationTitleOrigin.automatic)
        val stored = conversation().copy(title = "Stored Title", titleOrigin = ConversationTitleOrigin.automatic)
        val merged = auto.mergeMetadata(stored)
        assertEquals("Stored Title", merged.title)
    }

    // helpers
    private fun conversation() = Conversation(
        identity = ConversationIdentity(id = "conv-1"),
        createdAtEpochMillis = 0L,
        updatedAtEpochMillis = 0L,
    )
    private fun userMessage(text: String) = Message(role = MessageRole.user, content = text)
    private fun Conversation.autoTitleStoredAs(title: String) = copy(title = title, titleOrigin = ConversationTitleOrigin.automatic)
}
