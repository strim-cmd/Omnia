package com.omnia.feature.settings

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.omnia.common.NoOpLogger
import com.omnia.common.SingleDispatcherProvider
import com.omnia.designsystem.theme.OmniaTheme
import com.omnia.designsystem.theme.ThemeMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.LEGACY)
@Config(sdk = [35])
class SettingsScreenTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun screen_rendersThemeOptionsAndAboutRow() {
        composeTestRule.setContent {
            OmniaTheme {
                SettingsScreen(
                    uiState = SettingsUiState(themeMode = ThemeMode.SYSTEM),
                    onThemeModeSelected = {},
                    onBack = {},
                    onOpenAbout = {},
                    onShowClearDataDialog = {},
                    onConfirmClearData = {},
                    onDismissClearDataDialog = {},
                )
            }
        }

        composeTestRule.onNodeWithText("System default").assertIsDisplayed()
        composeTestRule.onNodeWithText("Light").assertIsDisplayed()
        composeTestRule.onNodeWithText("Dark").assertIsDisplayed()
        composeTestRule.onNodeWithText("About Omnia").assertIsDisplayed()
    }

    @Test
    fun topBar_showsBackAction() {
        composeTestRule.setContent {
            OmniaTheme {
                SettingsScreen(
                    uiState = SettingsUiState(),
                    onThemeModeSelected = {},
                    onBack = {},
                    onOpenAbout = {},
                    onShowClearDataDialog = {},
                    onConfirmClearData = {},
                    onDismissClearDataDialog = {},
                )
            }
        }

        composeTestRule.onNodeWithContentDescription("Back").assertIsDisplayed()
    }

    @Test
    fun selectingLightMode_invokesCallback() {
        var selected: ThemeMode? = null
        composeTestRule.setContent {
            OmniaTheme {
                SettingsScreen(
                    uiState = SettingsUiState(themeMode = ThemeMode.SYSTEM),
                    onThemeModeSelected = { selected = it },
                    onBack = {},
                    onOpenAbout = {},
                    onShowClearDataDialog = {},
                    onConfirmClearData = {},
                    onDismissClearDataDialog = {},
                )
            }
        }

        composeTestRule.onNodeWithText("Light").performClick()

        assertEquals(ThemeMode.LIGHT, selected)
    }

    @Test
    fun selectingAboutRow_invokesCallback() {
        var opened = false
        composeTestRule.setContent {
            OmniaTheme {
                SettingsScreen(
                    uiState = SettingsUiState(),
                    onThemeModeSelected = {},
                    onBack = {},
                    onOpenAbout = { opened = true },
                    onShowClearDataDialog = {},
                    onConfirmClearData = {},
                    onDismissClearDataDialog = {},
                )
            }
        }

        composeTestRule.onNodeWithText("About Omnia").performClick()

        assertTrue(opened)
    }

    @Test
    fun screen_rendersClearDataRow() {
        composeTestRule.setContent {
            OmniaTheme {
                SettingsScreen(
                    uiState = SettingsUiState(),
                    onThemeModeSelected = {},
                    onBack = {},
                    onOpenAbout = {},
                    onShowClearDataDialog = {},
                    onConfirmClearData = {},
                    onDismissClearDataDialog = {},
                )
            }
        }

        composeTestRule.onNodeWithText("Clear all data").assertIsDisplayed()
        composeTestRule.onNodeWithText("Remove providers, conversations, and settings").assertIsDisplayed()
    }
}
