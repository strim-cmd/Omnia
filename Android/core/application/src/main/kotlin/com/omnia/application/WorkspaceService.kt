package com.omnia.application

import com.omnia.domain.Workspace
import com.omnia.domain.WorkspaceIdentity
import com.omnia.domain.WorkspaceRepository

class WorkspaceService(
    private val repository: WorkspaceRepository,
) {
    @Throws(ApplicationValidationError::class)
    suspend fun createWorkspace(name: String): Workspace {
        val trimmed = name.trim()
        require(trimmed.isNotEmpty()) { throw ApplicationValidationError.Invalid("Workspace name must not be empty") }
        val workspace = Workspace(
            identity = WorkspaceIdentity(id = generateId()),
            name = trimmed,
        )
        repository.save(workspace)
        return workspace
    }

    suspend fun workspace(identity: WorkspaceIdentity): Workspace? =
        repository.workspace(identity)

    @Throws(ApplicationValidationError::class)
    suspend fun addConversation(
        conversationIdentity: com.omnia.domain.ConversationIdentity,
        workspaceId: WorkspaceIdentity,
    ): Workspace {
        val workspace = repository.workspace(workspaceId)
            ?: throw ApplicationValidationError.Invalid("Workspace not found: ${workspaceId.id}")
        val updated = workspace.adding(conversationIdentity)
        repository.save(updated)
        return updated
    }

    @Throws(ApplicationValidationError::class)
    suspend fun addProvider(
        providerIdentity: com.omnia.domain.ProviderIdentity,
        workspaceId: WorkspaceIdentity,
    ): Workspace {
        val workspace = repository.workspace(workspaceId)
            ?: throw ApplicationValidationError.Invalid("Workspace not found: ${workspaceId.id}")
        val updated = workspace.adding(providerIdentity)
        repository.save(updated)
        return updated
    }

    private fun generateId(): String = java.util.UUID.randomUUID().toString()
}
