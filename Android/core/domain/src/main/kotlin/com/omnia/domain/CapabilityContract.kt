package com.omnia.domain

/**
 * Contract interfaces for capability execution. Infrastructure implements
 * these; Application orchestrates through them; Domain defines them.
 *
 * In v1.0.0 only [StreamingContract] is fully realized.
 * [TextGenerationContract] and [ConversationContract] are extension points.
 */
interface CapabilityContract

interface TextGenerationContract : CapabilityContract {
    suspend fun generateText(request: TextGenerationRequest): TextGenerationResponse
}

interface ConversationContract : CapabilityContract {
    suspend fun sendMessage(request: ConversationRequest): ConversationResponse
}

interface StreamingContract : CapabilityContract {
    /**
     * Opens a streaming generation. Returns a [kotlinx.coroutines.flow.Flow]
     * of [StreamingUpdate] events. The caller must consume the flow within a
     * coroutine scope; cancellation propagates through structured concurrency.
     */
    suspend fun stream(request: StreamingRequest): kotlinx.coroutines.flow.Flow<StreamingUpdate>
}
