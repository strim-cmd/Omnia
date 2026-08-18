package com.omnia.feature.chat

import com.omnia.common.DispatcherProvider
import com.omnia.common.Logger
import com.omnia.application.ConversationService
import com.omnia.application.ConversationDraftService
import com.omnia.application.ConversationGenerationCoordinator
import com.omnia.application.ProviderModelService
import com.omnia.application.SendMessageUseCase

/**
 * Dependencies the Chat feature needs, declared by the feature and satisfied by
 * the app's composition root (AppContainer). The feature never reaches into the
 * app layer.
 */
interface ChatDependencies {
    val logger: Logger
    val dispatchers: DispatcherProvider
    val conversationService: ConversationService
    val conversationDraftService: ConversationDraftService
    val conversationGenerationCoordinator: ConversationGenerationCoordinator
    val providerModelService: ProviderModelService
    val sendMessageUseCase: SendMessageUseCase
}
