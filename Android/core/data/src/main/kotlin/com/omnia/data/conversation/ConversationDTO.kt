package com.omnia.data.conversation

import com.omnia.domain.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*

@Serializable
internal data class MessageDTOSchema(
    val schemaVersion: Int = 1,
    val role: String,
    val content: String,
    val attachments: List<MessageAttachmentSchema>? = null,
)

@Serializable
internal data class MessageAttachmentSchema(
    val identity: String,
    val fileName: String,
    val mediaType: String,
    val kind: String,
    val byteCount: Int,
    val storageKey: String,
)

@Serializable
internal data class ConversationStreamingStateSchema(
    val state: String,
    val partialContent: String? = null,
)

@Serializable
internal data class ProviderModelSelectionSchema(
    val provider: String,
    val model: String,
)

@Serializable
internal data class ConversationDTOSchema(
    val schemaVersion: Int = 1,
    val identity: String,
    val history: List<MessageDTOSchema> = emptyList(),
    val streamingState: ConversationStreamingStateSchema = ConversationStreamingStateSchema("idle"),
    val modelSelection: ProviderModelSelectionSchema? = null,
    val title: String? = null,
    val titleOrigin: String? = null,
    val createdAtEpochMillis: Long = 0L,
    val updatedAtEpochMillis: Long = 0L,
)

internal object ConversationSerializer {

    fun toDTO(conversation: Conversation): ConversationDTOSchema {
        return ConversationDTOSchema(
            identity = conversation.identity.id,
            history = conversation.history.map { msg ->
                MessageDTOSchema(
                    role = msg.role.serializedName,
                    content = msg.content,
                    attachments = msg.attachments.takeIf { it.isNotEmpty() }?.map { att ->
                        MessageAttachmentSchema(
                            identity = att.identity.id,
                            fileName = att.fileName,
                            mediaType = att.mediaType,
                            kind = att.kind.serializedName,
                            byteCount = att.byteCount,
                            storageKey = att.storageKey,
                        )
                    }
                )
            },
            streamingState = streamingStateToDTO(conversation.streamingState),
            modelSelection = conversation.modelSelection?.let {
                ProviderModelSelectionSchema(provider = it.provider.id, model = it.model.name)
            },
            title = conversation.title,
            titleOrigin = conversation.titleOrigin.serializedName,
            createdAtEpochMillis = conversation.createdAtEpochMillis,
            updatedAtEpochMillis = conversation.updatedAtEpochMillis,
        )
    }

    fun fromDTO(dto: ConversationDTOSchema): Conversation {
        val identity = ConversationIdentity(dto.identity)
        val titleOrigin = dto.titleOrigin?.toConversationTitleOrigin()
            ?: ConversationTitleOrigin.automatic
        val createdAt = dto.createdAtEpochMillis
        val updatedAt = dto.updatedAtEpochMillis
        require(updatedAt >= createdAt) { "updatedAt must be >= createdAt" }

        val modelSelection = dto.modelSelection?.let {
            ProviderModelSelection(
                provider = ProviderIdentity(it.provider),
                model = ModelReference(it.model),
            )
        }

        var conversation = Conversation(
            identity = identity,
            modelSelection = modelSelection,
            title = dto.title,
            titleOrigin = titleOrigin,
            createdAtEpochMillis = createdAt,
            updatedAtEpochMillis = updatedAt,
        )

        for (msgDTO in dto.history) {
            val role = msgDTO.role.toMessageRole()
                ?: throw RepositoryError.StorageUnavailable
            val attachments = msgDTO.attachments?.map { att ->
                MessageAttachment(
                    identity = AttachmentIdentity(att.identity),
                    fileName = att.fileName,
                    mediaType = att.mediaType,
                    kind = att.kind.toAttachmentKind(),
                    byteCount = att.byteCount,
                    storageKey = att.storageKey,
                )
            } ?: emptyList()
            conversation = conversation.append(
                Message(role = role, content = msgDTO.content, attachments = attachments),
                timestampMillis = 0L,
            )
        }

        restoreStreamingState(dto.streamingState, conversation)?.let {
            conversation = it
        }

        return conversation
    }

    private fun streamingStateToDTO(state: ConversationStreamingState): ConversationStreamingStateSchema {
        return when (state) {
            is ConversationStreamingState.Idle ->
                ConversationStreamingStateSchema(state = "idle")
            is ConversationStreamingState.Streaming ->
                ConversationStreamingStateSchema(state = "streaming", partialContent = state.content)
            is ConversationStreamingState.Interrupted ->
                ConversationStreamingStateSchema(state = "interrupted", partialContent = state.content)
        }
    }

    private fun restoreStreamingState(
        dto: ConversationStreamingStateSchema,
        conversation: Conversation,
    ): Conversation? {
        return when (dto.state) {
            "idle" -> null
            "streaming" -> {
                val partial = dto.partialContent ?: ""
                var c = conversation.beginStreaming()
                if (partial.isNotEmpty()) c = c.appendPartial(partial)
                c
            }
            "interrupted" -> {
                val partial = dto.partialContent ?: ""
                var c = conversation.beginStreaming()
                if (partial.isNotEmpty()) c = c.appendPartial(partial)
                c.interruptStreaming()
            }
            else -> throw RepositoryError.StorageUnavailable
        }
    }
}

private val MessageRole.serializedName: String
    get() = when (this) {
        MessageRole.system -> "system"
        MessageRole.user -> "user"
        MessageRole.assistant -> "assistant"
    }

private fun String.toMessageRole(): MessageRole? = when (this) {
    "system" -> MessageRole.system
    "user" -> MessageRole.user
    "assistant" -> MessageRole.assistant
    else -> null
}

private val AttachmentKind.serializedName: String
    get() = when (this) {
        AttachmentKind.image -> "image"
        AttachmentKind.pdf -> "pdf"
        AttachmentKind.plainText -> "plainText"
    }

private fun String.toAttachmentKind(): AttachmentKind = when (this) {
    "image" -> AttachmentKind.image
    "pdf" -> AttachmentKind.pdf
    "plainText" -> AttachmentKind.plainText
    else -> AttachmentKind.plainText
}

private val ConversationTitleOrigin.serializedName: String
    get() = when (this) {
        ConversationTitleOrigin.automatic -> "automatic"
        ConversationTitleOrigin.user -> "user"
    }

private fun String.toConversationTitleOrigin(): ConversationTitleOrigin = when (this) {
    "automatic" -> ConversationTitleOrigin.automatic
    "user" -> ConversationTitleOrigin.user
    else -> ConversationTitleOrigin.automatic
}
