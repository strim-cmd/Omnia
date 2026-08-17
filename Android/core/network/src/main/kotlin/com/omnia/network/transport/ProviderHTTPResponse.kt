package com.omnia.network.transport

/**
 * Provider-neutral HTTP response. Carries only the response body.
 * Status validation is performed inside the transport boundary.
 */
data class ProviderHTTPResponse(
    val body: ByteArray,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is ProviderHTTPResponse) return false
        return body.contentEquals(other.body)
    }

    override fun hashCode(): Int = body.contentHashCode()
}
