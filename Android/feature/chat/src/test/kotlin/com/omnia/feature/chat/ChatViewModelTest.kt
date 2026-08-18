package com.omnia.feature.chat

import com.omnia.application.ConversationDraftService
import com.omnia.application.ConversationGenerationCoordinator
import com.omnia.application.ConversationService
import com.omnia.application.ProviderModelService
import com.omnia.application.SendMessageUseCase
import com.omnia.common.NoOpLogger
import com.omnia.common.RecordingLogger
import com.omnia.common.SingleDispatcherProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class ChatViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private fun buildGenerationCoordinator() =
        ConversationGenerationCoordinator(SingleDispatcherProvider(mainDispatcherRule.testDispatcher))

    private fun testDependencies(logger: com.omnia.common.Logger = NoOpLogger()) =
        object : ChatDependencies {
            override val logger = logger
            override val dispatchers = SingleDispatcherProvider(mainDispatcherRule.testDispatcher)
            override val conversationService get() = throw NotImplementedError()
            override val conversationDraftService get() = throw NotImplementedError()
            override val conversationGenerationCoordinator get() = throw NotImplementedError()
            override val providerModelService get() = throw NotImplementedError()
            override val sendMessageUseCase get() = throw NotImplementedError()
            override val attachmentService get() = throw NotImplementedError()
        }

    @Test
    fun initial_state_isEmptyShell() {
        val viewModel = ChatViewModel(
            dependencies = testDependencies(),
            generationCoordinator = buildGenerationCoordinator(),
        )

        assertEquals(ChatUiState(), viewModel.uiState.value)
    }

    @Test
    fun open_logsCoarseEventOnly() {
        val logger = RecordingLogger()
        ChatViewModel(
            dependencies = testDependencies(logger),
            generationCoordinator = buildGenerationCoordinator(),
        )

        assertTrue(logger.entries.isNotEmpty())
        assertEquals("Chat destination opened", logger.entries.first().message)
        assertEquals("ChatViewModel", logger.entries.first().tag)
    }
}
