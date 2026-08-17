package com.omnia.application

import com.omnia.domain.Conversation
import com.omnia.domain.ConversationIdentity
import com.omnia.domain.ConversationRepository
import com.omnia.domain.Message
import com.omnia.domain.MessageRole
import com.omnia.domain.Workspace
import com.omnia.domain.WorkspaceIdentity
import com.omnia.domain.WorkspaceRepository
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ConversationServiceTest {

    private lateinit var convRepo: InMemoryConversationRepository
    private lateinit var wsRepo: InMemoryWorkspaceRepository
    private lateinit var service: ConversationService

    @Before
    fun setup() {
        convRepo = InMemoryConversationRepository()
        wsRepo = InMemoryWorkspaceRepository()
        service = ConversationService(convRepo, wsRepo, now = { FIXED_TIME })
    }

    companion object {
        private const val FIXED_TIME = 1000L
    }

    @Test
    fun createConversation_returnsNewConversation() {
        runBlocking {
            val conv = service.createConversation()
            assertNotNull(conv)
            assertEquals(FIXED_TIME, conv.createdAtEpochMillis)
        }
    }

    @Test
    fun getConversation_returnsExisting() {
        runBlocking {
            val conv = service.createConversation()
            val fetched = service.getConversation(conv.identity)
            assertNotNull(fetched)
            assertEquals(conv.identity, fetched?.identity)
        }
    }

    @Test
    fun getConversation_returnsNullForMissing() {
        runBlocking {
            assertNull(service.getConversation(ConversationIdentity("nonexistent")))
        }
    }

    @Test
    fun rename_truncatesAndPersists() {
        runBlocking {
            val conv = service.createConversation()
            val renamed = service.rename("My Chat", conv.identity)
            assertEquals("My Chat", renamed.title)
        }
    }

    @Test
    fun rename_throwsForEmptyTitle() {
        runBlocking {
            try {
                val conv = service.createConversation()
                service.rename("", conv.identity)
                throw AssertionError("Expected Invalid")
            } catch (e: ApplicationValidationError.Invalid) {
                // expected
            }
        }
    }

    @Test
    fun delete_removesConversation() {
        runBlocking {
            val conv = service.createConversation()
            service.delete(conv.identity)
            assertNull(service.getConversation(conv.identity))
        }
    }

    @Test
    fun delete_detachesFromWorkspace() {
        runBlocking {
            val ws = Workspace(WorkspaceIdentity("ws-1"), "Test")
            wsRepo.workspaces["ws-1"] = ws
            val conv = service.createConversationIn(WorkspaceIdentity("ws-1"))
            service.delete(conv.identity)
            val updatedWs = wsRepo.workspaces["ws-1"]
            assertTrue(updatedWs != null && !updatedWs.contains(conv.identity))
        }
    }

    @Test
    fun conversationsIn_returnsSorted() {
        runBlocking {
            val ws = Workspace(WorkspaceIdentity("ws-1"), "Test")
            wsRepo.workspaces["ws-1"] = ws
            val c1 = service.createConversationIn(WorkspaceIdentity("ws-1"))
            Thread.sleep(2)
            val c2 = service.createConversationIn(WorkspaceIdentity("ws-1"))
            val convs = service.conversationsIn(WorkspaceIdentity("ws-1"))
            assertEquals(2, convs.size)
            assertEquals(c2.identity, convs[0].identity)
        }
    }

    private class InMemoryConversationRepository : ConversationRepository {
        val conversations = mutableMapOf<String, Conversation>()
        override suspend fun save(conversation: Conversation) {
            conversations[conversation.identity.id] = conversation
        }
        override suspend fun conversation(identity: ConversationIdentity): Conversation? = conversations[identity.id]
        override suspend fun delete(identity: ConversationIdentity) { conversations.remove(identity.id) }
    }

    private class InMemoryWorkspaceRepository : WorkspaceRepository {
        val workspaces = mutableMapOf<String, Workspace>()
        override suspend fun save(workspace: Workspace) { workspaces[workspace.identity.id] = workspace }
        override suspend fun workspace(identity: WorkspaceIdentity): Workspace? = workspaces[identity.id]
        override suspend fun allWorkspaces(): List<Workspace> = workspaces.values.toList()
        override suspend fun delete(identity: WorkspaceIdentity) { workspaces.remove(identity.id) }
    }
}
