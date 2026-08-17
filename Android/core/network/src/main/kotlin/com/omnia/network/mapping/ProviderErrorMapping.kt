package com.omnia.network.mapping

import com.omnia.domain.CapabilityError
import com.omnia.domain.ModelCatalogError
import com.omnia.domain.ProviderConnectionTestError
import com.omnia.network.transport.ProviderTransportError

/**
 * Maps [ProviderTransportError] into the three Domain error categories:
 * - [ProviderConnectionTestError] for connection-test results
 * - [ModelCatalogError] for model-discovery results
 * - [CapabilityError] for text-generation / streaming results
 *
 * Every transport error resolves to exactly one Domain error in each category.
 */
object ProviderErrorMapping {

    fun toConnectionTestError(error: ProviderTransportError): ProviderConnectionTestError =
        when (error) {
            is ProviderTransportError.invalidRequest ->
                ProviderConnectionTestError.invalidEndpoint
            is ProviderTransportError.invalidResponse ->
                ProviderConnectionTestError.invalidResponse
            is ProviderTransportError.networkFailure ->
                ProviderConnectionTestError.unreachable
            is ProviderTransportError.timedOut ->
                ProviderConnectionTestError.timedOut
            is ProviderTransportError.httpStatus -> when {
                error.code == 401 || error.code == 403 ->
                    ProviderConnectionTestError.invalidCredential
                error.code == 404 ->
                    ProviderConnectionTestError.invalidEndpoint
                error.code == 429 ->
                    ProviderConnectionTestError.rateLimited
                error.code >= 500 ->
                    ProviderConnectionTestError.serverFailure
                else ->
                    ProviderConnectionTestError.invalidResponse
            }
        }

    fun toCatalogError(error: ProviderTransportError): ModelCatalogError =
        when (error) {
            is ProviderTransportError.invalidRequest ->
                ModelCatalogError.invalidResponse
            is ProviderTransportError.invalidResponse ->
                ModelCatalogError.invalidResponse
            is ProviderTransportError.networkFailure ->
                ModelCatalogError.unreachable
            is ProviderTransportError.timedOut ->
                ModelCatalogError.timedOut
            is ProviderTransportError.httpStatus -> when {
                error.code == 401 || error.code == 403 ->
                    ModelCatalogError.unauthorized
                error.code == 404 ->
                    ModelCatalogError.unreachable
                error.code == 429 ->
                    ModelCatalogError.rateLimited
                error.code >= 500 ->
                    ModelCatalogError.serverFailure
                else ->
                    ModelCatalogError.invalidResponse
            }
        }

    fun toCapabilityError(error: ProviderTransportError): CapabilityError =
        when (error) {
            is ProviderTransportError.invalidRequest ->
                CapabilityError.InvalidRequest
            is ProviderTransportError.invalidResponse ->
                CapabilityError.InvalidResponse
            is ProviderTransportError.networkFailure ->
                CapabilityError.NetworkUnavailable
            is ProviderTransportError.timedOut ->
                CapabilityError.TimedOut
            is ProviderTransportError.httpStatus -> when {
                error.code == 401 || error.code == 403 ->
                    CapabilityError.Unauthorized
                error.code == 404 ->
                    CapabilityError.InvalidEndpoint
                error.code == 429 ->
                    CapabilityError.RateLimited
                error.code >= 500 ->
                    CapabilityError.ServerFailure
                else ->
                    CapabilityError.InvalidResponse
            }
        }
}
