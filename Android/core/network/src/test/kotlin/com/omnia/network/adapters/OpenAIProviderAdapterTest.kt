package com.omnia.network.adapters

import com.omnia.domain.CapabilityRequestIdentity
import com.omnia.domain.Credential
import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageProtocol
import com.omnia.domain.Message
import com.omnia.domain.MessageRole
import com.omnia.domain.ModelReference
import com.omnia.domain.StreamingUpdate
import com.omnia.domain.TextGenerationRequest
import com.omnia.network.openai.OpenAIChatCompletionChunk
import com.omnia.network.openai.OpenAIChatCompletionChunkChoice
import com.omnia.network.openai.OpenAIChatCompletionChunkDelta
import com.omnia.network.openai.OpenAIChatCompletionResponse
import com.omnia.network.openai.OpenAIChatCompletionChoice
import com.omnia.network.openai.OpenAIChatCompletionResponseMessage
import com.omnia.network.transport.ProviderHTTPRequest
import com.omnia.network.transport.ProviderHTTPResponse
import com.omnia.network.transport.ProviderTransport
import com.omnia.network.transport.ProviderTransportError
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class OpenAIProviderAdapterTest {

    private val json = Json { ignoreUnknownKeys = true }
    private val credentialRef = CredentialReference(id = "cred-1")

    private fun fakeCredentialStorage(): CredentialStorageProtocol = object : CredentialStorageProtocol {
        override suspend fun store(credential: Credential, reference: CredentialReference) {}
        override suspend fun credential(reference: CredentialReference): Credential = Credential.of("sk-test")
        override suspend fun removeCredential(reference: CredentialReference) {}
    }

    @Test
    fun generateTextSuccess() = runTest {
        val responseJson = """{"id":"1","model":"gpt-4","choices":[{"index":0,"message":{"role":"assistant","content":"Hello"},"finish_reason":"stop"}]}"""
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                return ProviderHTTPResponse(responseJson.toByteArray())
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val adapter = OpenAICompatibleProviderAdapter(transport, fakeCredentialStorage(), "https://api.openai.com/v1", credentialRef)
        val result = adapter.generateText(
            TextGenerationRequest(
                identity = CapabilityRequestIdentity(id = "r1"),
                prompt = "Hi",
                model = ModelReference("gpt-4"),
            )
        )
        assertEquals("Hello", result.text)
    }

    @Test
    fun sendMessageSuccess() = runTest {
        val responseJson = """{"id":"1","model":"gpt-4","choices":[{"index":0,"message":{"role":"assistant","content":"I am fine"},"finish_reason":"stop"}]}"""
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                return ProviderHTTPResponse(responseJson.toByteArray())
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val adapter = OpenAICompatibleProviderAdapter(transport, fakeCredentialStorage(), "https://api.openai.com/v1", credentialRef)
        val result = adapter.sendMessage(
            com.omnia.domain.ConversationRequest(
                identity = CapabilityRequestIdentity(id = "r1"),
                history = listOf(Message(role = MessageRole.user, content = "How are you?")),
                model = ModelReference("gpt-4"),
            )
        )
        assertEquals(MessageRole.assistant, result.message.role)
        assertEquals("I am fine", result.message.content)
    }

    @Test
    fun streamDeliversUpdates() = runTest {
        val chunk1 = """{"id":"1","model":"gpt-4","choices":[{"index":0,"delta":{"content":"Hi"},"finish_reason":null}]}"""
        val chunk2 = """{"id":"1","model":"gpt-4","choices":[{"index":0,"delta":{"content":" there"},"finish_reason":null}]}"""
        val sseData = "data: $chunk1\n\ndata: $chunk2\n\n"

        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse = TODO()
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow {
                emit(sseData.toByteArray())
            }
        }

        val adapter = OpenAICompatibleProviderAdapter(transport, fakeCredentialStorage(), "https://api.openai.com/v1", credentialRef)
        val updates = adapter.stream(
            com.omnia.domain.StreamingRequest(
                identity = CapabilityRequestIdentity(id = "r1"),
                history = listOf(Message(role = MessageRole.user, content = "Hi")),
                model = ModelReference("gpt-4"),
            )
        ).toList()

        val contentUpdates = updates.filterIsInstance<StreamingUpdate.ContentDelta>()
        assertEquals(2, contentUpdates.size)
        assertEquals("Hi", contentUpdates[0].content)
        assertEquals(" there", contentUpdates[1].content)

        val completion = updates.filterIsInstance<StreamingUpdate.Completion>()
        assertEquals(1, completion.size)
        assertEquals("Hi there", completion[0].message.content)
    }

    @Test
    fun transportErrorThrowsCapabilityError() = runTest {
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                throw ProviderTransportError.httpStatus(401)
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val adapter = OpenAICompatibleProviderAdapter(transport, fakeCredentialStorage(), "https://api.openai.com/v1", credentialRef)
        try {
            adapter.generateText(
                TextGenerationRequest(
                    identity = CapabilityRequestIdentity(id = "r1"),
                    prompt = "Hi",
                    model = ModelReference("gpt-4"),
                )
            )
            assertTrue("Should have thrown", false)
        } catch (e: com.omnia.domain.CapabilityError) {
            assertEquals(com.omnia.domain.CapabilityError.Unauthorized, e)
        }
    }

    @Test
    fun isAvailableReturnsTrue() = runTest {
        val responseJson = """{"data":[{"id":"gpt-4"}]}"""
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                return ProviderHTTPResponse(responseJson.toByteArray())
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val adapter = OpenAICompatibleProviderAdapter(transport, fakeCredentialStorage(), "https://api.openai.com/v1", credentialRef)
        assertTrue(adapter.isAvailable())
    }
}
