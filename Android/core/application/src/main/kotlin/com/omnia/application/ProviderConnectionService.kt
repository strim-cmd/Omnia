package com.omnia.application

import com.omnia.common.SemanticVersion
import com.omnia.domain.ConfigurationKey
import com.omnia.domain.ConfigurationLevel
import com.omnia.domain.ConfigurationRepository
import com.omnia.domain.Credential
import com.omnia.domain.CredentialReference
import com.omnia.domain.CredentialStorageProtocol
import com.omnia.domain.Provider
import com.omnia.domain.ProviderAPIKind
import com.omnia.domain.ProviderConnection
import com.omnia.domain.ProviderIdentity
import com.omnia.domain.ProviderLifecycleError
import com.omnia.domain.ProviderLifecycleService
import com.omnia.domain.ProviderMetadata
import com.omnia.domain.ProviderRepository
import com.omnia.domain.ProviderState

class ProviderConnectionService(
    private val providerRepository: ProviderRepository,
    private val credentialStorage: CredentialStorageProtocol,
    private val configurationRepository: ConfigurationRepository,
    private val lifecycleService: ProviderLifecycleService,
) {
    @Throws(ApplicationValidationError::class, ProviderLifecycleError::class)
    suspend fun configure(request: ConfigureProviderRequest): Provider {
        require(request.displayName.isNotBlank()) {
            throw ApplicationValidationError.Invalid("Display name must not be empty")
        }

        val identity = ProviderIdentity(id = generateId())
        val credentialRef = CredentialReference(id = generateId())

        val connection = ProviderConnection(
            identity = identity,
            capabilities = request.capabilities,
            metadata = ProviderMetadata(displayName = request.displayName),
            limits = request.limits,
            version = request.version,
        )

        credentialStorage.store(request.credential, credentialRef)

        configurationRepository.store(
            credentialRef,
            credentialReferenceKey(identity),
            ConfigurationLevel.providerSettings,
        )

        val provider = Provider(connection)
        providerRepository.save(provider)

        lifecycleService.register(connection)
        lifecycleService.transition(identity, ProviderState.validated)
        lifecycleService.transition(identity, ProviderState.initializing)
        lifecycleService.transition(identity, ProviderState.ready)

        val readyProvider = Provider.atState(connection, ProviderState.ready)
        providerRepository.save(readyProvider)

        return readyProvider
    }

    suspend fun allProviders(): List<Provider> =
        providerRepository.allProviders().sortedBy { it.identity.id }

    @Throws(ApplicationValidationError::class)
    suspend fun update(connection: ProviderConnection, identity: ProviderIdentity) {
        val existing = providerRepository.provider(identity)
            ?: throw ApplicationValidationError.Invalid("Provider not found: ${identity.id}")

        val updated = existing.replacingConnection(connection)
        providerRepository.save(updated)
        lifecycleService.update(connection)
    }

    @Throws(ApplicationValidationError::class)
    suspend fun remove(identity: ProviderIdentity) {
        val provider = providerRepository.provider(identity)
            ?: throw ApplicationValidationError.Invalid("Provider not found: ${identity.id}")

        val credentialRef = configurationRepository.value(
            credentialReferenceKey(identity),
            ConfigurationLevel.providerSettings,
        )

        if (credentialRef != null) {
            try {
                credentialStorage.removeCredential(credentialRef)
            } catch (_: Exception) { }
        }

        configurationRepository.remove(credentialReferenceKey(identity), ConfigurationLevel.providerSettings)
        configurationRepository.remove(endpointKey(identity), ConfigurationLevel.providerSettings)
        configurationRepository.remove(modelKey(identity), ConfigurationLevel.providerSettings)
        configurationRepository.remove(apiKindKey(identity), ConfigurationLevel.providerSettings)

        providerRepository.delete(identity)
        lifecycleService.unregister(identity)
    }

    suspend fun endpoint(identity: ProviderIdentity): String? =
        configurationRepository.value(endpointKey(identity), ConfigurationLevel.providerSettings)

    suspend fun model(identity: ProviderIdentity): String? =
        configurationRepository.value(modelKey(identity), ConfigurationLevel.providerSettings)

    suspend fun apiKind(identity: ProviderIdentity): ProviderAPIKind {
        return configurationRepository.value(
            apiKindKey(identity),
            ConfigurationLevel.providerSettings,
        ) ?: ProviderAPIKind.default
    }

    companion object {
        fun credentialReferenceKey(identity: ProviderIdentity): ConfigurationKey<CredentialReference> =
            ConfigurationKey("providerCredential.${identity.id}")

        fun endpointKey(identity: ProviderIdentity): ConfigurationKey<String> =
            ConfigurationKey("providerEndpoint.${identity.id}")

        fun modelKey(identity: ProviderIdentity): ConfigurationKey<String> =
            ConfigurationKey("providerModel.${identity.id}")

        fun apiKindKey(identity: ProviderIdentity): ConfigurationKey<ProviderAPIKind> =
            ConfigurationKey("providerAPIKind.${identity.id}")

        private fun generateId(): String = java.util.UUID.randomUUID().toString()
    }
}
