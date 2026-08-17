package com.omnia.network.transport

import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class OkHttpProviderTransportTest {

    private lateinit var server: MockWebServer
    private lateinit var transport: OkHttpProviderTransport

    @Before
    fun setup() {
        server = MockWebServer()
        server.start()
        transport = OkHttpProviderTransport()
    }

    @After
    fun teardown() {
        server.shutdown()
    }

    @Test
    fun sendSuccess() = runTest {
        server.enqueue(MockResponse().setBody("ok").setResponseCode(200))

        val request = ProviderHTTPRequest(
            url = server.url("/test").toString(),
            method = "GET",
            headers = emptyMap(),
        )

        val response = transport.send(request)
        assertArrayEquals("ok".toByteArray(), response.body)
    }

    @Test
    fun sendWithHeaders() = runTest {
        server.enqueue(MockResponse().setBody("matched").setResponseCode(200))

        val request = ProviderHTTPRequest(
            url = server.url("/test").toString(),
            method = "GET",
            headers = mapOf("Authorization" to "Bearer test-key"),
        )

        transport.send(request)
        val recorded = server.takeRequest()
        assertEquals("Bearer test-key", recorded.getHeader("Authorization"))
    }

    @Test
    fun sendPostWithBody() = runTest {
        server.enqueue(MockResponse().setBody("created").setResponseCode(200))

        val body = """{"model":"gpt-4"}""".toByteArray()
        val request = ProviderHTTPRequest(
            url = server.url("/chat").toString(),
            method = "POST",
            headers = mapOf("Content-Type" to "application/json"),
            body = body,
        )

        val response = transport.send(request)
        assertArrayEquals("created".toByteArray(), response.body)
        val recorded = server.takeRequest()
        assertEquals(body.toString(Charsets.UTF_8), recorded.body.readUtf8())
    }

    @Test(expected = ProviderTransportError.httpStatus::class)
    fun sendHttpError401() = runTest {
        server.enqueue(MockResponse().setResponseCode(401).setBody("unauthorized"))

        val request = ProviderHTTPRequest(
            url = server.url("/test").toString(),
            method = "GET",
            headers = emptyMap(),
        )

        transport.send(request)
    }

    @Test(expected = ProviderTransportError.httpStatus::class)
    fun sendHttpError500() = runTest {
        server.enqueue(MockResponse().setResponseCode(500).setBody("error"))

        val request = ProviderHTTPRequest(
            url = server.url("/test").toString(),
            method = "GET",
            headers = emptyMap(),
        )

        transport.send(request)
    }

    @Test
    fun streamDeliversChunks() = runTest {
        server.enqueue(
            MockResponse()
                .setBody("chunk1chunk2chunk3")
                .setHeader("Content-Type", "text/event-stream")
        )

        val request = ProviderHTTPRequest(
            url = server.url("/stream").toString(),
            method = "GET",
            headers = emptyMap(),
        )

        val chunks = transport.stream(request).toList()
        val allData = StringBuilder()
        for (chunk in chunks) {
            allData.append(String(chunk))
        }
        assertTrue(allData.toString().contains("chunk1"))
    }

    @Test
    fun sendEmptyBody() = runTest {
        server.enqueue(MockResponse().setBody("").setResponseCode(200))

        val request = ProviderHTTPRequest(
            url = server.url("/test").toString(),
            method = "GET",
            headers = emptyMap(),
        )

        val response = transport.send(request)
        assertEquals(0, response.body.size)
    }

    @Test
    fun sendLargeBody() = runTest {
        val largeBody = "x".repeat(100_000)
        server.enqueue(MockResponse().setBody(largeBody).setResponseCode(200))

        val request = ProviderHTTPRequest(
            url = server.url("/test").toString(),
            method = "POST",
            headers = mapOf("Content-Type" to "text/plain"),
            body = largeBody.toByteArray(),
        )

        val response = transport.send(request)
        assertEquals(100_000, response.body.size)
    }

    @Test
    fun sendCancellationPropagates() = runTest {
        server.enqueue(MockResponse().setBody("ok").setResponseCode(200).throttleBody(1, 1, java.util.concurrent.TimeUnit.MINUTES))

        val request = ProviderHTTPRequest(
            url = server.url("/test").toString(),
            method = "GET",
            headers = emptyMap(),
        )

        var caughtCancellation = false
        val deferred = async {
            try {
                transport.send(request)
            } catch (_: kotlinx.coroutines.CancellationException) {
                caughtCancellation = true
            }
        }
        delay(50)
        deferred.cancel()
        try {
            deferred.await()
        } catch (_: kotlinx.coroutines.CancellationException) {
            caughtCancellation = true
        }
        assertTrue(caughtCancellation)
    }

    @Test
    fun sendCustomHeaders() = runTest {
        server.enqueue(MockResponse().setBody("ok"))

        val request = ProviderHTTPRequest(
            url = server.url("/test").toString(),
            method = "GET",
            headers = mapOf(
                "X-Custom" to "value1",
                "X-Another" to "value2",
            ),
        )

        transport.send(request)
        val recorded = server.takeRequest()
        assertEquals("value1", recorded.getHeader("X-Custom"))
        assertEquals("value2", recorded.getHeader("X-Another"))
    }
}
