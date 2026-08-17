package com.omnia.domain

import com.omnia.common.SemanticVersion

interface ConversationRepository {
    suspend fun save(conversation: Conversation)
    suspend fun conversation(identity: ConversationIdentity): Conversation?
    suspend fun delete(identity: ConversationIdentity)
}

interface ProviderRepository {
    suspend fun save(provider: Provider)
    suspend fun provider(identity: ProviderIdentity): Provider?
    suspend fun allProviders(): List<Provider>
    suspend fun delete(identity: ProviderIdentity)
}

interface WorkspaceRepository {
    suspend fun save(workspace: Workspace)
    suspend fun workspace(identity: WorkspaceIdentity): Workspace?
    suspend fun allWorkspaces(): List<Workspace>
    suspend fun delete(identity: WorkspaceIdentity)
}

sealed class RepositoryError(message: String, throwable: Throwable? = null) : Exception(message, throwable) {
    data object StorageUnavailable : RepositoryError("Storage is unavailable")

    data class CorruptedRecord(val identity: String, val throwable: Throwable? = null) :
        RepositoryError("Corrupted record: $identity", throwable)
}

enum class ProviderConnectionTestError {
    invalidCredential,
    unreachable,
    invalidEndpoint,
    modelUnavailable,
    rateLimited,
    timedOut,
    serverFailure,
    invalidResponse,
}

enum class ModelCatalogError {
    unsupported,
    unauthorized,
    unreachable,
    rateLimited,
    timedOut,
    serverFailure,
    invalidResponse,
}
