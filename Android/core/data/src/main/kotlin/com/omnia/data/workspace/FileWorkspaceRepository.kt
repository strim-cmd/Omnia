package com.omnia.data.workspace

import com.omnia.data.JsonDocumentStore
import com.omnia.domain.RepositoryError
import com.omnia.domain.Workspace
import com.omnia.domain.WorkspaceIdentity
import com.omnia.domain.WorkspaceRepository
import kotlinx.serialization.json.Json
import java.io.File

class FileWorkspaceRepository internal constructor(
    private val store: JsonDocumentStore,
) : WorkspaceRepository {

    constructor(directory: File) : this(JsonDocumentStore(directory))

    private val json = Json { encodeDefaults = true; prettyPrint = false }

    override suspend fun save(workspace: Workspace) {
        val dto = WorkspaceSerializer.toDTO(workspace)
        store.saveJson(json.encodeToString(WorkspaceDTOSchema.serializer(), dto), workspace.identity.id)
    }

    override suspend fun workspace(identity: WorkspaceIdentity): Workspace? {
        val text = store.loadJson(identity.id) ?: return null
        return try {
            val dto = json.decodeFromString(WorkspaceDTOSchema.serializer(), text)
            WorkspaceSerializer.fromDTO(dto)
        } catch (e: Exception) {
            if (e is RepositoryError) throw e
            throw RepositoryError.StorageUnavailable
        }
    }

    override suspend fun allWorkspaces(): List<Workspace> {
        val keys = store.allKeys()
        val workspaces = mutableListOf<Workspace>()
        for (key in keys) {
            val text = store.loadJsonRecoveringInvalid(key) ?: continue
            try {
                val dto = json.decodeFromString(WorkspaceDTOSchema.serializer(), text)
                workspaces.add(WorkspaceSerializer.fromDTO(dto))
            } catch (_: Exception) {
                continue
            }
        }
        return workspaces
    }

    override suspend fun delete(identity: WorkspaceIdentity) {
        store.delete(identity.id)
    }
}
