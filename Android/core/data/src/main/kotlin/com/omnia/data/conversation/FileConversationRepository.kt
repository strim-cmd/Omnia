package com.omnia.data.conversation

import com.omnia.data.JsonDocumentStore
import com.omnia.domain.Conversation
import com.omnia.domain.ConversationRepository
import com.omnia.domain.ConversationIdentity
import com.omnia.domain.RepositoryError
import kotlinx.serialization.json.Json
import java.io.File

class FileConversationRepository internal constructor(
    private val store: JsonDocumentStore,
) : ConversationRepository {

    constructor(directory: File) : this(JsonDocumentStore(directory))

    private val json = Json { encodeDefaults = true; prettyPrint = false }

    override suspend fun save(conversation: Conversation) {
        val dto = ConversationSerializer.toDTO(conversation)
        store.saveJson(json.encodeToString(ConversationDTOSchema.serializer(), dto), conversation.identity.id)
    }

    override suspend fun conversation(identity: ConversationIdentity): Conversation? {
        val text = store.loadJson(identity.id) ?: return null
        return try {
            val dto = json.decodeFromString(ConversationDTOSchema.serializer(), text)
            ConversationSerializer.fromDTO(dto)
        } catch (e: Exception) {
            if (e is RepositoryError) throw e
            throw RepositoryError.StorageUnavailable
        }
    }

    override suspend fun delete(identity: ConversationIdentity) {
        store.delete(identity.id)
    }

    suspend fun allConversations(): List<Conversation> {
        val keys = store.allKeys()
        val conversations = mutableListOf<Conversation>()
        for (key in keys) {
            val text = store.loadJsonRecoveringInvalid(key) ?: continue
            try {
                val dto = json.decodeFromString(ConversationDTOSchema.serializer(), text)
                conversations.add(ConversationSerializer.fromDTO(dto))
            } catch (_: Exception) {
                continue
            }
        }
        return conversations
    }

    suspend fun removeAll() {
        store.deleteAll()
    }
}
