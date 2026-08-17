package com.omnia.network.openai

import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageProtocol
import com.omnia.domain.ModelReference
import com.omnia.network.sse.SSEDecoder
import com.omnia.network.transport.ProviderHTTPRequest
import com.omnia.network.transport.ProviderTransport
import com.omnia.network.transport.ProviderTransportError
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.serialization.json.Json

/**
 * OpenAI-compatible client over the transport seam.
 *
 * Constructs chat-completions requests for OpenAI-compatible endpoints,
 * decodes responses, and delivers streaming content. Translates every
 * failure into [ProviderTransportError].
 *
 * Authentication is by reference: the client resolves the credential
 * through credential storage and builds the Authorization header inside
 * the credential's scoped access, so the secret never enters logs or
 * request metadata beyond the Authorization header.
 */
class OpenAICompatibleClient(
    private val transport: ProviderTransport,
    private val credentialStorage: CredentialStorageProtocol,
) {
    private val json = Json { ignoreUnknownKeys = true }

    /**
     * Non-streaming chat completions.
     */
    suspend fun chatCompletions(
        request: OpenAIChatCompletionRequest,
        endpoint: String,
        credential: CredentialReference,
    ): OpenAIChatCompletionResponse {
        val httpRequest = makeRequest(request, endpoint, credential, streaming = false)
        val response = transport.send(httpRequest)
        return try {
            json.decodeFromString<OpenAIChatCompletionResponse>(String(response.body))
        } catch (_: Exception) {
            throw ProviderTransportError.invalidResponse
        }
    }

    /**
     * Streaming chat completions. Returns a Flow of decoded chunks.
     */
    fun streamChatCompletions(
        request: OpenAIChatCompletionRequest,
        endpoint: String,
        credential: CredentialReference,
    ): Flow<OpenAIChatCompletionChunk> = flow {
        val httpRequest = makeRequest(request, endpoint, credential, streaming = true)
        val decoder = SSEDecoder()

        transport.stream(httpRequest).collect { chunk ->
            val events = decoder.append(chunk)
            for (event in events) {
                val trimmed = event.data.trim()
                if (trimmed == "[DONE]") return@collect
                try {
                    val decoded = json.decodeFromString<OpenAIChatCompletionChunk>(event.data)
                    emit(decoded)
                } catch (_: Exception) {
                    throw ProviderTransportError.invalidResponse
                }
            }
        }

        for (event in decoder.finish()) {
            val trimmed = event.data.trim()
            if (trimmed == "[DONE]") break
            try {
                val decoded = json.decodeFromString<OpenAIChatCompletionChunk>(event.data)
                emit(decoded)
            } catch (_: Exception) {
                throw ProviderTransportError.invalidResponse
            }
        }
    }.flowOn(Dispatchers.IO)

    /**
     * GET /models — returns model ID list.
     * Model-list records prove identity only; no inferred capabilities.
     */
    suspend fun models(
        endpoint: String,
        credential: CredentialReference,
    ): List<String> {
        val stored = credentialStorage.credential(credential)
        val httpRequest = stored.withValue { apiKey ->
            ProviderHTTPRequest(
                url = "${endpoint.trimEnd('/')}/models",
                method = "GET",
                headers = mapOf("Authorization" to "Bearer $apiKey"),
            )
        }
        val response = transport.send(httpRequest)
        val decoded = try {
            json.decodeFromString<OpenAIModelListResponse>(String(response.body))
        } catch (_: Exception) {
            throw ProviderTransportError.invalidResponse
        }
        return OpenAIMapping.modelIds(decoded)
    }

    /**
     * Probes whether the endpoint is reachable and authenticated.
     */
    suspend fun probeAvailability(
        endpoint: String,
        credential: CredentialReference,
    ): Boolean {
        return try {
            models(endpoint, credential)
            true
        } catch (_: Exception) {
            false
        }
    }

    private suspend fun makeRequest(
        request: OpenAIChatCompletionRequest,
        endpoint: String,
        credential: CredentialReference,
        streaming: Boolean,
    ): ProviderHTTPRequest {
        val stored = credentialStorage.credential(credential)
        return stored.withValue { apiKey ->
            val body = try {
                json.encodeToString(
                    OpenAIChatCompletionRequest.serializer(),
                    request.copy(stream = streaming)
                ).toByteArray(Charsets.UTF_8)
            } catch (_: Exception) {
                throw ProviderTransportError.invalidRequest
            }
            ProviderHTTPRequest(
                url = "${endpoint.trimEnd('/')}/chat/completions",
                method = "POST",
                headers = mapOf(
                    "Content-Type" to "application/json",
                    "Authorization" to "Bearer $apiKey",
                ),
                body = body,
            )
        }
    }
}
