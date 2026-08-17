package com.omnia.data.conversation

import com.omnia.domain.*
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

class FileConversationRepositoryTest {

    private lateinit var tempDir: File
    private lateinit var repo: FileConversationRepository

    @Before
    fun setup() {
        tempDir = Files.createTempDirectory("ConvRepoTests").toFile()
        repo = FileConversationRepository(tempDir)
    }

    @After
    fun teardown() {
        tempDir.deleteRecursively()
    }

    @Test
    fun save_then_load_roundTripsEmptyConversation() = runBlocking {
        val conversation = Conversation(
            identity = ConversationIdentity("conv-1"),
            createdAtEpochMillis = 1000L,
            updatedAtEpochMillis = 1000L,
        )
        repo.save(conversation)
        val loaded = repo.conversation(ConversationIdentity("conv-1"))
        assertNotNull(loaded)
        assertEquals("conv-1", loaded!!.identity.id)
        assertTrue(loaded.history.isEmpty())
    }

    @Test
    fun save_then_load_preservesFullHistoryInOrder() = runBlocking {
        var conversation = Conversation(
            identity = ConversationIdentity("conv-1"),
            createdAtEpochMillis = 1000L,
            updatedAtEpochMillis = 1000L,
        )
        conversation = conversation.append(Message(role = MessageRole.system, content = "System prompt"), 1000L)
        conversation = conversation.append(Message(role = MessageRole.user, content = "Hello"), 1001L)
        conversation = conversation.append(Message(role = MessageRole.assistant, content = "Hi there"), 1002L)
        repo.save(conversation)

        val loaded = repo.conversation(ConversationIdentity("conv-1"))!!
        assertEquals(3, loaded.history.size)
        assertEquals(MessageRole.system, loaded.history[0].role)
        assertEquals("System prompt", loaded.history[0].content)
        assertEquals(MessageRole.user, loaded.history[1].role)
        assertEquals("Hello", loaded.history[1].content)
        assertEquals(MessageRole.assistant, loaded.history[2].role)
        assertEquals("Hi there", loaded.history[2].content)
    }

    @Test
    fun save_then_load_preservesStreamingState() = runBlocking {
        var conversation = Conversation(
            identity = ConversationIdentity("conv-1"),
            createdAtEpochMillis = 1000L,
            updatedAtEpochMillis = 1000L,
        )
        conversation = conversation.append(Message(role = MessageRole.user, content = "Hello"), 1000L)
        conversation = conversation.beginStreaming()
        conversation = conversation.appendPartial("partial ")
        conversation = conversation.interruptStreaming()
        repo.save(conversation)

        val loaded = repo.conversation(ConversationIdentity("conv-1"))!!
        assertTrue(loaded.isInterrupted)
        assertEquals("partial ", loaded.partialContent)
    }

    @Test
    fun save_replacesExistingConversationWithSameIdentity() = runBlocking {
        val first = Conversation(
            identity = ConversationIdentity("conv-1"),
            title = "first",
            createdAtEpochMillis = 1000L,
            updatedAtEpochMillis = 1000L,
        )
        repo.save(first)

        val second = Conversation(
            identity = ConversationIdentity("conv-1"),
            title = "second",
            createdAtEpochMillis = 2000L,
            updatedAtEpochMillis = 2000L,
        )
        repo.save(second)

        val loaded = repo.conversation(ConversationIdentity("conv-1"))!!
        assertEquals("second", loaded.title)
    }

    @Test
    fun conversation_withAbsentIdentityReturnsNull() = runBlocking {
        assertNull(repo.conversation(ConversationIdentity("nonexistent")))
    }

    @Test
    fun delete_removesTheConversation() = runBlocking {
        val conversation = Conversation(
            identity = ConversationIdentity("conv-1"),
            createdAtEpochMillis = 1000L,
            updatedAtEpochMillis = 1000L,
        )
        repo.save(conversation)
        repo.delete(ConversationIdentity("conv-1"))
        assertNull(repo.conversation(ConversationIdentity("conv-1")))
    }

    @Test
    fun delete_absentIdentityIsNotAnError() = runBlocking {
        repo.delete(ConversationIdentity("nonexistent"))
    }

    @Test
    fun delete_isIdempotent() = runBlocking {
        val conversation = Conversation(
            identity = ConversationIdentity("conv-1"),
            createdAtEpochMillis = 1000L,
            updatedAtEpochMillis = 1000L,
        )
        repo.save(conversation)
        repo.delete(ConversationIdentity("conv-1"))
        repo.delete(ConversationIdentity("conv-1"))
    }

