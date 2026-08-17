package com.omnia.domain

/**
 * Streaming state machine. Records the lifecycle of a single generation
 * request independent of the Conversation aggregate.
 *
 * Transitions: Active -> Active (appending) / Complete (terminal) / Interrupted (terminal).
 * Complete and Interrupted are terminal — no transition leaves them.
 */
sealed class StreamingState {
    data class Active(val content: String) : StreamingState()
    data class Complete(val message: Message) : StreamingState()
    data class Interrupted(val content: String) : StreamingState()

    val partialContent: String?
        get() = when (this) {
            is Active -> content
            is Interrupted -> content
            is Complete -> null
        }

    val isTerminal: Boolean
        get() = this is Complete || this is Interrupted

    @Throws(StreamingStateError::class)
    fun appending(content: String): StreamingState {
        if (this !is Active) throw StreamingStateError.NotActive
        return copy(content = this.content + content)
    }

    @Throws(StreamingStateError::class)
    fun completing(): StreamingState {
        if (this !is Active) throw StreamingStateError.NotActive
        return Complete(message = Message(role = MessageRole.assistant, content = this.content))
    }

    @Throws(StreamingStateError::class)
    fun interrupting(): StreamingState {
        if (this !is Active) throw StreamingStateError.NotActive
        return Interrupted(content = this.content)
    }
}

sealed class StreamingStateError(message: String) : Exception(message) {
    data object NotActive : StreamingStateError("Streaming state is not active")
}

/**
 * Streaming update events correlated by [CapabilityRequestIdentity].
 */
sealed class StreamingUpdate {
    data class ContentDelta(
        val identity: CapabilityRequestIdentity,
        val content: String,
    ) : StreamingUpdate()

    data class Completion(
        val identity: CapabilityRequestIdentity,
        val message: Message,
    ) : StreamingUpdate()

    data class Interruption(
        val identity: CapabilityRequestIdentity,
        val partialContent: String,
    ) : StreamingUpdate()
}

/**
 * Request to open a streaming generation.
 */
data class StreamingRequest(
    val identity: CapabilityRequestIdentity,
    val history: List<Message>,
    val model: ModelReference,
    val provider: ProviderIdentity? = null,
    val resolvedAttachments: List<ResolvedAttachment> = emptyList(),
)

/**
 * Request for a non-streaming conversation exchange.
 */
data class ConversationRequest(
    val identity: CapabilityRequestIdentity,
    val history: List<Message>,
    val model: ModelReference,
    val provider: ProviderIdentity? = null,
    val resolvedAttachments: List<ResolvedAttachment> = emptyList(),
)

data class ConversationResponse(val message: Message)

/**
 * Request for simple text generation (extension point).
 */
data class TextGenerationRequest(
    val identity: CapabilityRequestIdentity,
    val prompt: String,
    val model: ModelReference,
    val provider: ProviderIdentity? = null,
)

data class TextGenerationResponse(val text: String)
