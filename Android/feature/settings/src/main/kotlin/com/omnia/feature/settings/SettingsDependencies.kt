package com.omnia.feature.settings

import com.omnia.common.DispatcherProvider
import com.omnia.common.Logger
import com.omnia.designsystem.theme.ThemeMode
import kotlinx.coroutines.flow.StateFlow

/**
 * Owns the theme preference. The app's composition root provides the real
 * implementation (AppThemeController); Settings only sees this contract.
 */
interface ThemeController {
    val themeMode: StateFlow<ThemeMode>
    fun setThemeMode(mode: ThemeMode)
}

/** Dependencies the Settings feature needs, satisfied by the app's AppContainer. */
interface SettingsDependencies {
    val themeController: ThemeController
    val logger: Logger
    val dispatchers: DispatcherProvider
}
