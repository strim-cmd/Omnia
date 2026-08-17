package com.omnia.application

import com.omnia.domain.ConfigurationKey
import com.omnia.domain.ConversationIdentity

class ConversationDraftService(
    private val configurationService: ConfigurationService,
) {
    suspend fun draft(conversation: ConversationIdentity): String =
        configurationService.resolved(key(conversation)) ?: ""

    suspend fun save(text: String, conversation: ConversationIdentity) {
        if (text.isBlank()) {
            configurationService.remove(key(conversation), DRAFT_LEVEL)
        } else {
            configurationService.store(text, key(conversation), DRAFT_LEVEL)
        }
    }

    suspend fun remove(conversation: ConversationIdentity) {
        configurationService.remove(key(conversation), DRAFT_LEVEL)
    }

    companion object {
        private val DRAFT_LEVEL = com.omnia.domain.ConfigurationLevel.workspaceOverride

        fun key(conversation: ConversationIdentity): ConfigurationKey<String> =
            ConfigurationKey("conversationDraft.${conversation.id}")
    }
}
