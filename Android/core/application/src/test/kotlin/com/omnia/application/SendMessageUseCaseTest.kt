package com.omnia.application

import com.omnia.domain.Capability
import com.omnia.domain.CapabilityRequestIdentity
import com.omnia.domain.Conversation
import com.omnia.domain.ConversationIdentity
import com.omnia.domain.ConversationRepository
import com.omnia.domain.Message
import com.omnia.domain.MessageRole
import com.omnia.domain.ModelReference
import com.omnia.domain.ProviderCandidate
import com.omnia.domain.ProviderIdentity
import com.omnia.domain.ProviderModelSelection
import com.omnia.domain.StreamingContract
import com.omnia.domain.StreamingRequest
import com.omnia.domain.StreamingUpdate
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

class SendMessageUseCaseTest {

    private lateinit var convRepo: FakeConversationRepository
    private lateinit var useCase: SendMessageUseCase

    private val provider = ProviderIdentity("provider-1")
    private val model = ModelReference("gpt-4")
    private val selection = ProviderModelSelection(provider, model)
    private val candidates = listOf(
        ProviderCandidate(provider, listOf(model))
    )

    @Before
    fun setup() {
        convRepo = FakeConversationRepository()
        useCase = SendMessageUseCase(
            streamingContract = FakeStreamingContract(),
            selectionPolicy = com.omnia.domain.ProviderSelectionPolicy(),
            conversationRepository = convRepo,
            candidatesFor = { candidates },
            now = { FIXED_TIME },
        )
    }

    @Test
    fun send_appendsUserMessageAndStreamsCompletion() = runBlocking {
        val conv = saveConversation("conv-1")
        val request = SendMessageRequest(
            conversation = conv.identity,
            message = Message(role = MessageRole.user, content = "Hello"),
        )

        val updates = useCase.send(request).toList()

        assertTrue(updates.any { it is StreamingUpdate.Completion })
        val stored = convRepo.get("conv-1")!!
        assertTrue(stored.history.any { it.role == MessageRole.user && it.content == "Hello" })
        assertTrue(stored.history.any { it.role == MessageRole.assistant })
    }

    @Test
    fun send_accumulatesContentDeltas() = runBlocking {
        val contract = FakeStreamingContract(
            events = listOf(
                StreamingUpdate.ContentDelta(id("req"), "Hello"),
                StreamingUpdate.ContentDelta(id("req"), " world"),
                StreamingUpdate.Completion(id("req"), Message(MessageRole.assistant, "Hello world")),
            )
        )
        val uc = useCaseWithContract(contract)
        val conv = saveConversation("conv-1")
        val request = SendMessageRequest(
            conversation = conv.identity,
            message = Message(role = MessageRole.user, content = "Hi"),
        )

        val updates = uc.send(request).toList()

        assertEquals(3, updates.size)
        val stored = convRepo.get("conv-1")!!
        assertTrue(stored.partialContent.isNullOrEmpty() || !stored.isStreaming)
    }

    @Test
    fun send_staleIdentityIgnored() = runBlocking {
        val contract = object : StreamingContract {
            override suspend fun stream(request: StreamingRequest): Flow<StreamingUpdate> = flowOf(
                StreamingUpdate.ContentDelta(CapabilityRequestIdentity("wrong-id"), "stale"),
                StreamingUpdate.Completion(
                    CapabilityRequestIdentity("wrong-id"),
                    Message(MessageRole.assistant, "stale"),
                ),
            )
        }
        val uc = useCaseWithContract(contract)
        val conv = saveConversation("conv-1")
        val request = SendMessageRequest(
            conversation = conv.identity,
            message = Message(role = MessageRole.user, content = "Hi"),
        )

        val updates = uc.send(request).toList()

        val stored = convRepo.get("conv-1")!!
        assertEquals(1, stored.history.size)
        assertEquals(MessageRole.user, stored.history[0].role)
        assertTrue(stored.isStreaming)
    }

    @Test
    fun send_interruptionPreservesPartial() = runBlocking {
        val contract = FakeStreamingContract(
            events = listOf(
                StreamingUpdate.ContentDelta(id("req"), "partial content"),
                StreamingUpdate.Interruption(id("req"), "partial content"),
            )
        )
        val uc = useCaseWithContract(contract)
        val conv = saveConversation("conv-1")
        val request = SendMessageRequest(
            conversation = conv.identity,
            message = Message(role = MessageRole.user, content = "Go"),
        )

        uc.send(request).toList()

        val stored = convRepo.get("conv-1")!!
        assertTrue(stored.isInterrupted)
        assertEquals("partial content", stored.partialContent)
    }

