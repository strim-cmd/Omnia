package com.omnia.network.mapping

import com.omnia.domain.CapabilityError
import com.omnia.domain.ModelCatalogError
import com.omnia.domain.ProviderConnectionTestError
import com.omnia.network.transport.ProviderTransportError
import org.junit.Assert.assertEquals
import org.junit.Test

class ProviderErrorMappingTest {

    // --- ConnectionTestError ---

    @Test
    fun connectionTest_invalidRequest_mapsToInvalidEndpoint() {
        val result = ProviderErrorMapping.toConnectionTestError(ProviderTransportError.invalidRequest)
        assertEquals(ProviderConnectionTestError.invalidEndpoint, result)
    }

    @Test
    fun connectionTest_invalidResponse_mapsToInvalidResponse() {
        val result = ProviderErrorMapping.toConnectionTestError(ProviderTransportError.invalidResponse)
        assertEquals(ProviderConnectionTestError.invalidResponse, result)
    }

    @Test
    fun connectionTest_networkFailure_mapsToUnreachable() {
        val result = ProviderErrorMapping.toConnectionTestError(ProviderTransportError.networkFailure)
        assertEquals(ProviderConnectionTestError.unreachable, result)
    }

    @Test
    fun connectionTest_timedOut_mapsToTimedOut() {
        val result = ProviderErrorMapping.toConnectionTestError(ProviderTransportError.timedOut)
        assertEquals(ProviderConnectionTestError.timedOut, result)
    }

    @Test
    fun connectionTest_http401_mapsToInvalidCredential() {
        val result = ProviderErrorMapping.toConnectionTestError(ProviderTransportError.httpStatus(401))
        assertEquals(ProviderConnectionTestError.invalidCredential, result)
    }

    @Test
    fun connectionTest_http403_mapsToInvalidCredential() {
        val result = ProviderErrorMapping.toConnectionTestError(ProviderTransportError.httpStatus(403))
        assertEquals(ProviderConnectionTestError.invalidCredential, result)
    }

    @Test
    fun connectionTest_http404_mapsToInvalidEndpoint() {
        val result = ProviderErrorMapping.toConnectionTestError(ProviderTransportError.httpStatus(404))
        assertEquals(ProviderConnectionTestError.invalidEndpoint, result)
    }

    @Test
    fun connectionTest_http429_mapsToRateLimited() {
        val result = ProviderErrorMapping.toConnectionTestError(ProviderTransportError.httpStatus(429))
        assertEquals(ProviderConnectionTestError.rateLimited, result)
    }

    @Test
    fun connectionTest_http500_mapsToServerFailure() {
        val result = ProviderErrorMapping.toConnectionTestError(ProviderTransportError.httpStatus(500))
        assertEquals(ProviderConnectionTestError.serverFailure, result)
    }

    @Test
    fun connectionTest_http503_mapsToServerFailure() {
        val result = ProviderErrorMapping.toConnectionTestError(ProviderTransportError.httpStatus(503))
        assertEquals(ProviderConnectionTestError.serverFailure, result)
    }

    @Test
    fun connectionTest_http400_mapsToInvalidResponse() {
        val result = ProviderErrorMapping.toConnectionTestError(ProviderTransportError.httpStatus(400))
        assertEquals(ProviderConnectionTestError.invalidResponse, result)
    }

    // --- ModelCatalogError ---

    @Test
    fun catalog_invalidRequest_mapsToInvalidResponse() {
        val result = ProviderErrorMapping.toCatalogError(ProviderTransportError.invalidRequest)
        assertEquals(ModelCatalogError.invalidResponse, result)
    }

    @Test
    fun catalog_invalidResponse_mapsToInvalidResponse() {
        val result = ProviderErrorMapping.toCatalogError(ProviderTransportError.invalidResponse)
        assertEquals(ModelCatalogError.invalidResponse, result)
    }

    @Test
    fun catalog_networkFailure_mapsToUnreachable() {
        val result = ProviderErrorMapping.toCatalogError(ProviderTransportError.networkFailure)
        assertEquals(ModelCatalogError.unreachable, result)
    }

