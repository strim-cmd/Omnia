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
import com.omnia.network.gemini.GeminiGenerateContentResponse
import com.omnia.network.gemini.GeminiCandidate
import com.omnia.network.gemini.GeminiResponseContent
import com.omnia.network.gemini.GeminiPart
import com.omnia.network.transport.ProviderHTTPRequest
import com.omnia.network.transport.ProviderHTTPResponse
import com.omnia.network.transport.ProviderTransport
import com.omnia.network.transport.ProviderTransportError
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GeminiProviderAdapterTest {

    private val credentialRef = CredentialReference(id = "cred-1")

    private fun fakeCredentialStorage(): CredentialStorageProtocol = object : CredentialStorageProtocol {
        override suspend fun store(credential: Credential, reference: CredentialReference) {}
        override suspend fun credential(reference: CredentialReference): Credential = Credential.of("test-key")
        override suspend fun removeCredential(reference: CredentialReference) {}
    }

    @Test
    fun generateTextSuccess() = runTest {
        val responseJson = """{"candidates":[{"content":{"parts":[{"text":"Hello"}]}}]}"""
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                return ProviderHTTPResponse(responseJson.toByteArray())
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val adapter = GeminiProviderAdapter(transport, fakeCredentialStorage(), "https://generativelanguage.googleapis.com/v1", credentialRef)
        val result = adapter.generateText(
            TextGenerationRequest(
                identity = CapabilityRequestIdentity(id = "r1"),
                prompt = "Hi",
                model = ModelReference("gemini-pro"),
            )
        )
        assertEquals("Hello", result.text)
    }

    @Test
    fun sendMessageSuccess() = runTest {
        val responseJson = """{"candidates":[{"content":{"parts":[{"text":"I am fine"}]}}]}"""
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                return ProviderHTTPResponse(responseJson.toByteArray())
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val adapter = GeminiProviderAdapter(transport, fakeCredentialStorage(), "https://generativelanguage.googleapis.com/v1", credentialRef)
        val result = adapter.sendMessage(
            com.omnia.domain.ConversationRequest(
                identity = CapabilityRequestIdentity(id = "r1"),
                history = listOf(Message(role = MessageRole.user, content = "How are you?")),
                model = ModelReference("gemini-pro"),
            )
        )
        assertEquals(MessageRole.assistant, result.message.role)
        assertEquals("I am fine", result.message.content)
    }

    @Test
    fun streamDeliversUpdates() = runTest {
        val chunk1 = """{"candidates":[{"content":{"parts":[{"text":"Hi"}]}}]}"""
        val chunk2 = """{"candidates":[{"content":{"parts":[{"text":" there"}]}}]}"""
        val sseData = "data: $chunk1\n\ndata: $chunk2\n\n"

        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse = TODO()
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow {
                emit(sseData.toByteArray())
            }
        }

        val adapter = GeminiProviderAdapter(transport, fakeCredentialStorage(), "https://generativelanguage.googleapis.com/v1", credentialRef)
        val updates = adapter.stream(
            com.omnia.domain.StreamingRequest(
                identity = CapabilityRequestIdentity(id = "r1"),
                history = listOf(Message(role = MessageRole.user, content = "Hi")),
                model = ModelReference("gemini-pro"),
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

        val adapter = GeminiProviderAdapter(transport, fakeCredentialStorage(), "https://generativelanguage.googleapis.com/v1", credentialRef)
        try {
            adapter.generateText(
                TextGenerationRequest(
                    identity = CapabilityRequestIdentity(id = "r1"),
                    prompt = "Hi",
                    model = ModelReference("gemini-pro"),
                )
            )
            assertTrue("Should have thrown", false)
        } catch (e: com.omnia.domain.CapabilityError) {
            assertEquals(com.omnia.domain.CapabilityError.Unauthorized, e)
        }
    }

    @Test
    fun isAvailableReturnsTrue() = runTest {
        val responseJson = """{"models":[{"name":"models/gemini-pro"}]}"""
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                return ProviderHTTPResponse(responseJson.toByteArray())
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val adapter = GeminiProviderAdapter(transport, fakeCredentialStorage(), "https://generativelanguage.googleapis.com/v1", credentialRef)
        assertTrue(adapter.isAvailable())
    }
}