    @Test
    fun send_errorWithPartialContent_interruptsStream() = runBlocking {
        val contract = object : StreamingContract {
            override suspend fun stream(request: StreamingRequest): Flow<StreamingUpdate> = flowOf(
                StreamingUpdate.ContentDelta(request.identity, "partial"),
            )
        }
        val uc = useCaseWithContract(contract, generateId = { "req" })
        val conv = saveConversation("conv-1")
        val request = SendMessageRequest(
            conversation = conv.identity,
            message = Message(role = MessageRole.user, content = "Go"),
        )

        uc.send(request).toList()

        val stored = convRepo.get("conv-1")!!
        assertTrue(stored.isInterrupted)
    }

    @Test
    fun resume_throwsWhenNotInterrupted() = runBlocking {
        val conv = saveConversation("conv-1")
        try {
            useCase.resume(conv.identity)
            fail("Expected exception")
        } catch (e: IllegalArgumentException) {
            assertTrue(e.message!!.contains("not in interrupted state"))
        }
    }

    @Test
    fun resume_continuesFromInterruptedState() = runBlocking {
        val interrupted = Conversation(
            identity = ConversationIdentity("conv-1"),
            history = listOf(Message(MessageRole.user, "Hi")),
            streamingState = com.omnia.domain.ConversationStreamingState.Interrupted("partial "),
        )
        convRepo.save(interrupted)

        val contract = FakeStreamingContract(
            events = listOf(
                StreamingUpdate.ContentDelta(id("req"), "more"),
                StreamingUpdate.Completion(id("req"), Message(MessageRole.assistant, "partial more")),
            )
        )
        val uc = useCaseWithContract(contract)

        uc.resume(interrupted.identity).toList()

        val stored = convRepo.get("conv-1")!!
        assertTrue(stored.history.any { it.role == MessageRole.assistant })
    }

    @Test
    fun send_emptyContentAndNoAttachments_throws() = runBlocking {
        val conv = saveConversation("conv-1")
        val request = SendMessageRequest(
            conversation = conv.identity,
            message = Message(role = MessageRole.user, content = ""),
        )
        try {
            useCase.send(request).toList()
            fail("Expected exception")
        } catch (e: ApplicationValidationError.Invalid) {
            assertTrue(e.message!!.contains("content or attachments"))
        }
    }

    @Test
    fun send_missingConversation_throws() = runBlocking {
        val request = SendMessageRequest(
            conversation = ConversationIdentity("nonexistent"),
            message = Message(role = MessageRole.user, content = "Hi"),
        )
        try {
            useCase.send(request).toList()
            fail("Expected exception")
        } catch (e: ApplicationValidationError.Invalid) {
            assertTrue(e.message!!.contains("not found"))
        }
    }

    @Test
    fun send_emptyContentFromProvider_interruptsInsteadOfCompleting() = runBlocking {
        val contract = FakeStreamingContract(
            events = listOf(
                StreamingUpdate.Completion(id("req"), Message(MessageRole.assistant, "")),
            )
        )
        val uc = useCaseWithContract(contract)
        val conv = saveConversation("conv-1")
        val request = SendMessageRequest(
            conversation = conv.identity,
            message = Message(role = MessageRole.user, content = "Hi"),
        )

        uc.send(request).toList()

        val stored = convRepo.get("conv-1")!!
        assertFalse(
            "Empty completion must not persist an assistant message",
            stored.history.any { it.role == MessageRole.assistant },
        )
        assertTrue("Conversation should be in interrupted state", stored.isInterrupted)
    }

    @Test
    fun send_zeroContentDeltasWithEmptyCompletion_interrupts() = runBlocking {
        val contract = FakeStreamingContract(
            events = listOf(
                StreamingUpdate.ContentDelta(id("req"), ""),
                StreamingUpdate.Completion(id("req"), Message(MessageRole.assistant, "")),
            )
        )
        val uc = useCaseWithContract(contract)
        val conv = saveConversation("conv-1")
        val request = SendMessageRequest(
            conversation = conv.identity,
            message = Message(role = MessageRole.user, content: "Hi"),
        )

        uc.send(request).toList()

        val stored = convRepo.get("conv-1")!!
        assertFalse(
            "Empty-only deltas must not persist assistant message",
            stored.history.any { it.role == MessageRole.assistant },
        )
        assertTrue(stored.isInterrupted)
    }

