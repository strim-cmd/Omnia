package com.omnia.feature.providers

import com.omnia.common.DispatcherProvider
import com.omnia.common.Logger

/** Dependencies the Providers feature needs, satisfied by the app's AppContainer. */
interface ProvidersDependencies {
    val logger: Logger
    val dispatchers: DispatcherProvider
}
