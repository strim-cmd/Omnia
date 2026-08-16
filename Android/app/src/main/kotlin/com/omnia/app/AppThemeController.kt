package com.omnia.app

import com.omnia.designsystem.theme.ThemeMode
import com.omnia.feature.settings.ThemeController
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Owns the app-wide theme preference. Satisfies the Settings feature's
 * [ThemeController] contract and drives [MainActivity] theming.
 */
class AppThemeController : ThemeController {

    private val _themeMode = MutableStateFlow(ThemeMode.SYSTEM)
    override val themeMode: StateFlow<ThemeMode> = _themeMode.asStateFlow()

    override fun setThemeMode(mode: ThemeMode) {
        _themeMode.value = mode
    }
}
