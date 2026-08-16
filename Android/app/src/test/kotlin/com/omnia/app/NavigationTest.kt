package com.omnia.app

import android.content.Context
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ApplicationProvider
import com.omnia.app.navigation.OmniaNavHost
import com.omnia.designsystem.theme.OmniaTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Shell-level navigation tests: launch on Chat, reach every destination from
 * the top bar, and honor system-style back via the back stack.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.LEGACY)
@Config(sdk = [35])
class NavigationTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val context: Context = ApplicationProvider.getApplicationContext()

    private fun setNavContent() {
        composeTestRule.setContent {
            OmniaTheme {
                OmniaNavHost(container = AppContainer(context))
            }
        }
    }

    @Test
    fun launchesOnChatEmptyState() {
        setNavContent()
        composeTestRule.onNodeWithText("No conversation yet").assertIsDisplayed()
    }

    @Test
    fun chat_opensSettings() {
        setNavContent()
        composeTestRule.onNodeWithContentDescription("Open settings").performClick()
        composeTestRule.onNodeWithText("Settings").assertIsDisplayed()
    }

    @Test
    fun chat_opensProviders() {
        setNavContent()
        composeTestRule.onNodeWithContentDescription("Open providers").performClick()
        composeTestRule.onNodeWithText("No providers configured").assertIsDisplayed()
    }

    @Test
    fun settings_opensAbout() {
        setNavContent()
        composeTestRule.onNodeWithContentDescription("Open settings").performClick()
        composeTestRule.onNodeWithText("About Omnia").performClick()
        composeTestRule.onNodeWithText("Omnia").assertIsDisplayed()
        composeTestRule.onNodeWithText("Version 1.0.1 (2)").assertIsDisplayed()
    }

    @Test
    fun settings_backReturnsToChat() {
        setNavContent()
        composeTestRule.onNodeWithContentDescription("Open settings").performClick()
        composeTestRule.onNodeWithText("Settings").assertIsDisplayed()
        composeTestRule.onNodeWithContentDescription("Back").performClick()
        composeTestRule.onNodeWithText("No conversation yet").assertIsDisplayed()
    }
}