    @Test
    fun allConversations_returnsEveryStoredConversation() = runBlocking {
        val c1 = Conversation(
            identity = ConversationIdentity("conv-1"),
            createdAtEpochMillis = 1000L,
            updatedAtEpochMillis = 1000L,
        )
        val c2 = Conversation(
            identity = ConversationIdentity("conv-2"),
            createdAtEpochMillis = 2000L,
            updatedAtEpochMillis = 2000L,
        )
        repo.save(c1)
        repo.save(c2)

        val all = repo.allConversations()
        assertEquals(2, all.size)
        assertEquals(setOf("conv-1", "conv-2"), all.map { it.identity.id }.toSet())
    }

    @Test
    fun allConversations_emptyRepositoryReturnsEmpty() = runBlocking {
        assertTrue(repo.allConversations().isEmpty())
    }

    @Test
    fun allConversations_skipsOneMalformedRecordWithoutDeletingIt() = runBlocking {
        val conversation = Conversation(
            identity = ConversationIdentity("conv-1"),
            createdAtEpochMillis = 1000L,
            updatedAtEpochMillis = 1000L,
        )
        repo.save(conversation)

        File(tempDir, "malformed.json").writeText("{not valid json!!!")

        val all = repo.allConversations()
        assertEquals(1, all.size)
        assertEquals("conv-1", all[0].identity.id)

        assertTrue(File(tempDir, "malformed.json").exists())
    }

    @Test
    fun removeAll_removesAllJsonFiles() = runBlocking {
        val conversation = Conversation(
            identity = ConversationIdentity("conv-1"),
            createdAtEpochMillis = 1000L,
            updatedAtEpochMillis = 1000L,
        )
        repo.save(conversation)
        repo.removeAll()
        assertTrue(repo.allConversations().isEmpty())
    }

    @Test
    fun removeAll_preservesNonJsonFiles() = runBlocking {
        val conversation = Conversation(
            identity = ConversationIdentity("conv-1"),
            createdAtEpochMillis = 1000L,
            updatedAtEpochMillis = 1000L,
        )
        repo.save(conversation)
        File(tempDir, "keep.txt").writeText("not json")
        repo.removeAll()
        assertTrue(repo.allConversations().isEmpty())
        assertTrue(File(tempDir, "keep.txt").exists())
    }

    @Test
    fun save_then_load_preservesModelSelection() = runBlocking {
        val conversation = Conversation(
            identity = ConversationIdentity("conv-1"),
            modelSelection = ProviderModelSelection(
                provider = ProviderIdentity("prov-1"),
                model = ModelReference("gpt-4"),
            ),
            createdAtEpochMillis = 1000L,
            updatedAtEpochMillis = 1000L,
        )
        repo.save(conversation)

        val loaded = repo.conversation(ConversationIdentity("conv-1"))!!
        assertNotNull(loaded.modelSelection)
        assertEquals("prov-1", loaded.modelSelection!!.provider.id)
        assertEquals("gpt-4", loaded.modelSelection!!.model.name)
    }

    @Test
    fun save_then_load_preservesTitleAndTitleOrigin() = runBlocking {
        val conversation = Conversation(
            identity = ConversationIdentity("conv-1"),
            title = "My Title",
            titleOrigin = ConversationTitleOrigin.user,
            createdAtEpochMillis = 1000L,
            updatedAtEpochMillis = 1000L,
        )
        repo.save(conversation)

        val loaded = repo.conversation(ConversationIdentity("conv-1"))!!
        assertEquals("My Title", loaded.title)
        assertEquals(ConversationTitleOrigin.user, loaded.titleOrigin)
    }

    @Test
    fun freshInstance_loadsPreviouslyPersistedData() = runBlocking {
        var conversation = Conversation(
            identity = ConversationIdentity("conv-1"),
            createdAtEpochMillis = 1000L,
            updatedAtEpochMillis = 1000L,
        )
        conversation = conversation.append(Message(role = MessageRole.user, content = "Hello"), 1000L)
        conversation = conversation.beginStreaming()
        conversation = conversation.appendPartial("partial data")
        conversation = conversation.interruptStreaming()
        repo.save(conversation)

        val freshRepo = FileConversationRepository(tempDir)
        val loaded = freshRepo.conversation(ConversationIdentity("conv-1"))!!
        assertEquals(1, loaded.history.size)
        assertEquals("Hello", loaded.history[0].content)
        assertTrue(loaded.isInterrupted)
        assertEquals("partial data", loaded.partialContent)
        assertEquals(1, freshRepo.allConversations().size)
    }

    @Test
    fun freshInstance_seesAllConversations() = runBlocking {
        repo.save(Conversation(
            identity = ConversationIdentity("conv-1"),
            createdAtEpochMillis = 1000L, updatedAtEpochMillis = 1000L,
        ))
        repo.save(Conversation(
            identity = ConversationIdentity("conv-2"),
            createdAtEpochMillis = 2000L, updatedAtEpochMillis = 2000L,
        ))

        val freshRepo = FileConversationRepository(tempDir)
        assertEquals(2, freshRepo.allConversations().size)
    }
}
