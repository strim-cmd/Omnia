package com.omnia.feature.chat

import com.omnia.domain.ConversationIdentity
import com.omnia.domain.Message
import com.omnia.domain.ModelReference
import com.omnia.domain.ProviderModelSelection

data class ChatUiState(
    val conversations: List<ConversationListItem> = emptyList(),
    val activeConversation: ConversationIdentity? = null,
    val messages: List<Message> = emptyList(),
    val partialContent: String? = null,
    val isStreaming: Boolean = false,
    val composerText: String = "",
    val isComposerEnabled: Boolean = true,
    val title: String = "",
    val currentModel: ProviderModelSelection? = null,
    val availableModels: List<ModelReference> = emptyList(),
    val error: String? = null,
    val isSearching: Boolean = false,
    val searchQuery: String = "",
    val searchResults: List<ConversationListItem> = emptyList(),
    val isRenaming: Boolean = false,
    val renameText: String = "",
    val showConversationList: Boolean = true,
    val showStopButton: Boolean = false,
    val isInterrupted: Boolean = false,
) {
    data class ConversationListItem(
        val id: String,
        val title: String,
        val lastMessage: String,
        val updatedAt: Long,
        val isActive: Boolean,
    )
}
