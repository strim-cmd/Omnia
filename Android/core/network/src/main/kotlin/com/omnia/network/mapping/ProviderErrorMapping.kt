package com.omnia.network.mapping

import com.omnia.domain.CapabilityError
import com.omnia.domain.CredentialStorageError
import com.omnia.domain.ModelCatalogError
import com.omnia.domain.ProviderConnectionTestError
import com.omnia.network.transport.ProviderTransportError

/**
 * Maps transport and credential errors into the three Domain error categories:
 * - [ProviderConnectionTestError] for connection-test results
 * - [ModelCatalogError] for model-discovery results
 * - [CapabilityError] for text-generation / streaming results
 *
 * Every transport error resolves to exactly one Domain error in each category.
 * Raw platform, transport, or credential errors never cross this boundary.
 */
object ProviderErrorMapping {

    fun connectionError(error: ProviderTransportError): ProviderConnectionTestError =
        when (error) {
            is ProviderTransportError.invalidRequest ->
                ProviderConnectionTestError.invalidEndpoint
            is ProviderTransportError.invalidResponse ->
                ProviderConnectionTestError.invalidResponse
            is ProviderTransportError.networkFailure ->
                ProviderConnectionTestError.unreachable
            is ProviderTransportError.timedOut ->
                ProviderConnectionTestError.timedOut
            is ProviderTransportError.httpStatus -> when (error.code) {
                401, 403 -> ProviderConnectionTestError.invalidCredential
                404, 405 -> ProviderConnectionTestError.invalidEndpoint
                408, 504 -> ProviderConnectionTestError.timedOut
                429 -> ProviderConnectionTestError.rateLimited
                in 500..599 -> ProviderConnectionTestError.serverFailure
                else -> ProviderConnectionTestError.invalidResponse
            }
        }

    fun catalogError(error: ProviderTransportError): ModelCatalogError =
        when (error) {
            is ProviderTransportError.invalidRequest ->
                ModelCatalogError.invalidResponse
            is ProviderTransportError.invalidResponse ->
                ModelCatalogError.invalidResponse
            is ProviderTransportError.networkFailure ->
                ModelCatalogError.unreachable
            is ProviderTransportError.timedOut ->
                ModelCatalogError.timedOut
            is ProviderTransportError.httpStatus -> when (error.code) {
                401, 403 -> ModelCatalogError.unauthorized
                404, 405, 501 -> ModelCatalogError.unsupported
                408, 504 -> ModelCatalogError.timedOut
                429 -> ModelCatalogError.rateLimited
                in 500..599 -> ModelCatalogError.serverFailure
                else -> ModelCatalogError.invalidResponse
            }
        }

    fun catalogError(error: CredentialStorageError): ModelCatalogError =
        when (error) {
            is CredentialStorageError.CredentialNotFound ->
                ModelCatalogError.unauthorized
            is CredentialStorageError.StorageUnavailable ->
                ModelCatalogError.unauthorized
        }

    fun capabilityError(error: ProviderTransportError): CapabilityError =
        when (error) {
            is ProviderTransportError.invalidRequest -> CapabilityError.InvalidRequest
            is ProviderTransportError.invalidResponse -> CapabilityError.InvalidResponse
            is ProviderTransportError.networkFailure -> CapabilityError.NetworkUnavailable
            is ProviderTransportError.timedOut -> CapabilityError.TimedOut
            is ProviderTransportError.httpStatus -> when {
                error.code in listOf(400, 409, 413, 415, 422) -> CapabilityError.InvalidRequest
                error.code in listOf(401, 403) -> CapabilityError.Unauthorized
                error.code in listOf(404, 405, 410) -> CapabilityError.InvalidEndpoint
                error.code == 408 -> CapabilityError.TimedOut
                error.code == 429 -> CapabilityError.RateLimited
                error.code in 500..599 -> CapabilityError.ServerFailure
                else -> CapabilityError.ProviderUnavailable
            }
        }
}
