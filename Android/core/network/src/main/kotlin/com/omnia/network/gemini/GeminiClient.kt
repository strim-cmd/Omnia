package com.omnia.network.gemini

import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageProtocol
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
 * Gemini (Generative Language API) client over the transport seam.
 *
 * Constructs Generate Content requests for Gemini endpoints, decodes
 * responses, and delivers streaming events. Translates every failure
 * into [ProviderTransportError].
 *
 * Authentication is by reference: the credential is sent in the
 * `x-goog-api-key` header, never in URLs, logs, or request metadata.
 */
class GeminiClient(
    private val transport: ProviderTransport,
    private val credentialStorage: CredentialStorageProtocol,
) {
    private val json = Json { ignoreUnknownKeys = true }

    /**
     * Non-streaming Generate Content.
     */
    suspend fun generateContent(
        request: GeminiGenerateContentRequest,
        model: String,
        endpoint: String,
        credential: CredentialReference,
    ): GeminiGenerateContentResponse {
        val httpRequest = makeRequest(request, model, endpoint, credential, streaming = false)
        val response = transport.send(httpRequest)
        return try {
            json.decodeFromString<GeminiGenerateContentResponse>(String(response.body))
        } catch (_: Exception) {
            throw ProviderTransportError.invalidResponse
        }
    }

    /**
     * Streaming Generate Content. Returns a Flow of decoded responses.
     * Gemini sends no terminal marker — the stream ends when transport ends.
     */
    fun streamGenerateContent(
        request: GeminiGenerateContentRequest,
        model: String,
        endpoint: String,
        credential: CredentialReference,
    ): Flow<GeminiGenerateContentResponse> = flow {
        val httpRequest = makeRequest(request, model, endpoint, credential, streaming = true)
        val decoder = SSEDecoder()

        transport.stream(httpRequest).collect { chunk ->
            val events = decoder.append(chunk)
            for (event in events) {
                val payload = event.data.trim()
                if (payload.isEmpty()) continue
                try {
                    emit(json.decodeFromString<GeminiGenerateContentResponse>(payload))
                } catch (_: Exception) {
                    throw ProviderTransportError.invalidResponse
                }
            }
        }

        for (event in decoder.finish()) {
            val payload = event.data.trim()
            if (payload.isEmpty()) continue
            try {
                emit(json.decodeFromString<GeminiGenerateContentResponse>(payload))
            } catch (_: Exception) {
                throw ProviderTransportError.invalidResponse
            }
        }
    }.flowOn(Dispatchers.IO)

    /**
     * GET /models — returns model ID list.
     * Strips the `models/` prefix. Model-list records prove identity only.
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
                headers = mapOf("x-goog-api-key" to apiKey),
            )
        }
        val response = transport.send(httpRequest)
        val decoded = try {
            json.decodeFromString<GeminiModelsResponse>(String(response.body))
        } catch (_: Exception) {
            throw ProviderTransportError.invalidResponse
        }
        return GeminiMapping.modelIds(decoded)
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
        request: GeminiGenerateContentRequest,
        model: String,
        endpoint: String,
        credential: CredentialReference,
        streaming: Boolean,
    ): ProviderHTTPRequest {
        val stored = credentialStorage.credential(credential)
        return stored.withValue { apiKey ->
            val body = try {
                json.encodeToString(GeminiGenerateContentRequest.serializer(), request)
                    .toByteArray(Charsets.UTF_8)
            } catch (_: Exception) {
                throw ProviderTransportError.invalidRequest
            }
            ProviderHTTPRequest(
                url = GeminiMapping.buildEndpointUrl(endpoint, model, streaming),
                method = "POST",
                headers = mapOf(
                    "Content-Type" to "application/json",
                    "x-goog-api-key" to apiKey,
                ),
                body = body,
            )
        }
    }
}
