package com.omnia.network.transport

/**
 * Transport-level error taxonomy. Never leaks OkHttp internals,
 * IOException, SocketTimeoutException, or JSON decoding errors.
 *
 * Maps into Domain/Application error categories at the infrastructure
 * boundary via ProviderErrorMapping.
 */
sealed class ProviderTransportError(message: String, cause: Throwable? = null) :
    Exception(message, cause) {

    data object invalidRequest : ProviderTransportError("Invalid request")
    data object invalidResponse : ProviderTransportError("Invalid response")
    data class httpStatus(val code: Int) :
        ProviderTransportError("HTTP status $code")
    data object networkFailure : ProviderTransportError("Network failure")
    data object timedOut : ProviderTransportError("Request timed out")
}
