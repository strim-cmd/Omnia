package com.omnia.network.transport

/**
 * Provider-neutral HTTP request. Transport-agnostic: carries only URL,
 * method, headers, and optional body. No provider-specific knowledge.
 */
data class ProviderHTTPRequest(
    val url: String,
    val method: String,
    val headers: Map<String, String>,
    val body: ByteArray? = null,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is ProviderHTTPRequest) return false
        return url == other.url &&
            method == other.method &&
            headers == other.headers &&
            body.contentEquals(other.body)
    }

    override fun hashCode(): Int {
        var result = url.hashCode()
        result = 31 * result + method.hashCode()
        result = 31 * result + headers.hashCode()
        result = 31 * result + (body?.contentHashCode() ?: 0)
        return result
    }
}
