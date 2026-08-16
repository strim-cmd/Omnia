package com.omnia.designsystem.theme

import androidx.compose.ui.graphics.Color

// Brand tokens mirroring Documentation/UI/DESIGN_SYSTEM.md.
internal val OmniaPrimary = Color(0xFF8A2BE2)      // primary
internal val OmniaCyan = Color(0xFF00D4FF)          // secondary accent
internal val OmniaAccent = Color(0xFF7C3AED)        // accent
internal val OmniaSuccess = Color(0xFF22C55E)       // success/healthy
internal val OmniaDarkSurface = Color(0xFF0F1117)   // main dark background
internal val OmniaDarkElevated = Color(0xFF161A22)  // cards / elevated surfaces
internal val OmniaDarkBorder = Color(0xFF2A2F3A)    // subtle borders
internal val OmniaDarkText = Color(0xFFE5E7EB)      // primary text

private val LightColors = androidx.compose.material3.lightColorScheme(
    primary = OmniaPrimary,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFF0E1FF),
    onPrimaryContainer = Color(0xFF2A0052),
    secondary = Color(0xFF00708A),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFB8ECFF),
    onSecondaryContainer = Color(0xFF003647),
    tertiary = OmniaAccent,
    onTertiary = Color.White,
    background = Color(0xFFFBFAFF),
    onBackground = Color(0xFF1C1B22),
    surface = Color(0xFFFBFAFF),
    onSurface = Color(0xFF1C1B22),
    surfaceVariant = Color(0xFFE8E0F0),
    onSurfaceVariant = Color(0xFF49454E),
    outline = Color(0xFF7A757F),
    outlineVariant = Color(0xFFCBC4D4),
    error = Color(0xFFB3261E),
    onError = Color.White,
    errorContainer = Color(0xFFF9DEDC),
    onErrorContainer = Color(0xFF410E0B),
)

private val DarkColors = androidx.compose.material3.darkColorScheme(
    primary = Color(0xFFB18CFF),
    onPrimary = Color(0xFF2A0052),
    primaryContainer = Color(0xFF4A0F87),
    onPrimaryContainer = Color(0xFFEADDFF),
    secondary = OmniaCyan,
    onSecondary = Color(0xFF003643),
    secondaryContainer = Color(0xFF00536A),
    onSecondaryContainer = Color(0xFFB8ECFF),
    tertiary = Color(0xFFD0BCFF),
    onTertiary = Color(0xFF381E72),
    background = OmniaDarkSurface,
    onBackground = OmniaDarkText,
    surface = OmniaDarkSurface,
    onSurface = OmniaDarkText,
    surfaceVariant = OmniaDarkElevated,
    onSurfaceVariant = Color(0xFFC8C5D0),
    outline = Color(0xFF93918F),
    outlineVariant = OmniaDarkBorder,
    error = Color(0xFFF2B8B5),
    onError = Color(0xFF601410),
    errorContainer = Color(0xFF8C1D18),
    onErrorContainer = Color(0xFFF9DEDC),
)

internal fun omniaLightColorScheme() = LightColors

internal fun omniaDarkColorScheme() = DarkColors
