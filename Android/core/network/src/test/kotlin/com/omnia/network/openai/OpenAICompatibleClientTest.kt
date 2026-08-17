package com.omnia.network.openai

import com.omnia.domain.Credential
import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageProtocol
import com.omnia.domain.CredentialStorageError
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

class OpenAICompatibleClientTest {

    private val credentialRef = CredentialReference(id = "cred-1")

    private fun fakeCredentialStorage(key: String): CredentialStorageProtocol =
        object : CredentialStorageProtocol {
            override suspend fun store(credential: Credential, reference: CredentialReference) {}
            override suspend fun credential(reference: CredentialReference): Credential =
                Credential.of(key)
            override suspend fun removeCredential(reference: CredentialReference) {}
        }

    private fun fakeTransport(
        responseBody: ByteArray,
        statusCode: Int = 200,
    ): ProviderTransport = object : ProviderTransport {
        override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
            if (statusCode !in 200..299) {
                throw ProviderTransportError.httpStatus(statusCode)
            }
            return ProviderHTTPResponse(responseBody)
        }

        override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow {
            emit(responseBody)
        }
    }

    @Test
    fun chatCompletionsSuccess() = runTest {
        val responseJson = """{"id":"chatcmpl-1","model":"gpt-4","choices":[{"index":0,"message":{"role":"assistant","content":"Hello"},"finish_reason":"stop"}]}"""
        val transport = fakeTransport(responseJson.toByteArray())
        val client = OpenAICompatibleClient(transport, fakeCredentialStorage("sk-test"))

        val request = OpenAIMapping.textGenerationRequest("gpt-4", "Hi")
        val response = client.chatCompletions(request, "https://api.openai.com/v1", credentialRef)

        assertEquals("chatcmpl-1", response.id)
        assertEquals("Hello", response.choices[0].message.content)
    }

    @Test
    fun chatCompletionsInvalidResponse() = runTest {
        val transport = fakeTransport("not json".toByteArray())
        val client = OpenAICompatibleClient(transport, fakeCredentialStorage("sk-test"))

        val request = OpenAIMapping.textGenerationRequest("gpt-4", "Hi")
        try {
            client.chatCompletions(request, "https://api.openai.com/v1", credentialRef)
            assertTrue("Should have thrown", false)
        } catch (e: ProviderTransportError) {
            assertEquals(ProviderTransportError.invalidResponse, e)
        }
    }

    @Test
    fun chatCompletionsHttpError() = runTest {
        val transport = fakeTransport(ByteArray(0), statusCode = 401)
        val client = OpenAICompatibleClient(transport, fakeCredentialStorage("sk-test"))

        val request = OpenAIMapping.textGenerationRequest("gpt-4", "Hi")
        try {
            client.chatCompletions(request, "https://api.openai.com/v1", credentialRef)
            assertTrue("Should have thrown", false)
        } catch (e: ProviderTransportError) {
            assertEquals(ProviderTransportError.httpStatus(401), e)
        }
    }

    @Test
    fun modelsReturnsModelIds() = runTest {
        val responseJson = """{"data":[{"id":"gpt-4"},{"id":"gpt-3.5-turbo"}]}"""
        val transport = fakeTransport(responseJson.toByteArray())
        val client = OpenAICompatibleClient(transport, fakeCredentialStorage("sk-test"))

        val models = client.models("https://api.openai.com/v1", credentialRef)
        assertEquals(listOf("gpt-3.5-turbo", "gpt-4"), models)
    }

    @Test
    fun probeAvailabilityTrue() = runTest {
        val responseJson = """{"data":[{"id":"gpt-4"}]}"""
        val transport = fakeTransport(responseJson.toByteArray())
        val client = OpenAICompatibleClient(transport, fakeCredentialStorage("sk-test"))

        assertTrue(client.probeAvailability("https://api.openai.com/v1", credentialRef))
    }

    @Test
    fun probeAvailabilityFalse() = runTest {
        val transport = fakeTransport(ByteArray(0), statusCode = 401)
        val client = OpenAICompatibleClient(transport, fakeCredentialStorage("sk-test"))

        assertFalse(client.probeAvailability("https://api.openai.com/v1", credentialRef))
    }

    @Test
    fun streamChatCompletionsDeliversChunks() = runTest {
        val chunk1 = """{"id":"1","model":"gpt-4","choices":[{"index":0,"delta":{"content":"Hi"},"finish_reason":null}]}"""
        val chunk2 = """{"id":"1","model":"gpt-4","choices":[{"index":0,"delta":{"content":" there"},"finish_reason":null}]}"""
        val sseData = "data: $chunk1\n\ndata: $chunk2\n\ndata: [DONE]\n\n"

        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse = TODO()
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow {
                emit(sseData.toByteArray())
            }
        }

        val client = OpenAICompatibleClient(transport, fakeCredentialStorage("sk-test"))
        val request = OpenAIMapping.streamingRequest(
            "gpt-4",
            listOf(com.omnia.domain.Message(role = com.omnia.domain.MessageRole.user, content = "Hi")),
            emptyList()
        )

        val chunks = client.streamChatCompletions(request, "https://api.openai.com/v1", credentialRef).toList()
        assertEquals(2, chunks.size)
        assertEquals("Hi", chunks[0].choices[0].delta.content)
        assertEquals(" there", chunks[1].choices[0].delta.content)
    }

    @Test
    fun requestSendsCorrectHeaders() = runTest {
        var capturedRequest: ProviderHTTPRequest? = null
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                capturedRequest = request
                return ProviderHTTPResponse("""{"id":"1","model":"gpt-4","choices":[]}""".toByteArray())
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val client = OpenAICompatibleClient(transport, fakeCredentialStorage("sk-secret-key"))
        val request = OpenAIMapping.textGenerationRequest("gpt-4", "Hi")
        client.chatCompletions(request, "https://api.example.com/v1", credentialRef)

        assertEquals("Bearer sk-secret-key", capturedRequest!!.headers["Authorization"])
        assertEquals("application/json", capturedRequest!!.headers["Content-Type"])
        assertEquals("https://api.example.com/v1/chat/completions", capturedRequest!!.url)
    }

    @Test
    fun endpointBasePathPreservedWithTrailingSlash() = runTest {
        var capturedRequest: ProviderHTTPRequest? = null
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                capturedRequest = request
                return ProviderHTTPResponse("""{"id":"1","model":"m","choices":[]}""".toByteArray())
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val client = OpenAICompatibleClient(transport, fakeCredentialStorage("key"))
        val request = OpenAIMapping.textGenerationRequest("gpt-4", "Hi")
        client.chatCompletions(request, "https://proxy.example.com/my-api/v1/", credentialRef)

        assertEquals("https://proxy.example.com/my-api/v1/chat/completions", capturedRequest!!.url)
    }

    @Test
    fun endpointWithoutTrailingSlashWorks() = runTest {
        var capturedRequest: ProviderHTTPRequest? = null
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                capturedRequest = request
                return ProviderHTTPResponse("""{"id":"1","model":"m","choices":[]}""".toByteArray())
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val client = OpenAICompatibleClient(transport, fakeCredentialStorage("key"))
        val request = OpenAIMapping.textGenerationRequest("gpt-4", "Hi")
        client.chatCompletions(request, "https://api.openai.com/v1", credentialRef)

        assertEquals("https://api.openai.com/v1/chat/completions", capturedRequest!!.url)
    }

    @Test
    fun modelsEndpointPreservesBasePath() = runTest {
        var capturedRequest: ProviderHTTPRequest? = null
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                capturedRequest = request
                return ProviderHTTPResponse("""{"data":[{"id":"gpt-4"}]}""".toByteArray())
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val client = OpenAICompatibleClient(transport, fakeCredentialStorage("key"))
        client.models("https://proxy.example.com/custom/v1", credentialRef)

        assertEquals("https://proxy.example.com/custom/v1/models", capturedRequest!!.url)
    }
}
