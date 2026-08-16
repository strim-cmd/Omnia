package com.omnia.designsystem.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.material3.MaterialTheme

/** Theme mode preference. SYSTEM follows the system setting. */
enum class ThemeMode { SYSTEM, LIGHT, DARK }

@Composable
fun OmniaTheme(
    themeMode: ThemeMode = ThemeMode.SYSTEM,
    content: @Composable () -> Unit,
) {
    val darkTheme = when (themeMode) {
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
    }
    val colorScheme = if (darkTheme) omniaDarkColorScheme() else omniaLightColorScheme()

    MaterialTheme(
        colorScheme = colorScheme,
        typography = OmniaTypography,
        shapes = OmniaShapes,
        content = content,
    )
}
