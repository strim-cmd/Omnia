package com.omnia.network.mapping

import com.omnia.domain.CapabilityError
import com.omnia.domain.CredentialStorageError
import com.omnia.domain.ModelCatalogError
import com.omnia.domain.ProviderConnectionTestError
import com.omnia.network.transport.ProviderTransportError
import org.junit.Assert.assertEquals
import org.junit.Test

class ProviderErrorMappingTest {

    // --- connectionError ---

    @Test
    fun connectionTest_invalidRequest_mapsToInvalidEndpoint() {
        assertEquals(ProviderConnectionTestError.invalidEndpoint, ProviderErrorMapping.connectionError(ProviderTransportError.invalidRequest))
    }

    @Test
    fun connectionTest_invalidResponse_mapsToInvalidResponse() {
        assertEquals(ProviderConnectionTestError.invalidResponse, ProviderErrorMapping.connectionError(ProviderTransportError.invalidResponse))
    }

    @Test
    fun connectionTest_networkFailure_mapsToUnreachable() {
        assertEquals(ProviderConnectionTestError.unreachable, ProviderErrorMapping.connectionError(ProviderTransportError.networkFailure))
    }

    @Test
    fun connectionTest_timedOut_mapsToTimedOut() {
        assertEquals(ProviderConnectionTestError.timedOut, ProviderErrorMapping.connectionError(ProviderTransportError.timedOut))
    }

    @Test
    fun connectionTest_http401_mapsToInvalidCredential() {
        assertEquals(ProviderConnectionTestError.invalidCredential, ProviderErrorMapping.connectionError(ProviderTransportError.httpStatus(401)))
    }

    @Test
    fun connectionTest_http403_mapsToInvalidCredential() {
        assertEquals(ProviderConnectionTestError.invalidCredential, ProviderErrorMapping.connectionError(ProviderTransportError.httpStatus(403)))
    }

    @Test
    fun connectionTest_http404_mapsToInvalidEndpoint() {
        assertEquals(ProviderConnectionTestError.invalidEndpoint, ProviderErrorMapping.connectionError(ProviderTransportError.httpStatus(404)))
    }

    @Test
    fun connectionTest_http405_mapsToInvalidEndpoint() {
        assertEquals(ProviderConnectionTestError.invalidEndpoint, ProviderErrorMapping.connectionError(ProviderTransportError.httpStatus(405)))
    }

    @Test
    fun connectionTest_http429_mapsToRateLimited() {
        assertEquals(ProviderConnectionTestError.rateLimited, ProviderErrorMapping.connectionError(ProviderTransportError.httpStatus(429)))
    }

    @Test
    fun connectionTest_http500_mapsToServerFailure() {
        assertEquals(ProviderConnectionTestError.serverFailure, ProviderErrorMapping.connectionError(ProviderTransportError.httpStatus(500)))
    }

    @Test
    fun connectionTest_http503_mapsToServerFailure() {
        assertEquals(ProviderConnectionTestError.serverFailure, ProviderErrorMapping.connectionError(ProviderTransportError.httpStatus(503)))
    }

    @Test
    fun connectionTest_http400_mapsToInvalidResponse() {
        assertEquals(ProviderConnectionTestError.invalidResponse, ProviderErrorMapping.connectionError(ProviderTransportError.httpStatus(400)))
    }

    @Test
    fun connectionTest_http408_mapsToTimedOut() {
        assertEquals(ProviderConnectionTestError.timedOut, ProviderErrorMapping.connectionError(ProviderTransportError.httpStatus(408)))
    }

    // --- catalogError (transport) ---

    @Test
    fun catalog_transport_invalidRequest_mapsToInvalidResponse() {
        assertEquals(ModelCatalogError.invalidResponse, ProviderErrorMapping.catalogError(ProviderTransportError.invalidRequest))
    }

    @Test
    fun catalog_transport_networkFailure_mapsToUnreachable() {
        assertEquals(ModelCatalogError.unreachable, ProviderErrorMapping.catalogError(ProviderTransportError.networkFailure))
    }

    @Test
    fun catalog_transport_timedOut_mapsToTimedOut() {
        assertEquals(ModelCatalogError.timedOut, ProviderErrorMapping.catalogError(ProviderTransportError.timedOut))
    }

    @Test
    fun catalog_transport_http401_mapsToUnauthorized() {
        assertEquals(ModelCatalogError.unauthorized, ProviderErrorMapping.catalogError(ProviderTransportError.httpStatus(401)))
    }

    @Test
    fun catalog_transport_http404_mapsToUnsupported() {
        assertEquals(ModelCatalogError.unsupported, ProviderErrorMapping.catalogError(ProviderTransportError.httpStatus(404)))
    }

    @Test
    fun catalog_transport_http501_mapsToUnsupported() {
        assertEquals(ModelCatalogError.unsupported, ProviderErrorMapping.catalogError(ProviderTransportError.httpStatus(501)))
    }

    @Test
    fun catalog_transport_http429_mapsToRateLimited() {
        assertEquals(ModelCatalogError.rateLimited, ProviderErrorMapping.catalogError(ProviderTransportError.httpStatus(429)))
    }

    @Test
    fun catalog_transport_http500_mapsToServerFailure() {
        assertEquals(ModelCatalogError.serverFailure, ProviderErrorMapping.catalogError(ProviderTransportError.httpStatus(500)))
    }

    // --- catalogError (credential) ---

    @Test
    fun catalog_credential_notFound_mapsToUnauthorized() {
        assertEquals(ModelCatalogError.unauthorized, ProviderErrorMapping.catalogError(CredentialStorageError.CredentialNotFound))
    }

    @Test
    fun catalog_credential_storageUnavailable_mapsToUnauthorized() {
        assertEquals(ModelCatalogError.unauthorized, ProviderErrorMapping.catalogError(CredentialStorageError.StorageUnavailable))
    }

    // --- capabilityError ---

    @Test
    fun capability_invalidRequest() {
        assertEquals(CapabilityError.InvalidRequest, ProviderErrorMapping.capabilityError(ProviderTransportError.invalidRequest))
    }

    @Test
    fun capability_invalidResponse() {
        assertEquals(CapabilityError.InvalidResponse, ProviderErrorMapping.capabilityError(ProviderTransportError.invalidResponse))
    }

    @Test
    fun capability_networkFailure() {
        assertEquals(CapabilityError.NetworkUnavailable, ProviderErrorMapping.capabilityError(ProviderTransportError.networkFailure))
    }

    @Test
    fun capability_timedOut() {
        assertEquals(CapabilityError.TimedOut, ProviderErrorMapping.capabilityError(ProviderTransportError.timedOut))
    }

    @Test
    fun capability_http401() {
        assertEquals(CapabilityError.Unauthorized, ProviderErrorMapping.capabilityError(ProviderTransportError.httpStatus(401)))
    }

    @Test
    fun capability_http404() {
        assertEquals(CapabilityError.InvalidEndpoint, ProviderErrorMapping.capabilityError(ProviderTransportError.httpStatus(404)))
    }

    @Test
    fun capability_http429() {
        assertEquals(CapabilityError.RateLimited, ProviderErrorMapping.capabilityError(ProviderTransportError.httpStatus(429)))
    }

    @Test
    fun capability_http500() {
        assertEquals(CapabilityError.ServerFailure, ProviderErrorMapping.capabilityError(ProviderTransportError.httpStatus(500)))
    }

    @Test
    fun capability_http400() {
        assertEquals(CapabilityError.InvalidRequest, ProviderErrorMapping.capabilityError(ProviderTransportError.httpStatus(400)))
    }
}
