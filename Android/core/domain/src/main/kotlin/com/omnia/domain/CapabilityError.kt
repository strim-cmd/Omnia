package com.omnia.domain

/**
 * Normalized capability errors. Carries no provider, transport, or decoding
 * detail (ARC-004). Designed so later Infrastructure can map
 * OpenAI/Gemini/network errors into these without leaking specifics.
 */
sealed class CapabilityError(
    message: String,
    cause: Throwable? = null,
) : Exception(message, cause) {

    data object ProviderUnavailable : CapabilityError("No provider is available for the requested capability")

    data object NetworkUnavailable : CapabilityError("Network is unavailable")

    data object Unauthorized : CapabilityError("Invalid or missing credential")

    data object InvalidEndpoint : CapabilityError("The provider endpoint is invalid")

    data object TimedOut : CapabilityError("The request timed out")

    data object RateLimited : CapabilityError("Rate limit exceeded")

    data object ServerFailure : CapabilityError("Server returned an error")

    data class ModelUnavailable(val model: ModelReference) :
        CapabilityError("Model '${model.name}' is unavailable")

    data object InvalidRequest : CapabilityError("The request is invalid or malformed")

    data object InvalidResponse : CapabilityError("The provider response is invalid")

    data class StreamingInterrupted(val partialContent: String) :
        CapabilityError("Streaming was interrupted with ${partialContent.length} chars of partial content")
}
