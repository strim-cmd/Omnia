package com.omnia.feature.providers

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
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
class ProvidersScreenTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private fun setContent(uiState: ProvidersUiState = ProvidersUiState()) {
        composeTestRule.setContent {
            com.omnia.designsystem.theme.OmniaTheme {
                ProvidersScreen(
                    uiState = uiState,
                    onBack = {},
                    onAddProvider = {},
                )
            }
        }
    }

    @Test
    fun emptyState_showsPlaceholderAndDisabledAdd() {
        setContent()

        composeTestRule.onNodeWithText("No providers configured").assertIsDisplayed()
        composeTestRule.onNodeWithText("Add provider").assertIsDisplayed()
        composeTestRule.onNodeWithText("Add provider").assertIsNotEnabled()
    }

    @Test
    fun topBar_showsBackAction() {
        setContent()

        composeTestRule.onNodeWithContentDescription("Back").assertIsDisplayed()
    }
}
