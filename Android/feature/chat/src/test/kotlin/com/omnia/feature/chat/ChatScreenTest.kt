package com.omnia.feature.chat

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.LEGACY)
@Config(sdk = [35])
class ChatScreenTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private fun setContent(uiState: ChatUiState = ChatUiState()) {
        composeTestRule.setContent {
            com.omnia.designsystem.theme.OmniaTheme {
                ChatScreen(
                    uiState = uiState,
                    onOpenProviders = {},
                    onOpenSettings = {},
                )
            }
        }
    }

    @Test
    fun emptyState_showsPlaceholder() {
        setContent()

        composeTestRule.onNodeWithText("No conversation yet").assertIsDisplayed()
        composeTestRule.onNodeWithText("Start a conversation to begin chatting.").assertIsDisplayed()
    }

    @Test
    fun topBar_exposesNavigationActions() {
        setContent()

        composeTestRule.onNodeWithContentDescription("Open providers").assertIsDisplayed()
        composeTestRule.onNodeWithContentDescription("Open settings").assertIsDisplayed()
    }
}
