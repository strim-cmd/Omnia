package com.omnia.feature.chat

import com.omnia.common.DispatcherProvider
import com.omnia.common.Logger

/**
 * Dependencies the Chat feature needs, declared by the feature and satisfied by
 * the app's composition root (AppContainer). The feature never reaches into the
 * app layer.
 */
interface ChatDependencies {
    val logger: Logger
    val dispatchers: DispatcherProvider
}
