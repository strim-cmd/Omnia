package com.omnia.application

import com.omnia.domain.Workspace
import com.omnia.domain.WorkspaceIdentity
import com.omnia.domain.WorkspaceRepository
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

class WorkspaceServiceTest {

    private lateinit var repo: InMemoryWorkspaceRepository
    private lateinit var service: WorkspaceService

    @Before
    fun setup() {
        repo = InMemoryWorkspaceRepository()
        service = WorkspaceService(repo)
    }

    @Test
    fun createWorkspace_persists() {
        runBlocking {
            val ws = service.createWorkspace("My Workspace")
            assertNotNull(ws)
            assertEquals("My Workspace", ws.name)
            assertNotNull(repo.workspaces[ws.identity.id])
        }
    }

    @Test
    fun createWorkspace_rejectsBlank() {
        runBlocking {
            try {
                service.createWorkspace("  ")
                throw AssertionError("Expected Invalid")
            } catch (e: ApplicationValidationError.Invalid) {
                // expected
            }
        }
    }

    @Test
    fun workspace_returnsExisting() {
        runBlocking {
            val ws = service.createWorkspace("Test")
            val fetched = service.workspace(ws.identity)
            assertEquals(ws.identity, fetched?.identity)
        }
    }

    @Test
    fun workspace_returnsNullForMissing() {
        runBlocking {
            assertNull(service.workspace(WorkspaceIdentity("nonexistent")))
        }
    }

    private class InMemoryWorkspaceRepository : WorkspaceRepository {
        val workspaces = mutableMapOf<String, Workspace>()
        override suspend fun save(workspace: Workspace) { workspaces[workspace.identity.id] = workspace }
        override suspend fun workspace(identity: WorkspaceIdentity): Workspace? = workspaces[identity.id]
        override suspend fun allWorkspaces(): List<Workspace> = workspaces.values.toList()
        override suspend fun delete(identity: WorkspaceIdentity) { workspaces.remove(identity.id) }
    }
}
