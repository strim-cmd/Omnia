package com.omnia.feature.providers

import com.omnia.common.DispatcherProvider
import com.omnia.common.Logger
import com.omnia.application.ProviderConnectionService
import com.omnia.application.ProviderModelService
import com.omnia.application.ProviderValidationService

/** Dependencies the Providers feature needs, satisfied by the app's AppContainer. */
interface ProvidersDependencies {
    val logger: Logger
    val dispatchers: DispatcherProvider
    val providerConnectionService: ProviderConnectionService
    val providerModelService: ProviderModelService
    val providerValidationService: ProviderValidationService
}
