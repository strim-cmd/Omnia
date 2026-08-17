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
        return configureValidated(request, endpoint = null, model = null, apiKind = ProviderAPIKind.default)
    }

    @Throws(ApplicationValidationError::class, ProviderLifecycleError::class)
    suspend fun configure(
        request: ConfigureProviderRequest,
        endpoint: String,
    ): Provider {
        val validatedEndpoint = validatedEndpoint(endpoint)
        return configureValidated(request, endpoint = validatedEndpoint, model = null, apiKind = ProviderAPIKind.default)
    }

    @Throws(ApplicationValidationError::class, ProviderLifecycleError::class)
    suspend fun configure(
        request: ConfigureProviderRequest,
        endpoint: String,
        model: String?,
        apiKind: ProviderAPIKind = ProviderAPIKind.default,
    ): Provider {
        val validatedEndpoint = validatedEndpoint(endpoint)
        val validatedModel = model?.let { validatedModel(it) }
        return configureValidated(request, endpoint = validatedEndpoint, model = validatedModel, apiKind = apiKind)
    }

    suspend fun allProviders(): List<Provider> =
        providerRepository.allProviders().sortedBy { it.identity.id }

    @Throws(ApplicationValidationError::class)
    suspend fun update(
        request: ProviderUpdateRequest,
        identity: ProviderIdentity,
        endpoint: String,
        model: String?,
        apiKind: ProviderAPIKind = ProviderAPIKind.default,
    ) {
        validateUpdateRequest(request)
        val validatedEndpoint = validatedEndpoint(endpoint)
        val validatedModel = model?.let { validatedModel(it) }
        val existing = providerRepository.provider(identity)
            ?: throw ApplicationValidationError.Invalid("Provider not found: ${identity.id}")

        val connection = ProviderConnection(
            identity = identity,
            capabilities = request.capabilities,
            metadata = ProviderMetadata(displayName = request.displayName),
            limits = request.limits,
            version = request.version,
        )
        val updated = existing.replacingConnection(connection)
        providerRepository.save(updated)
        lifecycleService.update(connection)

        updateEndpoint(validatedEndpoint, identity)
        updateAPIKind(apiKind, identity)
        if (validatedModel != null) {
            updateModel(validatedModel, identity)
        } else {
            configurationRepository.remove(modelKey(identity), ConfigurationLevel.providerSettings)
        }
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

    @Throws(ApplicationValidationError::class)
    suspend fun updateEndpoint(endpoint: String, identity: ProviderIdentity) {
        val trimmed = validatedEndpoint(endpoint)
        configurationRepository.store(trimmed, endpointKey(identity), ConfigurationLevel.providerSettings)
    }

    @Throws(ApplicationValidationError::class)
    suspend fun updateModel(model: String, identity: ProviderIdentity) {
        val trimmed = validatedModel(model)
        configurationRepository.store(trimmed, modelKey(identity), ConfigurationLevel.providerSettings)
    }

    suspend fun updateAPIKind(kind: ProviderAPIKind, identity: ProviderIdentity) {
        configurationRepository.store(kind, apiKindKey(identity), ConfigurationLevel.providerSettings)
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

    private fun validateUpdateRequest(request: ProviderUpdateRequest) {
        require(request.displayName.isNotBlank()) {
            throw ApplicationValidationError.Invalid("Display name must not be empty")
        }
        require(request.capabilities.capabilities.isNotEmpty()) {
            throw ApplicationValidationError.Invalid("Provider must declare at least one capability")
        }
    }

    private suspend fun configureValidated(
        request: ConfigureProviderRequest,
        endpoint: String?,
        model: String?,
        apiKind: ProviderAPIKind,
    ): Provider {
        require(request.displayName.isNotBlank()) {
            throw ApplicationValidationError.Invalid("Display name must not be empty")
        }
        require(request.capabilities.capabilities.isNotEmpty()) {
            throw ApplicationValidationError.Invalid("Provider must declare at least one capability")
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
        configurationRepository.store(credentialRef, credentialReferenceKey(identity), ConfigurationLevel.providerSettings)

        if (endpoint != null) {
            configurationRepository.store(endpoint, endpointKey(identity), ConfigurationLevel.providerSettings)
        }
        if (model != null) {
            configurationRepository.store(model, modelKey(identity), ConfigurationLevel.providerSettings)
        }
        configurationRepository.store(apiKind, apiKindKey(identity), ConfigurationLevel.providerSettings)

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

    companion object {
        fun credentialReferenceKey(identity: ProviderIdentity): ConfigurationKey<CredentialReference> =
            ConfigurationKey("providerCredential.${identity.id}")

        fun endpointKey(identity: ProviderIdentity): ConfigurationKey<String> =
            ConfigurationKey("providerEndpoint.${identity.id}")

        fun modelKey(identity: ProviderIdentity): ConfigurationKey<String> =
            ConfigurationKey("providerModel.${identity.id}")

        fun apiKindKey(identity: ProviderIdentity): ConfigurationKey<ProviderAPIKind> =
            ConfigurationKey("providerAPIKind.${identity.id}")

        fun validatedEndpoint(endpoint: String): String {
            val trimmed = endpoint.trim()
            require(trimmed.isNotEmpty()) {
                throw ApplicationValidationError.Invalid("The endpoint is empty.")
            }
            val separatorIndex = trimmed.indexOf("://")
            require(separatorIndex > 0) {
                throw ApplicationValidationError.Invalid("The endpoint must be an absolute http or https URL.")
            }
            val scheme = trimmed.substring(0, separatorIndex).lowercase()
            val authority = trimmed.substring(separatorIndex + 3)
            require((scheme == "http" || scheme == "https") && authority.isNotEmpty()) {
                throw ApplicationValidationError.Invalid("The endpoint must be an absolute http or https URL.")
            }
            return trimmed
        }

        fun validatedModel(model: String): String {
            val trimmed = model.trim()
            require(trimmed.isNotEmpty()) {
                throw ApplicationValidationError.Invalid("The model is empty.")
            }
            return trimmed
        }

        private fun generateId(): String = java.util.UUID.randomUUID().toString()
    }
}
