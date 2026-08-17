package com.omnia.application

import com.omnia.domain.Conversation
import com.omnia.domain.ConversationIdentity
import com.omnia.domain.ConversationRepository
import com.omnia.domain.ConversationStreamError
import com.omnia.domain.MessageAttachment
import com.omnia.domain.ProviderModelSelection
import com.omnia.domain.WorkspaceIdentity
import com.omnia.domain.WorkspaceRepository

class ConversationService(
    private val conversationRepository: ConversationRepository,
    private val workspaceRepository: WorkspaceRepository,
    private val defaultModelSelection: suspend () -> ProviderModelSelection? = { null },
    private val cleanupAttachments: suspend (List<MessageAttachment>) -> Unit = { },
    private val now: () -> Long = { System.currentTimeMillis() },
) {
    suspend fun createConversation(): Conversation {
        val identity = ConversationIdentity(id = generateId())
        val selection = try {
            defaultModelSelection()
        } catch (_: Exception) {
            null
        }
        val conversation = Conversation(
            identity = identity,
            modelSelection = selection,
            createdAtEpochMillis = now(),
            updatedAtEpochMillis = now(),
        )
        conversationRepository.save(conversation)
        return conversation
    }

    @Throws(ApplicationValidationError::class)
    suspend fun createConversationIn(workspaceId: WorkspaceIdentity): Conversation {
        val conversation = createConversation()
        val workspace = workspaceRepository.workspace(workspaceId)
        if (workspace != null) {
            val updatedWorkspace = workspace.adding(conversation.identity)
            try {
                workspaceRepository.save(updatedWorkspace)
            } catch (e: Exception) {
                conversationRepository.delete(conversation.identity)
                throw ApplicationValidationError.Invalid("Failed to add conversation to workspace: ${e.message}")
            }
        }
        return conversation
    }

    suspend fun getConversation(identity: ConversationIdentity): Conversation? =
        conversationRepository.conversation(identity)

    @Throws(ConversationStreamError::class, ApplicationValidationError::class)
    suspend fun selectModel(
        selection: ProviderModelSelection?,
        conversationIdentity: ConversationIdentity,
    ): Conversation {
        val conversation = conversationRepository.conversation(conversationIdentity)
            ?: throw ApplicationValidationError.Invalid("Conversation not found: ${conversationIdentity.id}")
        val updated = conversation.selectModel(selection)
        conversationRepository.save(updated)
        return updated
    }

    @Throws(ApplicationValidationError::class)
    suspend fun rename(
        value: String,
        conversationIdentity: ConversationIdentity,
    ): Conversation {
        val trimmed = value.trim()
        require(trimmed.isNotEmpty()) { throw ApplicationValidationError.Invalid("Title must not be empty") }
        val conversation = conversationRepository.conversation(conversationIdentity)
            ?: throw ApplicationValidationError.Invalid("Conversation not found: ${conversationIdentity.id}")
        val updated = conversation.rename(trimmed)
        conversationRepository.save(updated)
        return updated
    }

    suspend fun conversationsIn(workspaceId: WorkspaceIdentity): List<Conversation> {
        val workspace = workspaceRepository.workspace(workspaceId) ?: return emptyList()
        return workspace.conversationIdentities
            .mapNotNull { conversationRepository.conversation(it) }
            .sortedWith(compareByDescending<Conversation> { it.updatedAtEpochMillis }
                .thenByDescending { it.createdAtEpochMillis }
                .thenBy { it.identity.id })
    }

    @Throws(ApplicationValidationError::class)
    suspend fun delete(conversationIdentity: ConversationIdentity) {
        val conversation = conversationRepository.conversation(conversationIdentity)
            ?: throw ApplicationValidationError.Invalid("Conversation not found: ${conversationIdentity.id}")

        val allWorkspaces = workspaceRepository.allWorkspaces()
        for (workspace in allWorkspaces) {
            if (workspace.contains(conversation.identity)) {
                val updated = workspace.removing(conversation.identity)
                workspaceRepository.save(updated)
            }
        }

        conversationRepository.delete(conversation.identity)

        val allAttachments = conversation.history.flatMap { it.attachments }
        if (allAttachments.isNotEmpty()) {
            try {
                cleanupAttachments(allAttachments)
            } catch (_: Exception) { }
        }
    }

    private fun generateId(): String = java.util.UUID.randomUUID().toString()
}
