package com.omnia.feature.settings

import com.omnia.designsystem.theme.ThemeMode

/**
 * Immutable state of the Settings destination. Appearance (theme mode) is the
 * only live setting in the M1 shell; the About row is navigation only.
 */
data class SettingsUiState(
    val themeMode: ThemeMode = ThemeMode.SYSTEM,
    val showClearDataDialog: Boolean = false,
    val isClearingData: Boolean = false,
)
