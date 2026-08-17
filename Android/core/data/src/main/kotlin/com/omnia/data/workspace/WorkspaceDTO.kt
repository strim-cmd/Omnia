package com.omnia.data.workspace

import com.omnia.domain.Workspace
import com.omnia.domain.WorkspaceIdentity
import com.omnia.domain.ConversationIdentity
import com.omnia.domain.ProviderIdentity
import kotlinx.serialization.Serializable

@Serializable
internal data class WorkspaceDTOSchema(
    val schemaVersion: Int = 1,
    val identity: String,
    val name: String,
    val conversationIdentities: List<String> = emptyList(),
    val providerIdentities: List<String> = emptyList(),
)

internal object WorkspaceSerializer {
    fun toDTO(workspace: Workspace): WorkspaceDTOSchema {
        return WorkspaceDTOSchema(
            identity = workspace.identity.id,
            name = workspace.name,
            conversationIdentities = workspace.conversationIdentities
                .map { it.id }.sorted(),
            providerIdentities = workspace.providerIdentities
                .map { it.id }.sorted(),
        )
    }

    fun fromDTO(dto: WorkspaceDTOSchema): Workspace {
        return Workspace(
            identity = WorkspaceIdentity(dto.identity),
            name = dto.name,
            conversationIdentities = dto.conversationIdentities
                .map { ConversationIdentity(it) }.toSet(),
            providerIdentities = dto.providerIdentities
                .map { ProviderIdentity(it) }.toSet(),
        )
    }
}