    @Test
    fun send_contentDeltasWithCompletion_persistsAssistantMessage() = runBlocking {
        val contract = FakeStreamingContract(
            events = listOf(
                StreamingUpdate.ContentDelta(id("req"), "Hello"),
                StreamingUpdate.ContentDelta(id("req"), " world"),
                StreamingUpdate.Completion(id("req"), Message(MessageRole.assistant, "Hello world")),
            )
        )
        val uc = useCaseWithContract(contract)
        val conv = saveConversation("conv-1")
        val request = SendMessageRequest(
            conversation = conv.identity,
            message = Message(role = MessageRole.user, content: "Hi"),
        )

        uc.send(request).toList()

        val stored = convRepo.get("conv-1")!!
        val assistant = stored.history.lastOrNull { it.role == MessageRole.assistant }
        assertNotNull("Assistant message must be persisted when content deltas exist", assistant)
        assertEquals("Hello world", assistant!!.content)
        assertFalse(stored.isInterrupted)
    }

    @Test
    fun send_preservesMetadataDuringSave() = runBlocking {
        val conv = Conversation(
            identity = ConversationIdentity("conv-1"),
            title = "User Title",
            titleOrigin = com.omnia.domain.ConversationTitleOrigin.user,
        )
        convRepo.save(conv)

        val contract = FakeStreamingContract(
            events = listOf(
                StreamingUpdate.Completion(id("req"), Message(MessageRole.assistant, "response")),
            )
        )
        val uc = useCaseWithContract(contract)
        val request = SendMessageRequest(
            conversation = conv.identity,
            message = Message(role = MessageRole.user, content = "Hi"),
        )

        uc.send(request).toList()

        val stored = convRepo.get("conv-1")!!
        assertEquals("User Title", stored.title)
        assertEquals(com.omnia.domain.ConversationTitleOrigin.user, stored.titleOrigin)
    }

    @Test
    fun reconciliation_accumulatesMissingDelta() = runBlocking {
        val contract = FakeStreamingContract(
            events = listOf(
                StreamingUpdate.ContentDelta(id("req"), "Hello world"),
                StreamingUpdate.Completion(id("req"), Message(MessageRole.assistant, "Hello world extra")),
            )
        )
        val uc = useCaseWithContract(contract)
        val conv = saveConversation("conv-1")
        val request = SendMessageRequest(
            conversation = conv.identity,
            message = Message(role = MessageRole.user, content = "Hi"),
        )

        uc.send(request).toList()

        val stored = convRepo.get("conv-1")!!
        val assistant = stored.history.lastOrNull { it.role == MessageRole.assistant }
        assertNotNull(assistant)
        assertTrue(assistant!!.content.contains("extra"))
    }

    @Test
    fun send_generatesUniqueRequestIds() = runBlocking {
        val ids = mutableSetOf<String>()
        val contract = object : StreamingContract {
            override suspend fun stream(request: StreamingRequest): Flow<StreamingUpdate> {
                ids.add(request.identity.id)
                return flowOf(
                    StreamingUpdate.Completion(request.identity, Message(MessageRole.assistant, "ok")),
                )
            }
        }
        val uc = useCaseWithContract(contract)

        val conv1 = saveConversation("conv-1")
        val conv2 = saveConversation("conv-2")
        uc.send(SendMessageRequest(conv1.identity, Message(MessageRole.user, "A"))).toList()
        uc.send(SendMessageRequest(conv2.identity, Message(MessageRole.user, "B"))).toList()

        assertEquals(2, ids.size)
    }

    @Test
    fun resume_doesNotAddUserMessage() = runBlocking {
        val interrupted = Conversation(
            identity = ConversationIdentity("conv-1"),
            history = listOf(Message(MessageRole.user, "Hi")),
            streamingState = com.omnia.domain.ConversationStreamingState.Interrupted("partial "),
        )
        convRepo.save(interrupted)

        val contract = FakeStreamingContract(
            events = listOf(
                StreamingUpdate.ContentDelta(id("req"), "more"),
                StreamingUpdate.Completion(id("req"), Message(MessageRole.assistant, "partial more")),
            )
        )
        val uc = useCaseWithContract(contract)

        uc.resume(interrupted.identity).toList()

        val stored = convRepo.get("conv-1")!!
        val userMessages = stored.history.filter { it.role == MessageRole.user }
        assertEquals("Resume must not add user messages", 1, userMessages.size)
    }

    @Test
    fun send_retryAppendsExactlyOneUserMessage() = runBlocking {
        val contract = FakeStreamingContract(
            events = listOf(
                StreamingUpdate.Completion(id("req"), Message(MessageRole.assistant, "response")),
            )
        )
        val uc = useCaseWithContract(contract)
        val conv = saveConversation("conv-1")

        uc.send(SendMessageRequest(conv.identity, Message(MessageRole.user, "Hello"))).toList()
        uc.send(SendMessageRequest(conv.identity, Message(MessageRole.user, "Hello"))).toList()

        val stored = convRepo.get("conv-1")!!
        val userMessages = stored.history.filter { it.role == MessageRole.user }
        assertEquals("Each send() adds exactly one user message, no phantom duplicates", 2, userMessages.size)
    }

