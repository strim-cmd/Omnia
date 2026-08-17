package com.omnia.network.adapters

import com.omnia.domain.Credential
import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageProtocol
import com.omnia.domain.ModelReference
import com.omnia.domain.ProviderConnectionTestError
import com.omnia.network.transport.ProviderHTTPRequest
import com.omnia.network.transport.ProviderHTTPResponse
import com.omnia.network.transport.ProviderTransport
import com.omnia.network.transport.ProviderTransportError
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ProviderInspectorTest {

    private val credentialRef = CredentialReference(id = "cred-1")

    private fun fakeCredentialStorage(): CredentialStorageProtocol = object : CredentialStorageProtocol {
        override suspend fun store(credential: Credential, reference: CredentialReference) {}
        override suspend fun credential(reference: CredentialReference): Credential = Credential.of("test-key")
        override suspend fun removeCredential(reference: CredentialReference) {}
    }

    // --- OpenAI Inspector ---

    @Test
    fun openAI_discoverModels() = runTest {
        val responseJson = """{"data":[{"id":"gpt-4"},{"id":"gpt-3.5-turbo"}]}"""
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse =
                ProviderHTTPResponse(responseJson.toByteArray())
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val inspector = OpenAICompatibleProviderInspector(transport, fakeCredentialStorage(), "https://api.openai.com/v1", credentialRef)
        val models = inspector.discoverModels()
        assertEquals(2, models.size)
        assertEquals("gpt-3.5-turbo", models[0].name)
        assertEquals("gpt-4", models[1].name)
    }

    @Test
    fun openAI_testConnectionSuccess() = runTest {
        val responseJson = """{"data":[{"id":"gpt-4"}]}"""
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse =
                ProviderHTTPResponse(responseJson.toByteArray())
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val inspector = OpenAICompatibleProviderInspector(transport, fakeCredentialStorage(), "https://api.openai.com/v1", credentialRef)
        val models = inspector.testConnection(ModelReference("gpt-4"))
        assertEquals(1, models.size)
        assertEquals("gpt-4", models[0].name)
    }

    @Test
    fun openAI_testConnectionModelUnavailable() = runTest {
        val responseJson = """{"data":[{"id":"gpt-4"}]}"""
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse =
                ProviderHTTPResponse(responseJson.toByteArray())
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val inspector = OpenAICompatibleProviderInspector(transport, fakeCredentialStorage(), "https://api.openai.com/v1", credentialRef)
        try {
            inspector.testConnection(ModelReference("nonexistent-model"))
            assertTrue("Should have thrown", false)
        } catch (e: ConnectionTestErrorException) {
            assertEquals(ProviderConnectionTestError.modelUnavailable, e.error)
        }
    }

    @Test
    fun openAI_testConnectionFallbackWhenDiscoveryUnsupported() = runTest {
        var callCount = 0
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                callCount++
                if (request.url.endsWith("/models")) {
                    throw ProviderTransportError.httpStatus(404)
                }
                return ProviderHTTPResponse(
                    """{"id":"1","model":"custom-model","choices":[{"index":0,"message":{"role":"assistant","content":"OK"}}]}""".toByteArray()
                )
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val inspector = OpenAICompatibleProviderInspector(transport, fakeCredentialStorage(), "https://custom.api.com/v1", credentialRef)
        val models = inspector.testConnection(ModelReference("custom-model"))
        assertEquals(1, models.size)
        assertEquals("custom-model", models[0].name)
        assertEquals(2, callCount) // GET /models + POST /chat/completions
    }

    @Test
    fun openAI_testConnectionNullModel() = runTest {
        val responseJson = """{"data":[{"id":"gpt-4"}]}"""
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse =
                ProviderHTTPResponse(responseJson.toByteArray())
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val inspector = OpenAICompatibleProviderInspector(transport, fakeCredentialStorage(), "https://api.openai.com/v1", credentialRef)
        val models = inspector.testConnection(null)
        assertEquals(1, models.size)
    }

    // --- Gemini Inspector ---

    @Test
    fun gemini_discoverModels() = runTest {
        val responseJson = """{"models":[{"name":"models/gemini-pro"},{"name":"models/gemini-flash"}]}"""
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse =
                ProviderHTTPResponse(responseJson.toByteArray())
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val inspector = GeminiProviderInspector(transport, fakeCredentialStorage(), "https://generativelanguage.googleapis.com/v1", credentialRef)
        val models = inspector.discoverModels()
        assertEquals(2, models.size)
        assertEquals("gemini-flash", models[0].name)
        assertEquals("gemini-pro", models[1].name)
    }

    @Test
    fun gemini_testConnectionSuccess() = runTest {
        val responseJson = """{"models":[{"name":"models/gemini-pro"}]}"""
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse =
                ProviderHTTPResponse(responseJson.toByteArray())
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val inspector = GeminiProviderInspector(transport, fakeCredentialStorage(), "https://generativelanguage.googleapis.com/v1", credentialRef)
        val models = inspector.testConnection(ModelReference("gemini-pro"))
        assertEquals(1, models.size)
    }

    @Test
    fun gemini_testConnectionModelUnavailable() = runTest {
        val responseJson = """{"models":[{"name":"models/gemini-pro"}]}"""
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse =
                ProviderHTTPResponse(responseJson.toByteArray())
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val inspector = GeminiProviderInspector(transport, fakeCredentialStorage(), "https://generativelanguage.googleapis.com/v1", credentialRef)
        try {
            inspector.testConnection(ModelReference("nonexistent"))
            assertTrue("Should have thrown", false)
        } catch (e: ConnectionTestErrorException) {
            assertEquals(ProviderConnectionTestError.modelUnavailable, e.error)
        }
    }

    @Test
    fun gemini_testConnectionNormalizesModelName() = runTest {
        val responseJson = """{"models":[{"name":"models/gemini-pro"}]}"""
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse =
                ProviderHTTPResponse(responseJson.toByteArray())
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow { }
        }

        val inspector = GeminiProviderInspector(transport, fakeCredentialStorage(), "https://generativelanguage.googleapis.com/v1", credentialRef)
        val models = inspector.testConnection(ModelReference("models/gemini-pro"))
        assertEquals(1, models.size)
    }
}
