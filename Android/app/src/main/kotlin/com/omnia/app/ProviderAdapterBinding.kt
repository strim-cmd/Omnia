package com.omnia.app

import com.omnia.application.ConfigurationService
import com.omnia.application.ProviderConnectionService
import com.omnia.domain.CapabilityError
import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageProtocol
import com.omnia.domain.ProviderAPIKind
import com.omnia.domain.ProviderRepository
import com.omnia.domain.StreamingContract
import com.omnia.domain.StreamingRequest
import com.omnia.domain.StreamingUpdate
import com.omnia.network.adapters.GeminiProviderAdapter
import com.omnia.network.adapters.OpenAICompatibleProviderAdapter
import com.omnia.network.transport.ProviderTransport
import kotlinx.coroutines.flow.Flow

interface AdapterFactory {
    fun createAdapter(
        endpoint: String,
        apiKind: ProviderAPIKind,
        credentialRef: CredentialReference,
    ): StreamingContract
}

class DefaultAdapterFactory(
    private val transport: ProviderTransport,
    private val credentialStorage: CredentialStorageProtocol,
) : AdapterFactory {
    override fun createAdapter(
        endpoint: String,
        apiKind: ProviderAPIKind,
        credentialRef: CredentialReference,
    ): StreamingContract = when (apiKind) {
        ProviderAPIKind.openAICompatible -> OpenAICompatibleProviderAdapter(transport, credentialStorage, endpoint, credentialRef)
        ProviderAPIKind.gemini -> GeminiProviderAdapter(transport, credentialStorage, endpoint, credentialRef)
    }
}

class ProviderAdapterBinding(
    private val providerRepository: ProviderRepository,
    private val configurationService: ConfigurationService,
    private val adapterFactory: AdapterFactory,
) : StreamingContract {

    override suspend fun stream(request: StreamingRequest): Flow<StreamingUpdate> {
        val identity = request.provider
            ?: throw CapabilityError.ProviderUnavailable

        val provider = providerRepository.provider(identity)
            ?: throw CapabilityError.ProviderUnavailable

        val endpoint = configurationService.resolved<String>(
            ProviderConnectionService.endpointKey(identity)
        ) ?: throw CapabilityError.InvalidRequest

        val credentialRef = configurationService.resolved<CredentialReference>(
            ProviderConnectionService.credentialReferenceKey(identity)
        ) ?: throw CapabilityError.InvalidRequest

        val apiKind = configurationService.resolved<ProviderAPIKind>(
            ProviderConnectionService.apiKindKey(identity)
        ) ?: ProviderAPIKind.openAICompatible

        val adapter = adapterFactory.createAdapter(endpoint, apiKind, credentialRef)
        return adapter.stream(request)
    }
}
