package com.omnia.domain

/**
 * Title origin — tracks whether the title was set automatically or by the user.
 * User titles must never be overwritten by auto-title behavior.
 */
enum class ConversationTitleOrigin {
    automatic,
    user,
}

/**
 * Streaming state of a conversation. Part of the Conversation aggregate.
 */
sealed class ConversationStreamingState {
    data object Idle : ConversationStreamingState()
    data class Streaming(val content: String) : ConversationStreamingState()
    data class Interrupted(val content: String) : ConversationStreamingState()

    val partialContent: String?
        get() = when (this) {
            is Streaming -> content
            is Interrupted -> content
            is Idle -> null
        }

    val isStreaming: Boolean get() = this is Streaming
}

/**
 * Conversation aggregate — owns message history, streaming state, model
 * selection, and title. All mutations go through this aggregate.
 *
 * Key invariants:
 * - Message history is only ever appended to, never rewritten.
 * - [beginStreaming] from Interrupted resumes with preserved partial content.
 * - [completeStreaming] appends an assistant Message with the accumulated
 *   partial content, then resets to Idle.
 * - [interruptStreaming] preserves partial content as incomplete.
 * - Auto-title is derived from the first user message, truncated to 80 chars.
 * - User rename truncates to 160 chars. User title always wins.
 * - [mergeMetadata] from a newer snapshot preserves user titles.
 * - Streaming state: [selectModel] and [append] reject when streaming.
 */
