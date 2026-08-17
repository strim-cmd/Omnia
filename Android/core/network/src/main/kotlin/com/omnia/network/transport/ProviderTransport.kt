package com.omnia.network.transport

import kotlinx.coroutines.flow.Flow

/**
 * Provider-neutral HTTP transport. Owns HTTP execution, response status
 * validation, streaming byte delivery, cancellation, and timeout
 * categorization.
 *
 * Must NOT understand: Gemini DTOs, OpenAI DTOs, ModelReference,
 * conversation history, or Omnia capabilities.
 */
interface ProviderTransport {
    /**
     * Send a request and return the full response body.
     * Validates status codes and maps HTTP errors to [ProviderTransportError].
     */
    suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse

    /**
     * Stream a response body as raw byte chunks.
     * Each emission is a chunk of the response body.
     * Cancellation of the Flow collection cancels the underlying HTTP call.
     */
    fun stream(request: ProviderHTTPRequest): Flow<ByteArray>
}