    @Test
    fun send_independentConversationsDoNotCrossContaminate() = runBlocking {
        val contract = object : StreamingContract {
            override suspend fun stream(request: StreamingRequest): Flow<StreamingUpdate> = flowOf(
                StreamingUpdate.ContentDelta(request.identity, "delta"),
                StreamingUpdate.Completion(request.identity, Message(MessageRole.assistant, "done")),
            )
        }
        val uc = useCaseWithContract(contract)
        val conv1 = saveConversation("conv-1")
        val conv2 = saveConversation("conv-2")

        uc.send(SendMessageRequest(conv1.identity, Message(MessageRole.user, "A"))).toList()

        val untouched = convRepo.get("conv-2")!!
        assertEquals(0, untouched.history.size)

        uc.send(SendMessageRequest(conv2.identity, Message(MessageRole.user, "B"))).toList()

        val stored1 = convRepo.get("conv-1")!!
        val stored2 = convRepo.get("conv-2")!!
        assertFalse(stored1.history.any { it.role == MessageRole.user && it.content == "B" })
        assertFalse(stored2.history.any { it.role == MessageRole.user && it.content == "A" })
        assertEquals(1, stored1.history.count { it.role == MessageRole.assistant })
        assertEquals(1, stored2.history.count { it.role == MessageRole.assistant })
    }

    @Test
    fun send_lateChunksFromOldGenerationCannotCorruptNew() = runBlocking {
        val oldIdentity = CapabilityRequestIdentity("old-generation")
        val contract = object : StreamingContract {
            override suspend fun stream(request: StreamingRequest): Flow<StreamingUpdate> = flowOf(
                StreamingUpdate.ContentDelta(request.identity, "Hello"),
                StreamingUpdate.ContentDelta(request.identity, " world"),
                StreamingUpdate.ContentDelta(oldIdentity, "STALE"),
                StreamingUpdate.Completion(request.identity, Message(MessageRole.assistant, "Hello world")),
            )
        }
        val uc = useCaseWithContract(contract)
        val conv = saveConversation("conv-1")

        uc.send(SendMessageRequest(conv.identity, Message(MessageRole.user, "Hi"))).toList()

        val stored = convRepo.get("conv-1")!!
        val assistant = stored.history.lastOrNull { it.role == MessageRole.assistant }
        assertNotNull(assistant)
        assertEquals("Hello world", assistant!!.content)
        assertFalse(stored.history.any { it.content.contains("STALE") })
    }

    // --- helpers ---

    private fun id(suffix: String) = CapabilityRequestIdentity("req-$suffix")

    private fun useCaseWithContract(
        contract: StreamingContract,
        generateId: () -> String = { "req" },
    ): SendMessageUseCase {
        return SendMessageUseCase(
            streamingContract = contract,
            selectionPolicy = com.omnia.domain.ProviderSelectionPolicy(),
            conversationRepository = convRepo,
            candidatesFor = { candidates },
            now = { FIXED_TIME },
        )
    }

    private suspend fun saveConversation(id: String): Conversation {
        val conv = Conversation(
            identity = ConversationIdentity(id),
            createdAtEpochMillis = FIXED_TIME,
            updatedAtEpochMillis = FIXED_TIME,
        )
        convRepo.save(conv)
        return conv
    }

    private class FakeStreamingContract(
        private val events: List<StreamingUpdate> = listOf(
            StreamingUpdate.Completion(
                CapabilityRequestIdentity("req"),
                Message(MessageRole.assistant, "response"),
            )
        ),
    ) : StreamingContract {
        override suspend fun stream(request: StreamingRequest): Flow<StreamingUpdate> {
            val mapped = events.map {
                when (it) {
                    is StreamingUpdate.ContentDelta -> StreamingUpdate.ContentDelta(request.identity, it.content)
                    is StreamingUpdate.Completion -> StreamingUpdate.Completion(request.identity, it.message)
                    is StreamingUpdate.Interruption -> StreamingUpdate.Interruption(request.identity, it.partialContent)
                }
            }
            return flowOf(*mapped.toTypedArray())
        }
    }

    private class FakeConversationRepository : ConversationRepository {
        private val store = mutableMapOf<String, Conversation>()
        override suspend fun save(conversation: Conversation) {
            store[conversation.identity.id] = conversation
        }
        override suspend fun conversation(identity: ConversationIdentity): Conversation? = store[identity.id]
        override suspend fun delete(identity: ConversationIdentity) { store.remove(identity.id) }
        override suspend fun allConversations(): List<Conversation> = store.values.toList()
        fun get(id: String): Conversation? = store[id]
    }

    companion object {
        private const val FIXED_TIME = 1000L
    }
}
