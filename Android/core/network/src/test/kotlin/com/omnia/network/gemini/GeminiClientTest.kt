package com.omnia.network.gemini

import com.omnia.domain.Credential
import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageProtocol
import com.omnia.domain.Message
import com.omnia.domain.MessageRole
import com.omnia.network.transport.ProviderHTTPRequest
import com.omnia.network.transport.ProviderHTTPResponse
import com.omnia.network.transport.ProviderTransport
import com.omnia.network.transport.ProviderTransportError
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GeminiClientTest {

    private val credentialRef = CredentialReference(id = "cred-1")

    private fun fakeCredentialStorage(key: String): CredentialStorageProtocol =
        object : CredentialStorageProtocol {
            override suspend fun store(credential: Credential, reference: CredentialReference) {}
            override suspend fun credential(reference: CredentialReference): Credential =
                Credential.of(key)
            override suspend fun removeCredential(reference: CredentialReference) {}
        }

    private fun fakeTransport(responseBody: ByteArray, statusCode: Int = 200): ProviderTransport =
        object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                if (statusCode !in 200..299) throw ProviderTransportError.httpStatus(statusCode)
                return ProviderHTTPResponse(responseBody)
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow {
                emit(responseBody)
            }
        }

    @Test
    fun generateContentSuccess() = runTest {
        val responseJson = """{"candidates":[{"content":{"parts":[{"text":"Hello"}]}}]}"""
        val transport = fakeTransport(responseJson.toByteArray())
        val client = GeminiClient(transport, fakeCredentialStorage("test-key"))

        val request = GeminiMapping.textGenerationRequest("gemini-pro", "Hi")
        val response = client.generateContent(request, "gemini-pro", "https://generativelanguage.googleapis.com/v1", credentialRef)

        assertEquals("Hello", response.candidates!![0].content!!.parts!![0].text)
    }

    @Test
    fun generateContentInvalidResponse() = runTest {
        val transport = fakeTransport("not json".toByteArray())
        val client = GeminiClient(transport, fakeCredentialStorage("test-key"))

        val request = GeminiMapping.textGenerationRequest("gemini-pro", "Hi")
        try {
            client.generateContent(request, "gemini-pro", "https://generativelanguage.googleapis.com/v1", credentialRef)
            assertTrue("Should have thrown", false)
        } catch (e: ProviderTransportError) {
            assertEquals(ProviderTransportError.invalidResponse, e)
        }
    }

    @Test
    fun generateContentHttpError() = runTest {
        val transport = fakeTransport(ByteArray(0), statusCode = 403)
        val client = GeminiClient(transport, fakeCredentialStorage("test-key"))

        val request = GeminiMapping.textGenerationRequest("gemini-pro", "Hi")
        try {
            client.generateContent(request, "gemini-pro", "https://generativelanguage.googleapis.com/v1", credentialRef)
            assertTrue("Should have thrown", false)
        } catch (e: ProviderTransportError) {
            assertEquals(ProviderTransportError.httpStatus(403), e)
        }
    }

    @Test
    fun modelsReturnsModelIds() = runTest {
        val responseJson = """{"models":[{"name":"models/gemini-pro"},{"name":"models/gemini-flash"}]}"""
        val transport = fakeTransport(responseJson.toByteArray())
        val client = GeminiClient(transport, fakeCredentialStorage("test-key"))

        val models = client.models("https://generativelanguage.googleapis.com/v1", credentialRef)
        assertEquals(listOf("gemini-flash", "gemini-pro"), models)
    }

    @Test
    fun probeAvailabilityTrue() = runTest {
        val responseJson = """{"models":[{"name":"models/gemini-pro"}]}"""
        val transport = fakeTransport(responseJson.toByteArray())
        val client = GeminiClient(transport, fakeCredentialStorage("test-key"))

        assertTrue(client.probeAvailability("https://generativelanguage.googleapis.com/v1", credentialRef))
    }

    @Test
    fun probeAvailabilityFalse() = runTest {
        val transport = fakeTransport(ByteArray(0), statusCode = 401)
        val client = GeminiClient(transport, fakeCredentialStorage("test-key"))

        assertFalse(client.probeAvailability("https://generativelanguage.googleapis.com/v1", credentialRef))
    }

    @Test
    fun streamDeliversChunks() = runTest {
        val chunk1 = """{"candidates":[{"content":{"parts":[{"text":"Hi"}]}}]}"""
        val chunk2 = """{"candidates":[{"content":{"parts":[{"text":" there"}]}}]}"""
        val sseData = "data: $chunk1\n\ndata: $chunk2\n\n"

        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse = TODO()
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow {
                emit(sseData.toByteArray())
            }
        }

        val client = GeminiClient(transport, fakeCredentialStorage("test-key"))
        val request = GeminiMapping.streamingRequest(
            "gemini-pro",
            listOf(Message(role = MessageRole.user, content = "Hi")),
            emptyList()
        )

        val responses = client.streamGenerateContent(
            request, "gemini-pro", "https://generativelanguage.googleapis.com/v1", credentialRef
        ).toList()

        assertEquals(2, responses.size)
        assertEquals("Hi", responses[0].candidates!![0].content!!.parts!![0].text)
        assertEquals(" there", responses[1].candidates!![0].content!!.parts!![0].text)
    }

    @Test
    fun requestSendsApiKeyHeader() = runTest {
        var capturedRequest: ProviderHTTPRequest? = null
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                capturedRequest = request
                return ProviderHTTPResponse("""{"models":[]}""".toByteArray())
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val client = GeminiClient(transport, fakeCredentialStorage("test-api-key"))
        client.models("https://generativelanguage.googleapis.com/v1", credentialRef)

        assertEquals("test-api-key", capturedRequest!!.headers["x-goog-api-key"])
        assertEquals("https://generativelanguage.googleapis.com/v1/models", capturedRequest!!.url)
    }

    @Test
    fun requestUrlIncludesModelPath() = runTest {
        var capturedRequest: ProviderHTTPRequest? = null
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                capturedRequest = request
                return ProviderHTTPResponse("""{"candidates":[]}""".toByteArray())
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val client = GeminiClient(transport, fakeCredentialStorage("key"))
        val request = GeminiMapping.textGenerationRequest("gemini-pro", "Hi")
        client.generateContent(request, "gemini-pro", "https://generativelanguage.googleapis.com/v1", credentialRef)

        assertEquals(
            "https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent",
            capturedRequest!!.url
        )
    }
}