    @Test
    fun catalog_timedOut_mapsToTimedOut() {
        val result = ProviderErrorMapping.toCatalogError(ProviderTransportError.timedOut)
        assertEquals(ModelCatalogError.timedOut, result)
    }

    @Test
    fun catalog_http401_mapsToUnauthorized() {
        val result = ProviderErrorMapping.toCatalogError(ProviderTransportError.httpStatus(401))
        assertEquals(ModelCatalogError.unauthorized, result)
    }

    @Test
    fun catalog_http403_mapsToUnauthorized() {
        val result = ProviderErrorMapping.toCatalogError(ProviderTransportError.httpStatus(403))
        assertEquals(ModelCatalogError.unauthorized, result)
    }

    @Test
    fun catalog_http429_mapsToRateLimited() {
        val result = ProviderErrorMapping.toCatalogError(ProviderTransportError.httpStatus(429))
        assertEquals(ModelCatalogError.rateLimited, result)
    }

    @Test
    fun catalog_http500_mapsToServerFailure() {
        val result = ProviderErrorMapping.toCatalogError(ProviderTransportError.httpStatus(500))
        assertEquals(ModelCatalogError.serverFailure, result)
    }

    @Test
    fun catalog_http503_mapsToServerFailure() {
        val result = ProviderErrorMapping.toCatalogError(ProviderTransportError.httpStatus(503))
        assertEquals(ModelCatalogError.serverFailure, result)
    }

    // --- CapabilityError ---

    @Test
    fun capability_invalidRequest_mapsToInvalidRequest() {
        val result = ProviderErrorMapping.toCapabilityError(ProviderTransportError.invalidRequest)
        assertEquals(CapabilityError.InvalidRequest, result)
    }

    @Test
    fun capability_invalidResponse_mapsToInvalidResponse() {
        val result = ProviderErrorMapping.toCapabilityError(ProviderTransportError.invalidResponse)
        assertEquals(CapabilityError.InvalidResponse, result)
    }

    @Test
    fun capability_networkFailure_mapsToNetworkUnavailable() {
        val result = ProviderErrorMapping.toCapabilityError(ProviderTransportError.networkFailure)
        assertEquals(CapabilityError.NetworkUnavailable, result)
    }

    @Test
    fun capability_timedOut_mapsToTimedOut() {
        val result = ProviderErrorMapping.toCapabilityError(ProviderTransportError.timedOut)
        assertEquals(CapabilityError.TimedOut, result)
    }

    @Test
    fun capability_http401_mapsToUnauthorized() {
        val result = ProviderErrorMapping.toCapabilityError(ProviderTransportError.httpStatus(401))
        assertEquals(CapabilityError.Unauthorized, result)
    }

    @Test
    fun capability_http403_mapsToUnauthorized() {
        val result = ProviderErrorMapping.toCapabilityError(ProviderTransportError.httpStatus(403))
        assertEquals(CapabilityError.Unauthorized, result)
    }

    @Test
    fun capability_http404_mapsToInvalidEndpoint() {
        val result = ProviderErrorMapping.toCapabilityError(ProviderTransportError.httpStatus(404))
        assertEquals(CapabilityError.InvalidEndpoint, result)
    }

    @Test
    fun capability_http429_mapsToRateLimited() {
        val result = ProviderErrorMapping.toCapabilityError(ProviderTransportError.httpStatus(429))
        assertEquals(CapabilityError.RateLimited, result)
    }

    @Test
    fun capability_http500_mapsToServerFailure() {
        val result = ProviderErrorMapping.toCapabilityError(ProviderTransportError.httpStatus(500))
        assertEquals(CapabilityError.ServerFailure, result)
    }

    @Test
    fun capability_http503_mapsToServerFailure() {
        val result = ProviderErrorMapping.toCapabilityError(ProviderTransportError.httpStatus(503))
        assertEquals(CapabilityError.ServerFailure, result)
    }
}
