package com.omnia.network.transport

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import okhttp3.ResponseBody
import okio.Buffer
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * OkHttp-backed implementation of [ProviderTransport].
 *
 * Timeout policy:
 * - Connection timeout: 15 seconds
 * - Ordinary request timeout: 120 seconds
 * - Streaming: no read timeout (long-lived connections for SSE)
 */
class OkHttpProviderTransport(
    private val client: OkHttpClient = defaultClient(),
) : ProviderTransport {

    override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
        val okRequest = request.toOkHttpRequest()
        val response = callAsync(okRequest)
        response.use { resp ->
            val body = resp.body?.bytes() ?: ByteArray(0)
            validateStatus(resp.code, body)
            return ProviderHTTPResponse(body)
        }
    }

    override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow {
        val okRequest = request.toOkHttpRequest()
        val call = client.newCall(okRequest)

        call.enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                // handled via cancellation
            }
            override fun onResponse(call: Call, response: Response) {
                // no-op, we use execute below
            }
        })
        call.cancel()

        val response = client.newCall(okRequest).execute()
        response.use { resp ->
            validateStatus(resp.code, ByteArray(0))
            val source = resp.body?.source() ?: return@flow
            val buffer = Buffer()
            while (true) {
                val bytesRead = source.read(buffer, SEGMENT_SIZE)
                if (bytesRead == -1L) break
                val chunk = buffer.readByteArray()
                emit(chunk)
            }
        }
    }.flowOn(Dispatchers.IO)

    private fun ProviderHTTPRequest.toOkHttpRequest(): Request {
        val mediaType = "application/json; charset=utf-8".toMediaType()
        val requestBody = body?.toRequestBody(mediaType)

        val builder = Request.Builder()
            .url(url)
            .method(method, requestBody)

        for ((key, value) in headers) {
            builder.addHeader(key, value)
        }

        return builder.build()
    }

    private suspend fun callAsync(request: Request): Response =
        suspendCancellableCoroutine { cont ->
            val call = client.newCall(request)
            cont.invokeOnCancellation { call.cancel() }
            call.enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    if (cont.isActive) {
                        cont.resumeWithException(categorizeException(e))
                    }
                }

                override fun onResponse(call: Call, response: Response) {
                    if (cont.isActive) {
                        cont.resume(response)
                    }
                }
            })
        }

    private fun validateStatus(code: Int, body: ByteArray) {
        if (code in 200..299) return
        throw ProviderTransportError.httpStatus(code)
    }

    private fun categorizeException(e: IOException): ProviderTransportError {
        val message = e.message?.lowercase() ?: ""
        return when {
            e is java.net.SocketTimeoutException || "timeout" in message ->
                ProviderTransportError.timedOut
            "connect" in message || "network" in message || "unresolved host" in message ->
                ProviderTransportError.networkFailure
            else -> ProviderTransportError.networkFailure
        }
    }

    companion object {
        private const val SEGMENT_SIZE = 8192L

        fun defaultClient(): OkHttpClient = OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(120, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()

        fun streamingClient(): OkHttpClient = OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(0, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()
    }
}