data class Conversation(
    val identity: ConversationIdentity,
    val history: List<Message> = emptyList(),
    val streamingState: ConversationStreamingState = ConversationStreamingState.Idle,
    val modelSelection: ProviderModelSelection? = null,
    val title: String? = null,
    val titleOrigin: ConversationTitleOrigin = ConversationTitleOrigin.automatic,
    val createdAtEpochMillis: Long = 0L,
    val updatedAtEpochMillis: Long = 0L,
) {
    val partialContent: String? get() = streamingState.partialContent
    val isStreaming: Boolean get() = streamingState.isStreaming

    /** True when the conversation has been completed at least once (has assistant messages). */
    val hasCompletedGeneration: Boolean
        get() = history.any { it.role == MessageRole.assistant }

    /** True when the conversation is in an interrupted state ready for resume. */
    val isInterrupted: Boolean
        get() = streamingState is ConversationStreamingState.Interrupted

    @Throws(ConversationStreamError::class)
    fun selectModel(selection: ProviderModelSelection?): Conversation {
        if (streamingState is ConversationStreamingState.Streaming) {
            throw ConversationStreamError.StreamInProgress
        }
        return copy(modelSelection = selection)
    }

    @Throws(ConversationMetadataError::class)
    fun rename(value: String): Conversation {
        val normalized = normalizeTitle(value)
        require(normalized.isNotEmpty()) { "Title must not be empty" }
        val truncated = if (normalized.length > MAX_USER_TITLE_LENGTH) {
            normalized.substring(0, MAX_USER_TITLE_LENGTH)
        } else {
            normalized
        }
        return copy(
            title = truncated,
            titleOrigin = ConversationTitleOrigin.user,
        )
    }

    /**
     * Merges metadata from a newer repository snapshot into this
     * (older in-memory) snapshot. This is called after streaming completes
     * to preserve concurrent user renames.
     *
     * Rules (matching Swift OmniaDomain):
     * - If [from] (newer) has a user title → take it (user renamed during generation).
     * - Else if this (older) has an automatic title AND [from] has any title → take from's.
     * - Else keep this snapshot's title.
     * - UpdatedAt is always the max of both.
     */
    fun mergeMetadata(from: Conversation): Conversation {
        if (this.identity != from.identity) return this
        val mergedTitle: String?
        val mergedOrigin: ConversationTitleOrigin
        when {
            from.titleOrigin == ConversationTitleOrigin.user -> {
                mergedTitle = from.title
                mergedOrigin = ConversationTitleOrigin.user
            }
            this.titleOrigin != ConversationTitleOrigin.user && from.title != null -> {
                mergedTitle = from.title
                mergedOrigin = this.titleOrigin
            }
            else -> {
                mergedTitle = this.title
                mergedOrigin = this.titleOrigin
            }
        }
        return copy(
            title = mergedTitle,
            titleOrigin = mergedOrigin,
            updatedAtEpochMillis = maxOf(this.updatedAtEpochMillis, from.updatedAtEpochMillis),
        )
    }

    /**
     * Generates an automatic title from the first user message content,
     * truncated to 80 characters.
     */
    fun autoTitle(): String? {
        val firstUserMessage = history.firstOrNull { it.role == MessageRole.user } ?: return null
        val raw = firstUserMessage.content.trim()
        if (raw.isEmpty()) return null
        return if (raw.length > MAX_AUTO_TITLE_LENGTH) {
            raw.substring(0, MAX_AUTO_TITLE_LENGTH)
        } else {
            raw
        }
    }

    @Throws(ConversationStreamError::class)
    fun append(message: Message, timestampMillis: Long = 0L): Conversation {
        if (streamingState is ConversationStreamingState.Streaming) {
            throw ConversationStreamError.StreamInProgress
        }
        var result = copy(
            history = history + message,
            updatedAtEpochMillis = timestampMillis,
        )
        // Auto-title from first user message (matching Swift OmniaDomain)
        if (titleOrigin == ConversationTitleOrigin.automatic && title == null && message.role == MessageRole.user) {
            val contentTitle = normalizeTitle(message.content)
            val attachmentTitle = message.attachments.firstOrNull()?.let { normalizeTitle(it.fileName) } ?: ""
            val automatic = if (contentTitle.isEmpty()) attachmentTitle else contentTitle
            if (automatic.isNotEmpty()) {
                result = result.copy(title = automatic.take(MAX_AUTO_TITLE_LENGTH))
            }
        }
        return result
    }

    @Throws(ConversationStreamError::class)
    fun beginStreaming(): Conversation {
        return when (streamingState) {
            is ConversationStreamingState.Idle -> copy(
                streamingState = ConversationStreamingState.Streaming(content = ""),
            )
            is ConversationStreamingState.Interrupted -> copy(
                streamingState = ConversationStreamingState.Streaming(
                    content = streamingState.content,
                ),
            )
            is ConversationStreamingState.Streaming -> throw ConversationStreamError.StreamInProgress
        }
    }

    @Throws(ConversationStreamError::class)
    fun appendPartial(content: String): Conversation {
        val current = streamingState
        if (current !is ConversationStreamingState.Streaming) {
            throw ConversationStreamError.NotStreaming
        }
        return copy(
            streamingState = ConversationStreamingState.Streaming(
                content = current.content + content,
            ),
        )
    }

    @Throws(ConversationStreamError::class)
    fun completeStreaming(timestampMillis: Long = 0L): Conversation {
        val current = streamingState
        if (current !is ConversationStreamingState.Streaming) {
            throw ConversationStreamError.NotStreaming
        }
        val assistantMessage = Message(
            role = MessageRole.assistant,
            content = current.content,
        )
        return copy(
            history = history + assistantMessage,
            streamingState = ConversationStreamingState.Idle,
            updatedAtEpochMillis = timestampMillis,
        )
    }

    @Throws(ConversationStreamError::class)
    fun interruptStreaming(): Conversation {
        val current = streamingState
        if (current !is ConversationStreamingState.Streaming) {
            throw ConversationStreamError.NotStreaming
        }
        return copy(
            streamingState = ConversationStreamingState.Interrupted(
                content = current.content,
            ),
        )
    }

    companion object {
        const val MAX_AUTO_TITLE_LENGTH = 80
        const val MAX_USER_TITLE_LENGTH = 160

        /**
         * Collapses whitespace into single spaces and trims (matching Swift
         * OmniaDomain normalizedTitle). Used for auto-title derivation and
         * user rename normalization.
         */
        fun normalizeTitle(value: String): String {
            return value.split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ").trim()
        }
    }
}

sealed class ConversationStreamError(message: String) : Exception(message) {
    data object StreamInProgress : ConversationStreamError("A stream is already in progress")
    data object NotStreaming : ConversationStreamError("No stream is in progress")
}

sealed class ConversationMetadataError(message: String) : Exception(message) {
    data object InvalidTitle : ConversationMetadataError("The title is invalid")
}
