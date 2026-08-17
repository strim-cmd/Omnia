package com.omnia.network.adapters

import com.omnia.domain.ModelCatalogError
import com.omnia.domain.ProviderConnectionTestError

/**
 * Throwable wrappers for Domain enums that need to be thrown.
 * Swift enums can conform to Error; Kotlin enums cannot.
 */
class CatalogErrorException(val error: ModelCatalogError) :
    Exception("Model catalog error: $error")

class ConnectionTestErrorException(val error: ProviderConnectionTestError) :
    Exception("Connection test error: $error")
