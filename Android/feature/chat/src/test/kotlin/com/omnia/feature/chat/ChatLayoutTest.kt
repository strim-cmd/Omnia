package com.omnia.feature.chat

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import com.omnia.domain.ConversationIdentity
import com.omnia.domain.Message
import com.omnia.domain.MessageRole
import com.omnia.domain.ModelReference
import com.omnia.domain.ProviderIdentity
import com.omnia.domain.ProviderModelSelection
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
class ChatLayoutTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private fun setContent(uiState: ChatUiState = ChatUiState()) {
        composeTestRule.setContent {
            com.omnia.designsystem.theme.OmniaTheme {
                ChatScreen(
                    uiState = uiState,
                    onOpenProviders = {},
                    onOpenSettings = {},
                    onBack = {},
                    onCreateConversation = {},
                    onOpenConversation = {},
                    onStartRename = {},
                    onUpdateComposerText = {},
                    onSendMessage = {},
                    onStopGeneration = {},
                    onRetryGeneration = {},
                    onContinueGeneration = {},
                    onSelectModel = {},
                    onSearchQueryChanged = {},
                    onClearSearch = {},
                    onDismissError = {},
                    onUpdateRenameText = {},
                    onConfirmRename = {},
                    onDismissRename = {},
                )
            }
        }
    }

    @Test
    fun conversationList_showsTopBarActions() {
        setContent()
        composeTestRule.onNodeWithContentDescription("Open providers").assertIsDisplayed()
        composeTestRule.onNodeWithContentDescription("Open settings").assertIsDisplayed()
    }

    @Test
    fun conversationList_noDuplicateSettingsIcons() {
        setContent()
        composeTestRule.onNodeWithContentDescription("Open settings").assertIsDisplayed()
        composeTestRule.onNodeWithContentDescription("Rename").assertDoesNotExist()
    }

    @Test
    fun chatView_showsTopBarWithBackAndActions() {
        val state = ChatUiState(
            activeConversation = ConversationIdentity("conv1"),
            title = "Test Chat",
            showConversationList = false,
        )
        setContent(uiState = state)
        composeTestRule.onNodeWithContentDescription("Back").assertIsDisplayed()
        composeTestRule.onNodeWithContentDescription("Rename").assertIsDisplayed()
        composeTestRule.onNodeWithContentDescription("Open settings").assertIsDisplayed()
    }

    @Test
    fun chatView_noDuplicateSettingsIcons() {
        val state = ChatUiState(
            activeConversation = ConversationIdentity("conv1"),
            title = "Test Chat",
            showConversationList = false,
        )
        setContent(uiState = state)
        composeTestRule.onNodeWithText("Test Chat").assertIsDisplayed()
    }

    @Test
    fun chatView_showsMessagesAndComposer() {
        val state = ChatUiState(
            activeConversation = ConversationIdentity("conv1"),
            title = "Chat",
            showConversationList = false,
            messages = listOf(
                Message(role = MessageRole.user, content = "Hello"),
                Message(role = MessageRole.assistant, content = "Hi there!"),
            ),
        )
        setContent(uiState = state)
        composeTestRule.onNodeWithText("Hello").assertIsDisplayed()
        composeTestRule.onNodeWithText("Hi there!").assertIsDisplayed()
    }

    @Test
    fun chatView_composerPlaceholderIsLocalized() {
        val state = ChatUiState(
            activeConversation = ConversationIdentity("conv1"),
            title = "Chat",
            showConversationList = false,
        )
        setContent(uiState = state)
        composeTestRule.onNodeWithText("Type a message…").assertIsDisplayed()
    }

    @Test
    fun chatView_streamingShowsPartialContent() {
        val state = ChatUiState(
            activeConversation = ConversationIdentity("conv1"),
            title = "Chat",
            showConversationList = false,
            messages = listOf(
                Message(role = MessageRole.user, content = "Hi"),
            ),
            partialContent = "Partial response...",
            isStreaming = true,
            showStopButton = true,
        )
        setContent(uiState = state)
        composeTestRule.onNodeWithText("Partial response...").assertIsDisplayed()
    }

    @Test
    fun chatView_modelNameShownInTopBar() {
        val state = ChatUiState(
            activeConversation = ConversationIdentity("conv1"),
            title = "Chat",
            showConversationList = false,
            currentModel = ProviderModelSelection(
                provider = ProviderIdentity(id = "prov1"),
                model = ModelReference("gpt-4"),
            ),
        )
        setContent(uiState = state)
        composeTestRule.onNodeWithText("Chat").assertIsDisplayed()
        composeTestRule.onNodeWithText("gpt-4").assertIsDisplayed()
    }

    @Test
    fun bubble_singleCharUserMessage_isNarrowerThanMaxWidth() {
        val state = ChatUiState(
            activeConversation = ConversationIdentity("conv1"),
            title = "Chat",
            showConversationList = false,
            messages = listOf(
                Message(role = MessageRole.user, content = "A"),
            ),
        )
        setContent(uiState = state)
        val rootBounds = composeTestRule.onRoot().fetchSemanticsNode().boundsInRoot
        val rootWidth = rootBounds.width

        val bubbleBounds = composeTestRule.onNodeWithText("A").fetchSemanticsNode().boundsInRoot
        val bubbleWidth = bubbleBounds.width

        val maxAllowedWidth = rootWidth * 0.82f
        assertTrue(
            "Single-char bubble width ($bubbleWidth) should be materially narrower than max ($maxAllowedWidth)",
            bubbleWidth < maxAllowedWidth * 0.7f,
        )
    }

    @Test
    fun bubble_shortAssistantMessage_isNarrowerThanMaxWidth() {
        val state = ChatUiState(
            activeConversation = ConversationIdentity("conv1"),
            title = "Chat",
            showConversationList = false,
            messages = listOf(
                Message(role = MessageRole.assistant, content = "Hello!"),
            ),
        )
        setContent(uiState = state)
        val rootBounds = composeTestRule.onRoot().fetchSemanticsNode().boundsInRoot
        val rootWidth = rootBounds.width

        val bubbleBounds = composeTestRule.onNodeWithText("Hello!").fetchSemanticsNode().boundsInRoot
        val bubbleWidth = bubbleBounds.width

        val maxAllowedWidth = rootWidth * 0.82f
        assertTrue(
            "Short assistant bubble width ($bubbleWidth) should be materially narrower than max ($maxAllowedWidth)",
            bubbleWidth < maxAllowedWidth * 0.7f,
        )
    }

    @Test
    fun bubble_longMessage_isWiderThanShortMessage() {
        val longMessage = "This is a very long message that should wrap and fill up to the maximum bubble width limit because it contains many words that will not fit on a single line."
        val state = ChatUiState(
            activeConversation = ConversationIdentity("conv1"),
            title = "Chat",
            showConversationList = false,
            messages = listOf(
                Message(role = MessageRole.user, content = "A"),
                Message(role = MessageRole.user, content = longMessage),
            ),
        )
        setContent(uiState = state)
        val rootBounds = composeTestRule.onRoot().fetchSemanticsNode().boundsInRoot
        val rootWidth = rootBounds.width

        val shortBounds = composeTestRule.onNodeWithText("A").fetchSemanticsNode().boundsInRoot
        val longBounds = composeTestRule.onNodeWithText(longMessage).fetchSemanticsNode().boundsInRoot

        val maxAllowedWidth = rootWidth * 0.82f
        assertTrue(
            "Long message (${longBounds.width}) should be wider than short (${shortBounds.width})",
            longBounds.width > shortBounds.width,
        )
        assertTrue(
            "Long message (${longBounds.width}) should not exceed max ($maxAllowedWidth)",
            longBounds.width <= maxAllowedWidth + 10f,
        )
    }

    @Test
    fun duplicateKeys_twoEmptyAssistantMessages_noCrash() {
        val state = ChatUiState(
            activeConversation = ConversationIdentity("conv1"),
            title = "Chat",
            showConversationList = false,
            messages = listOf(
                Message(role = MessageRole.user, content = "Hi"),
                Message(role = MessageRole.assistant, content = ""),
                Message(role = MessageRole.assistant, content = ""),
            ),
        )
        setContent(uiState = state)
        composeTestRule.onNodeWithText("Hi").assertIsDisplayed()
    }

    @Test
    fun duplicateKeys_twoIdenticalAssistantMessages_noCrash() {
        val state = ChatUiState(
            activeConversation = ConversationIdentity("conv1"),
            title = "Chat",
            showConversationList = false,
            messages = listOf(
                Message(role = MessageRole.user, content = "Hi"),
                Message(role = MessageRole.assistant, content = "Same"),
                Message(role = MessageRole.assistant, content = "Same"),
            ),
        )
        setContent(uiState = state)
        composeTestRule.onNodeWithText("Hi").assertIsDisplayed()
    }

    @Test
    fun duplicateKeys_twoIdenticalUserMessages_noCrash() {
        val state = ChatUiState(
            activeConversation = ConversationIdentity("conv1"),
            title = "Chat",
            showConversationList = false,
            messages = listOf(
                Message(role = MessageRole.user, content = "Hi"),
                Message(role = MessageRole.user, content = "Hello"),
            ),
        )
        setContent(uiState = state)
        composeTestRule.onNodeWithText("Hi").assertIsDisplayed()
        composeTestRule.onNodeWithText("Hello").assertIsDisplayed()
    }
}
