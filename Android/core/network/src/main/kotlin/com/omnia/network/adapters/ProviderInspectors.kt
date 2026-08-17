package com.omnia.network.adapters

import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageProtocol
import com.omnia.domain.ModelReference
import com.omnia.network.mapping.ProviderErrorMapping
import com.omnia.network.openai.OpenAICompatibleClient
import com.omnia.network.transport.ProviderTransport
import com.omnia.network.transport.ProviderTransportError

/**
 * Interface for provider model discovery and connection validation.
 * An inspector is bound to one endpoint and credential. Returns only
 * Domain model identities and safe typed errors.
 */
interface ProviderInspector {
    suspend fun discoverModels(): List<ModelReference>
    suspend fun testConnection(model: ModelReference?): List<ModelReference>
}

/**
 * OpenAI-compatible model discovery and connection validation.
 *
 * When the models endpoint is unsupported (404/405/501), falls back to a
 * bounded one-token chat request to validate the actual configured
 * model/credential path.
 */
class OpenAICompatibleProviderInspector(
    private val client: OpenAICompatibleClient,
    private val endpoint: String,
    private val credential: CredentialReference,
) : ProviderInspector {

    constructor(
        transport: ProviderTransport,
        credentialStorage: CredentialStorageProtocol,
        endpoint: String,
        credential: CredentialReference,
    ) : this(
        OpenAICompatibleClient(transport, credentialStorage),
        endpoint,
        credential,
    )

    constructor(
        transport: ProviderTransport,
        endpoint: String,
        credential: com.omnia.domain.Credential,
    ) : this(
        OpenAICompatibleClient(transport, FixedCredentialStorage(credential)),
        endpoint,
        CredentialReference(id = "test-connection"),
    )

    override suspend fun discoverModels(): List<ModelReference> {
        return try {
            client.models(endpoint, credential).map { ModelReference(it) }
        } catch (e: ProviderTransportError) {
            throw CatalogErrorException(ProviderErrorMapping.catalogError(e))
        }
    }

    override suspend fun testConnection(model: ModelReference?): List<ModelReference> {
        try {
            val models = client.models(endpoint, credential).map { ModelReference(it) }
            if (model != null && models.none { it.name == model.name }) {
                throw ConnectionTestErrorException(com.omnia.domain.ProviderConnectionTestError.modelUnavailable)
            }
            return models
        } catch (e: ConnectionTestErrorException) {
            throw e
        } catch (e: CatalogErrorException) {
            throw ConnectionTestErrorException(com.omnia.domain.ProviderConnectionTestError.invalidCredential)
        } catch (e: ProviderTransportError) {
            if (discoveryIsUnsupported(e) && model != null) {
                return fallbackValidation(model)
            }
            throw ConnectionTestErrorException(ProviderErrorMapping.connectionError(e))
        }
    }

    private suspend fun fallbackValidation(model: ModelReference): List<ModelReference> {
        return try {
            val request = com.omnia.network.openai.OpenAIChatCompletionRequest(
                model = model.name,
                messages = listOf(
                    com.omnia.network.openai.OpenAIChatMessage(
                        role = "user",
                        content = com.omnia.network.openai.OpenAIContent.Text("OK")
                    )
                ),
                stream = false,
            )
            client.chatCompletions(request, endpoint, credential)
            listOf(model)
        } catch (e: ProviderTransportError) {
            if (e is ProviderTransportError.httpStatus && e.code in listOf(400, 404)) {
                throw ConnectionTestErrorException(com.omnia.domain.ProviderConnectionTestError.modelUnavailable)
            }
            throw ConnectionTestErrorException(ProviderErrorMapping.connectionError(e))
        } catch (e: ConnectionTestErrorException) {
            throw e
        }
    }

    private fun discoveryIsUnsupported(error: ProviderTransportError): Boolean {
        return error is ProviderTransportError.httpStatus && error.code in listOf(404, 405, 501)
    }
}

/**
 * Gemini model discovery and connection validation.
 *
 * Gemini's GET /models is authoritative and already validates the credential.
 * The recorded model is verified against the real list.
 */
class GeminiProviderInspector(
    private val client: com.omnia.network.gemini.GeminiClient,
    private val endpoint: String,
    private val credential: CredentialReference,
) : ProviderInspector {

    constructor(
        transport: ProviderTransport,
        credentialStorage: CredentialStorageProtocol,
        endpoint: String,
        credential: CredentialReference,
    ) : this(
        com.omnia.network.gemini.GeminiClient(transport, credentialStorage),
        endpoint,
        credential,
    )

    constructor(
        transport: ProviderTransport,
        endpoint: String,
        credential: com.omnia.domain.Credential,
    ) : this(
        com.omnia.network.gemini.GeminiClient(transport, FixedCredentialStorage(credential)),
        endpoint,
        CredentialReference(id = "test-connection"),
    )

    override suspend fun discoverModels(): List<ModelReference> {
        return try {
            client.models(endpoint, credential).map { ModelReference(it) }
        } catch (e: ProviderTransportError) {
            throw CatalogErrorException(ProviderErrorMapping.catalogError(e))
        }
    }

    override suspend fun testConnection(model: ModelReference?): List<ModelReference> {
        try {
            val models = client.models(endpoint, credential).map { ModelReference(it) }
            if (model != null) {
                val normalized = com.omnia.network.gemini.GeminiMapping.normalizedModelName(model.name)
                if (models.none { it.name == normalized }) {
                    throw ConnectionTestErrorException(com.omnia.domain.ProviderConnectionTestError.modelUnavailable)
                }
            }
            return models
        } catch (e: ConnectionTestErrorException) {
            throw e
        } catch (e: CatalogErrorException) {
            throw ConnectionTestErrorException(com.omnia.domain.ProviderConnectionTestError.invalidCredential)
        } catch (e: ProviderTransportError) {
            throw ConnectionTestErrorException(ProviderErrorMapping.connectionError(e))
        }
    }
}
