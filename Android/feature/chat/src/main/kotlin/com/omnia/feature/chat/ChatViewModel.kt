package com.omnia.feature.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.omnia.common.DispatcherProvider
import com.omnia.common.Logger
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Backs the Chat destination. The M1 shell exposes a single immutable
 * [ChatUiState]; real conversation state transitions arrive with the message
 * pipeline in later milestones.
 */
class ChatViewModel(private val dependencies: ChatDependencies) : ViewModel() {

    private val _uiState = MutableStateFlow(ChatUiState())
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch(dependencies.dispatchers.default) {
            dependencies.logger.info(TAG, "Chat destination opened")
        }
    }

    private companion object {
        const val TAG = "ChatViewModel"
    }
}
