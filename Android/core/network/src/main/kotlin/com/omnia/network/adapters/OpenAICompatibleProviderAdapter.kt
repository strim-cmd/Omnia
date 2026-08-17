package com.omnia.network.adapters

import com.omnia.domain.ConversationContract
import com.omnia.domain.ConversationRequest
import com.omnia.domain.ConversationResponse
import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageProtocol
import com.omnia.domain.Message
import com.omnia.domain.StreamingContract
import com.omnia.domain.StreamingRequest
import com.omnia.domain.StreamingUpdate
import com.omnia.domain.TextGenerationContract
import com.omnia.domain.TextGenerationRequest
import com.omnia.domain.TextGenerationResponse
import com.omnia.network.mapping.ProviderErrorMapping
import com.omnia.network.openai.OpenAICompatibleClient
import com.omnia.network.openai.OpenAIMapping
import com.omnia.network.transport.ProviderTransport
import com.omnia.network.transport.ProviderTransportError
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * OpenAI-compatible provider adapter. Wires the transport seam and credential
 * storage to the Domain capability contracts.
 *
 * The adapter owns no business logic and no application state (ARC-004 Adapter
 * Model). Transport or decoding failures are translated into the Domain
 * capability errors; credential-resolution failures surface as
 * `CredentialStorageError` (DES-009 §3.7).
 *
 * Bound to one endpoint and credential reference at creation time.
 */
class OpenAICompatibleProviderAdapter(
    transport: ProviderTransport,
    credentialStorage: CredentialStorageProtocol,
    private val endpoint: String,
    private val credential: CredentialReference,
) : TextGenerationContract, ConversationContract, StreamingContract {

    private val client = OpenAICompatibleClient(transport, credentialStorage)

    override suspend fun generateText(request: TextGenerationRequest): TextGenerationResponse {
        val wireRequest = OpenAIMapping.textGenerationRequest(request.model.name, request.prompt)
        val response = try {
            client.chatCompletions(wireRequest, endpoint, credential)
        } catch (e: ProviderTransportError) {
            throw ProviderErrorMapping.capabilityError(e)
        }
        return TextGenerationResponse(text = OpenAIMapping.textResponse(response))
    }

    override suspend fun sendMessage(request: ConversationRequest): ConversationResponse {
        val wireRequest = OpenAIMapping.conversationRequest(
            request.model.name, request.history, request.resolvedAttachments
        )
        val response = try {
            client.chatCompletions(wireRequest, endpoint, credential)
        } catch (e: ProviderTransportError) {
            throw ProviderErrorMapping.capabilityError(e)
        }
        return ConversationResponse(message = OpenAIMapping.conversationResponseMessage(response))
    }

    override suspend fun stream(request: StreamingRequest): Flow<StreamingUpdate> {
        val wireRequest = OpenAIMapping.streamingRequest(
            request.model.name, request.history, request.resolvedAttachments
        )
        val chunkStream = try {
            client.streamChatCompletions(wireRequest, endpoint, credential)
        } catch (e: ProviderTransportError) {
            throw ProviderErrorMapping.capabilityError(e)
        }

        val identity = request.identity
        return flow {
            var partialContent = ""
            try {
                chunkStream.collect { chunk ->
                    val update = OpenAIMapping.streamingUpdate(chunk, identity) ?: return@collect
                    partialContent += update.content
                    emit(update)
                }
                val message = Message(
                    role = com.omnia.domain.MessageRole.assistant,
                    content = partialContent
                )
                emit(StreamingUpdate.Completion(identity = identity, message = message))
            } catch (e: ProviderTransportError) {
                if (partialContent.isEmpty()) {
                    throw ProviderErrorMapping.capabilityError(e)
                }
                throw com.omnia.domain.CapabilityError.StreamingInterrupted(partialContent)
            } catch (e: com.omnia.domain.CapabilityError) {
                throw e
            } catch (_: Exception) {
                if (partialContent.isNotEmpty()) {
                    throw com.omnia.domain.CapabilityError.StreamingInterrupted(partialContent)
                }
            }
        }
    }

    suspend fun isAvailable(): Boolean = client.probeAvailability(endpoint, credential)
}
