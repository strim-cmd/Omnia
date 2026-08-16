package com.omnia.designsystem.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.LEGACY)
@Config(sdk = [35])
class ThemeTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private fun captureTheme(
        themeMode: ThemeMode,
        capture: (ColorScheme) -> Unit,
    ) {
        composeTestRule.setContent {
            OmniaTheme(themeMode = themeMode) {
                capture(MaterialTheme.colorScheme)
            }
        }
        composeTestRule.waitForIdle()
    }

    @Test
    fun lightTheme_usesLightBackground() {
        captureTheme(ThemeMode.LIGHT) { scheme ->
            assertEquals(Color(0xFFFBFAFF), scheme.background)
        }
    }

    @Test
    fun darkTheme_usesBrandDarkSurface() {
        captureTheme(ThemeMode.DARK) { scheme ->
            assertEquals(Color(0xFF0F1117), scheme.background)
        }
    }

    @Test
    fun lightTheme_usesBrandPrimary() {
        captureTheme(ThemeMode.LIGHT) { scheme ->
            assertEquals(Color(0xFF8A2BE2), scheme.primary)
        }
    }

    @Test
    fun darkTheme_usesBrandPrimary() {
        captureTheme(ThemeMode.DARK) { scheme ->
            assertEquals(Color(0xFFB18CFF), scheme.primary)
        }
    }

    @Test
    fun themeMode_defaultsToSystem() {
        assertEquals(ThemeMode.SYSTEM, ThemeMode.valueOf("SYSTEM"))
        assertEquals(ThemeMode.LIGHT, ThemeMode.valueOf("LIGHT"))
        assertEquals(ThemeMode.DARK, ThemeMode.valueOf("DARK"))
        assertEquals(3, ThemeMode.entries.size)
    }
}
