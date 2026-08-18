package com.omnia.application

import com.omnia.domain.ModelReference
import com.omnia.domain.ProviderAPIKind
import com.omnia.domain.ProviderConnectionTestError
import com.omnia.domain.ProviderIdentity

class ProviderValidationService(
    private val testCandidate: suspend (endpoint: String, credential: com.omnia.domain.Credential, model: ModelReference?, apiKind: ProviderAPIKind) -> List<ModelReference>,
    private val testExisting: suspend (identity: ProviderIdentity, endpoint: String, model: ModelReference?, apiKind: ProviderAPIKind) -> List<ModelReference>,
) {
    @Throws(ApplicationValidationError::class)
    suspend fun test(request: ProviderConnectionTestRequest): ProviderConnectionTestResult {
        val endpoint = request.endpoint?.trim() ?: ""
        val model = request.model?.trim()?.takeIf { it.isNotEmpty() }?.let { ModelReference(it) }
        val apiKind = request.apiKind ?: ProviderAPIKind.default

        if (!isValidEndpoint(endpoint)) {
            throw ApplicationValidationError.Invalid("Invalid endpoint: $endpoint")
        }

        val credential = request.credential

        val models = if (request.providerIdentity != null) {
            testExisting(request.providerIdentity, endpoint, model, apiKind)
        } else {
            val resolvedCredential = credential
                ?: throw ApplicationValidationError.Invalid("Credential is required")
            testCandidate(endpoint, resolvedCredential, model, apiKind)
        }

        return ProviderConnectionTestResult(models = models)
    }

    private fun isValidEndpoint(endpoint: String): Boolean {
        if (endpoint.isBlank()) return false
        val lowered = endpoint.lowercase()
        return lowered.startsWith("http://") || lowered.startsWith("https://")
    }
}

data class ProviderConnectionTestRequest(
    val providerIdentity: ProviderIdentity? = null,
    val endpoint: String? = null,
    val model: String? = null,
    val credential: com.omnia.domain.Credential? = null,
    val apiKind: ProviderAPIKind? = null,
)

data class ProviderConnectionTestResult(
    val models: List<ModelReference>,
)
