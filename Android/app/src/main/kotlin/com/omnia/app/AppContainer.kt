package com.omnia.app

import android.content.Context
import com.omnia.application.AppMetadata
import com.omnia.application.ProvideAppMetadata
import com.omnia.common.Clock
import com.omnia.common.DispatcherProvider
import com.omnia.common.IdentifierFactory
import com.omnia.common.LogLevel
import com.omnia.common.Logger
import com.omnia.common.RandomIdentifierFactory
import com.omnia.common.SystemClock
import com.omnia.feature.chat.ChatDependencies
import com.omnia.feature.providers.ProvidersDependencies
import com.omnia.feature.settings.SettingsDependencies
import com.omnia.feature.settings.ThemeController

/**
 * Explicit composition root (no service locator, no DI framework). Every
 * dependency is constructed here once and injected into features through their
 * dependency contracts.
 */
class AppContainer(context: Context) {

    val clock: Clock = SystemClock()
    val identifierFactory: IdentifierFactory = RandomIdentifierFactory()
    val logger: Logger = AndroidLogger(minLevel = LogLevel.INFO)
    val dispatchers: DispatcherProvider = AndroidDispatchers()

    val appMetadata: AppMetadata = AppMetadata(
        name = "Omnia",
        marketingVersion = "1.0.1",
        buildNumber = "2",
    )
    val provideAppMetadata: ProvideAppMetadata = ProvideAppMetadata(appMetadata)

    val themeController: ThemeController = AppThemeController()

    val chatDependencies: ChatDependencies = object : ChatDependencies {
        override val logger: Logger get() = this@AppContainer.logger
        override val dispatchers: DispatcherProvider get() = this@AppContainer.dispatchers
    }

    val providersDependencies: ProvidersDependencies = object : ProvidersDependencies {
        override val logger: Logger get() = this@AppContainer.logger
        override val dispatchers: DispatcherProvider get() = this@AppContainer.dispatchers
    }

    val settingsDependencies: SettingsDependencies = object : SettingsDependencies {
        override val themeController: ThemeController get() = this@AppContainer.themeController
        override val logger: Logger get() = this@AppContainer.logger
        override val dispatchers: DispatcherProvider get() = this@AppContainer.dispatchers
    }
}
