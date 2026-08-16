package com.omnia.feature.chat

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

    @Test
    fun initial_state_isEmptyShell() {
        val viewModel = ChatViewModel(
            dependencies = object : ChatDependencies {
                override val logger = NoOpLogger()
                override val dispatchers = SingleDispatcherProvider(mainDispatcherRule.testDispatcher)
            },
        )

        assertEquals(ChatUiState(), viewModel.uiState.value)
    }

    @Test
    fun open_logsCoarseEventOnly() {
        val logger = RecordingLogger()
        ChatViewModel(
            dependencies = object : ChatDependencies {
                override val logger = logger
                override val dispatchers = SingleDispatcherProvider(mainDispatcherRule.testDispatcher)
            },
        )

        assertTrue(logger.entries.isNotEmpty())
        assertEquals("Chat destination opened", logger.entries.first().message)
        assertEquals("ChatViewModel", logger.entries.first().tag)
    }
}
