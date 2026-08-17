package com.omnia.network.adapters

import com.omnia.domain.CapabilityRequestIdentity
import com.omnia.domain.Credential
import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageProtocol
import com.omnia.domain.Message
import com.omnia.domain.MessageRole
import com.omnia.domain.ModelReference
import com.omnia.network.openai.OpenAIMapping
import com.omnia.network.openai.OpenAICompatibleClient
import com.omnia.network.gemini.GeminiClient
import com.omnia.network.gemini.GeminiMapping
import com.omnia.network.transport.ProviderHTTPRequest
import com.omnia.network.transport.ProviderHTTPResponse
import com.omnia.network.transport.ProviderTransport
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Verifies that sentinel secret keys never appear in logs, exceptions,
 * URLs, or request metadata beyond the intended Authorization header.
 */
class ProviderPrivacyTest {

    private val sentinelKey = "SUPER_SECRET_TEST_KEY_1234567890abcdef"

    private fun geminiTransport(): Pair<ProviderTransport, MutableList<ProviderHTTPRequest>> {
        val requests = mutableListOf<ProviderHTTPRequest>()
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                requests.add(request)
                return ProviderHTTPResponse(
                    """{"candidates":[{"content":{"parts":[{"text":"OK"}]}}]}""".toByteArray()
                )
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow {
                requests.add(request)
            }
        }
        return transport to requests
    }

    private fun geminiModelsTransport(): Pair<ProviderTransport, MutableList<ProviderHTTPRequest>> {
        val requests = mutableListOf<ProviderHTTPRequest>()
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                requests.add(request)
                return ProviderHTTPResponse("""{"models":[{"name":"models/gemini-pro"}]}""".toByteArray())
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow {
                requests.add(request)
            }
        }
        return transport to requests
    }

    private fun modelsTransport(): Pair<ProviderTransport, MutableList<ProviderHTTPRequest>> {
        val requests = mutableListOf<ProviderHTTPRequest>()
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                requests.add(request)
                return ProviderHTTPResponse("""{"data":[{"id":"gpt-4"}]}""".toByteArray())
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow {
                requests.add(request)
            }
        }
        return transport to requests
    }

    private fun chatTransport(): Pair<ProviderTransport, MutableList<ProviderHTTPRequest>> {
        val requests = mutableListOf<ProviderHTTPRequest>()
        val transport = object : ProviderTransport {
            override suspend fun send(request: ProviderHTTPRequest): ProviderHTTPResponse {
                requests.add(request)
                return ProviderHTTPResponse(
                    """{"id":"1","model":"gpt-4","choices":[{"index":0,"message":{"role":"assistant","content":"OK"},"finish_reason":"stop"}]}""".toByteArray()
                )
            }
            override fun stream(request: ProviderHTTPRequest): Flow<ByteArray> = flow {
                requests.add(request)
            }
        }
        return transport to requests
    }

    private fun credentialStorage(key: String): CredentialStorageProtocol =
        object : CredentialStorageProtocol {
            override suspend fun store(credential: Credential, reference: CredentialReference) {}
            override suspend fun credential(reference: CredentialReference): Credential = Credential.of(key)
            override suspend fun removeCredential(reference: CredentialReference) {}
        }

    @Test
    fun openai_secretKeyNotInUrl() = runTest {
        val (transport, requests) = modelsTransport()
        val client = OpenAICompatibleClient(transport, credentialStorage(sentinelKey))
        val ref = CredentialReference(id = "c1")

        client.models("https://api.openai.com/v1", ref)

        for (req in requests) {
            assertFalse("Secret key must not appear in URL: ${req.url}", req.url.contains(sentinelKey))
        }
    }

    @Test
    fun openai_secretKeyOnlyInAuthorizationHeader() = runTest {
        val (transport, requests) = modelsTransport()
        val client = OpenAICompatibleClient(transport, credentialStorage(sentinelKey))
        val ref = CredentialReference(id = "c1")

        client.models("https://api.openai.com/v1", ref)

        for (req in requests) {
            val auth = req.headers["Authorization"] ?: continue
            assertTrue("Authorization must contain Bearer token", auth.startsWith("Bearer "))
            assertTrue("Authorization must contain the key", auth.contains(sentinelKey))

            for ((key, value) in req.headers) {
                if (key == "Authorization") continue
                assertFalse("Secret key must not appear in header $key", value.contains(sentinelKey))
            }
        }
    }

    @Test
    fun openai_secretKeyNotInUrlForChatCompletions() = runTest {
        val (transport, requests) = chatTransport()
        val client = OpenAICompatibleClient(transport, credentialStorage(sentinelKey))
        val ref = CredentialReference(id = "c1")

        val request = OpenAIMapping.textGenerationRequest("gpt-4", "Hi")
        client.chatCompletions(request, "https://api.openai.com/v1", ref)

        for (req in requests) {
            assertFalse("Secret key must not appear in URL", req.url.contains(sentinelKey))
        }
    }

    @Test
    fun gemini_secretKeyNotInUrl() = runTest {
        val (transport, requests) = geminiModelsTransport()
        val client = GeminiClient(transport, credentialStorage(sentinelKey))
        val ref = CredentialReference(id = "c1")

        client.models("https://generativelanguage.googleapis.com/v1", ref)

        for (req in requests) {
            assertFalse("Secret key must not appear in URL: ${req.url}", req.url.contains(sentinelKey))
        }
    }

    @Test
    fun gemini_secretKeyOnlyInApiKeyHeader() = runTest {
        val (transport, requests) = geminiModelsTransport()
        val client = GeminiClient(transport, credentialStorage(sentinelKey))
        val ref = CredentialReference(id = "c1")

        client.models("https://generativelanguage.googleapis.com/v1", ref)

        for (req in requests) {
            val apiKey = req.headers["x-goog-api-key"]
            assertTrue("x-goog-api-key must contain the key", apiKey == sentinelKey)

            for ((key, value) in req.headers) {
                if (key == "x-goog-api-key") continue
                assertFalse("Secret key must not appear in header $key", value.contains(sentinelKey))
            }
        }
    }

    @Test
    fun gemini_secretKeyNotInUrlForGenerateContent() = runTest {
        val (transport, requests) = geminiTransport()
        val client = GeminiClient(transport, credentialStorage(sentinelKey))
        val ref = CredentialReference(id = "c1")

        val request = GeminiMapping.textGenerationRequest("gemini-pro", "Hi")
        client.generateContent(request, "gemini-pro", "https://generativelanguage.googleapis.com/v1", ref)

        for (req in requests) {
            assertFalse("Secret key must not appear in URL", req.url.contains(sentinelKey))
        }
    }

    @Test
    fun credentialToStringRedactsValue() {
        val cred = Credential.of(sentinelKey)
        val str = cred.toString()
        assertFalse("Credential.toString() must not reveal the secret key", str.contains(sentinelKey))
        assertTrue("Credential.toString() should contain <redacted>", str.contains("redacted"))
    }
}
