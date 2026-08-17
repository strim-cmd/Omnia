package com.omnia.application

import com.omnia.domain.ModelReference
import com.omnia.domain.ProviderAPIKind
import com.omnia.domain.ProviderIdentity
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ProviderValidationServiceTest {

    private lateinit var service: ProviderValidationService

    @Before
    fun setup() {
        service = ProviderValidationService(
            testCandidate = { _, _, _, _ -> listOf(ModelReference("gpt-4o")) },
            testExisting = { _, _, _, _ -> listOf(ModelReference("gpt-4o")) },
        )
    }

    @Test
    fun test_candidate_succeeds() {
        runBlocking {
            val result = service.test(
                ProviderConnectionTestRequest(
                    endpoint = "https://api.openai.com",
                    credential = com.omnia.domain.Credential.of("test-key"),
                )
            )
            assertEquals(1, result.models.size)
        }
    }

    @Test
    fun test_rejectsInvalidEndpoint() {
        runBlocking {
            try {
                service.test(
                    ProviderConnectionTestRequest(endpoint = "not-a-url", credential = com.omnia.domain.Credential.of("key"))
                )
                throw AssertionError("Expected Invalid")
            } catch (e: ApplicationValidationError.Invalid) {
                // expected
            }
        }
    }

    @Test
    fun test_rejectsNullCredential() {
        runBlocking {
            try {
                service.test(
                    ProviderConnectionTestRequest(endpoint = "https://api.test.com", credential = null)
                )
                throw AssertionError("Expected Invalid")
            } catch (e: ApplicationValidationError.Invalid) {
                // expected
            }
        }
    }

    @Test
    fun test_existingProvider_usesExistingTest() {
        runBlocking {
            val testExisting: suspend (ProviderIdentity, String, ModelReference?, ProviderAPIKind) -> List<ModelReference> =
                { _, _, _, _ -> listOf(ModelReference("claude-3")) }
            val svc = ProviderValidationService(
                testCandidate = { _, _, _, _ -> emptyList() },
                testExisting = testExisting,
            )
            val result = svc.test(
                ProviderConnectionTestRequest(
                    providerIdentity = ProviderIdentity("test"),
                    endpoint = "https://api.test.com",
                    credential = com.omnia.domain.Credential.of("key"),
                )
            )
            assertEquals(1, result.models.size)
            assertEquals("claude-3", result.models[0].name)
        }
    }
}
