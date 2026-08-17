package com.omnia.data.workspace

import com.omnia.domain.ConversationIdentity
import com.omnia.domain.ProviderIdentity
import com.omnia.domain.Workspace
import com.omnia.domain.WorkspaceIdentity
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

class FileWorkspaceRepositoryTest {

    private lateinit var tempDir: File
    private lateinit var repo: FileWorkspaceRepository

    @Before
    fun setup() {
        tempDir = Files.createTempDirectory("WorkspaceRepoTests").toFile()
        repo = FileWorkspaceRepository(tempDir)
    }

    @After
    fun teardown() {
        tempDir.deleteRecursively()
    }

    @Test
    fun save_then_load_roundTripsWorkspace() = runBlocking {
        val workspace = Workspace(
            identity = WorkspaceIdentity("ws-1"),
            name = "My Workspace",
        )
        repo.save(workspace)
        val loaded = repo.workspace(WorkspaceIdentity("ws-1"))
        assertNotNull(loaded)
        assertEquals("My Workspace", loaded!!.name)
    }

    @Test
    fun save_then_load_preservesConversationsAndProviders() = runBlocking {
        val workspace = Workspace(
            identity = WorkspaceIdentity("ws-1"),
            name = "My Workspace",
            conversationIdentities = setOf(
                ConversationIdentity("conv-1"),
                ConversationIdentity("conv-2"),
            ),
            providerIdentities = setOf(
                ProviderIdentity("prov-1"),
            ),
        )
        repo.save(workspace)

        val loaded = repo.workspace(WorkspaceIdentity("ws-1"))!!
        assertEquals(2, loaded.conversationIdentities.size)
        assertEquals(1, loaded.providerIdentities.size)
    }

    @Test
    fun save_replacesExistingWorkspaceWithSameIdentity() = runBlocking {
        val first = Workspace(
            identity = WorkspaceIdentity("ws-1"),
            name = "First",
        )
        repo.save(first)

        val second = Workspace(
            identity = WorkspaceIdentity("ws-1"),
            name = "Second",
        )
        repo.save(second)

        val loaded = repo.workspace(WorkspaceIdentity("ws-1"))!!
        assertEquals("Second", loaded.name)
    }

    @Test
    fun workspace_withAbsentIdentityReturnsNull() = runBlocking {
        assertNull(repo.workspace(WorkspaceIdentity("nonexistent")))
    }

    @Test
    fun allWorkspaces_returnsEveryStoredWorkspace() = runBlocking {
        repo.save(Workspace(identity = WorkspaceIdentity("ws-1"), name = "One"))
        repo.save(Workspace(identity = WorkspaceIdentity("ws-2"), name = "Two"))

        val all = repo.allWorkspaces()
        assertEquals(2, all.size)
    }

    @Test
    fun allWorkspaces_emptyRepositoryReturnsEmpty() = runBlocking {
        assertTrue(repo.allWorkspaces().isEmpty())
    }

    @Test
    fun allWorkspaces_skipsMalformedRecord() = runBlocking {
        repo.save(Workspace(identity = WorkspaceIdentity("ws-1"), name = "One"))
        File(tempDir, "malformed.json").writeText("{bad json!!!")

        val all = repo.allWorkspaces()
        assertEquals(1, all.size)
        assertTrue(File(tempDir, "malformed.json").exists())
    }

    @Test
    fun delete_removesTheWorkspace() = runBlocking {
        repo.save(Workspace(identity = WorkspaceIdentity("ws-1"), name = "One"))
        repo.delete(WorkspaceIdentity("ws-1"))
        assertNull(repo.workspace(WorkspaceIdentity("ws-1")))
    }

    @Test
    fun delete_absentIdentityIsNotAnError() = runBlocking {
        repo.delete(WorkspaceIdentity("nonexistent"))
    }

    @Test
    fun delete_isIdempotent() = runBlocking {
        repo.save(Workspace(identity = WorkspaceIdentity("ws-1"), name = "One"))
        repo.delete(WorkspaceIdentity("ws-1"))
        repo.delete(WorkspaceIdentity("ws-1"))
    }

    @Test
    fun freshInstance_loadsPreviouslyPersistedData() = runBlocking {
        val workspace = Workspace(
            identity = WorkspaceIdentity("ws-1"),
            name = "My Workspace",
            conversationIdentities = setOf(ConversationIdentity("conv-1")),
            providerIdentities = setOf(ProviderIdentity("prov-1")),
        )
        repo.save(workspace)

        val freshRepo = FileWorkspaceRepository(tempDir)
        val loaded = freshRepo.workspace(WorkspaceIdentity("ws-1"))!!
        assertEquals("My Workspace", loaded.name)
        assertEquals(1, loaded.conversationIdentities.size)
        assertEquals(1, loaded.providerIdentities.size)
    }

    @Test
    fun freshInstance_seesAllWorkspaces() = runBlocking {
        repo.save(Workspace(identity = WorkspaceIdentity("ws-1"), name = "One"))
        repo.save(Workspace(identity = WorkspaceIdentity("ws-2"), name = "Two"))

        val freshRepo = FileWorkspaceRepository(tempDir)
        assertEquals(2, freshRepo.allWorkspaces().size)
    }
}
