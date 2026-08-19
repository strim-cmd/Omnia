package com.omnia.feature.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.omnia.application.AttachmentImportCandidate
import com.omnia.application.ConversationGenerationCoordinator
import com.omnia.application.GenerationState
import com.omnia.application.SendMessageRequest
import com.omnia.domain.ConversationIdentity
import com.omnia.domain.Message
import com.omnia.domain.MessageRole
import com.omnia.domain.ProviderModelSelection
import com.omnia.domain.StreamingUpdate
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class ChatViewModel(
    private val dependencies: ChatDependencies,
    private val generationCoordinator: ConversationGenerationCoordinator,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ChatUiState())
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()

    private var streamingJob: Job? = null

    init {
        viewModelScope.launch(dependencies.dispatchers.default) {
            dependencies.logger.info(TAG, "Chat destination opened")
            loadConversations()
        }
    }

    fun loadConversations() {
        viewModelScope.launch(dependencies.dispatchers.default) {
            try {
                val conversations = dependencies.conversationService.conversations()
                val items = conversations.map { conversation ->
                    val lastMessage = conversation.history.lastOrNull { it.role != MessageRole.system }
                    ChatUiState.ConversationListItem(
                        id = conversation.identity.id,
                        title = conversation.title ?: "Untitled",
                        lastMessage = lastMessage?.content ?: "",
                        updatedAt = conversation.updatedAtEpochMillis,
                        isActive = conversation.identity == _uiState.value.activeConversation,
                    )
                }
                _uiState.update { state ->
                    state.copy(conversations = items)
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.message ?: "Failed to load conversations") }
            }
        }
    }

    fun openConversation(identity: ConversationIdentity) {
        viewModelScope.launch(dependencies.dispatchers.default) {
            try {
                val conversation = dependencies.conversationService.getConversation(identity)
                if (conversation == null) {
                    _uiState.update { it.copy(error = "Conversation not found") }
                    return@launch
                }

                val draft = try {
                    dependencies.conversationDraftService.draft(identity)
                } catch (_: Exception) {
                    ""
                }

                val models = try {
                    val catalog = dependencies.providerModelService.cachedCatalog(
                        conversation.modelSelection?.provider
                            ?: com.omnia.domain.ProviderIdentity(id = "default")
                    )
                    catalog.models
                } catch (_: Exception) {
                    emptyList()
                }

                val genState = generationCoordinator.generationState(identity)
                val isStreaming = genState is GenerationState.Streaming
                val partialContent = (genState as? GenerationState.Streaming)?.partialContent

                _uiState.update { state ->
                    state.copy(
                        activeConversation = identity,
                        messages = conversation.history,
                        partialContent = partialContent,
                        isStreaming = isStreaming,
                        composerText = draft,
                        title = conversation.title ?: "Untitled",
                        currentModel = conversation.modelSelection,
                        availableModels = models,
                        showConversationList = false,
                        showStopButton = isStreaming,
                        isInterrupted = conversation.isInterrupted,
                    )
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.message ?: "Failed to open conversation") }
            }
        }
    }

    fun createConversation() {
        viewModelScope.launch(dependencies.dispatchers.default) {
            try {
                val conversation = dependencies.conversationService.createConversation()
                loadConversations()
                openConversation(conversation.identity)
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.message ?: "Failed to create conversation") }
            }
        }
    }

    fun deleteConversation(identity: ConversationIdentity) {
        viewModelScope.launch(dependencies.dispatchers.default) {
            try {
                dependencies.conversationService.delete(identity)
                generationCoordinator.cleanup(identity)
                if (_uiState.value.activeConversation == identity) {
                    _uiState.update {
                        it.copy(
                            activeConversation = null,
                            showConversationList = true,
                            messages = emptyList(),
                            partialContent = null,
                            isStreaming = false,
                        )
                    }
                }
                loadConversations()
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.message ?: "Failed to delete conversation") }
            }
        }
    }

    fun renameConversation(name: String, identity: ConversationIdentity) {
        viewModelScope.launch(dependencies.dispatchers.default) {
            try {
                val conversation = dependencies.conversationService.rename(name, identity)
                if (identity == _uiState.value.activeConversation) {
                    _uiState.update { it.copy(title = conversation.title ?: name) }
                }
                loadConversations()
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.message ?: "Failed to rename conversation") }
            }
        }
    }

    fun updateComposerText(text: String) {
        val identity = _uiState.value.activeConversation ?: return
        _uiState.update { it.copy(composerText = text) }
        viewModelScope.launch(dependencies.dispatchers.default) {
            try {
                dependencies.conversationDraftService.save(text, identity)
            } catch (_: Exception) {
            }
        }
    }

    fun sendMessage() {
        val state = _uiState.value
        val identity = state.activeConversation ?: return
        val text = state.composerText.trim()
        if (text.isEmpty() && state.draftAttachments.isEmpty()) return

        val userMessage = Message(
            role = MessageRole.user,
            content = text,
            attachments = state.draftAttachments,
        )

        _uiState.update {
            it.copy(
                composerText = "",
                draftAttachments = emptyList(),
                attachmentIssue = null,
                isStreaming = true,
                showStopButton = true,
                isComposerEnabled = false,
            )
        }

        viewModelScope.launch(dependencies.dispatchers.default) {
            try {
                dependencies.conversationDraftService.remove(identity)
            } catch (_: Exception) {
            }
        }

        streamingJob = generationCoordinator.startGeneration(identity) { _ ->
            try {
                val request = SendMessageRequest(
                    conversation = identity,
                    message = userMessage,
                    modelSelection = state.currentModel,
                )

                dependencies.sendMessageUseCase.send(request).collect { update ->
                    when (update) {
                        is StreamingUpdate.ContentDelta -> {
                            _uiState.update { s ->
                                s.copy(
                                    partialContent = (s.partialContent ?: "") + update.content,
                                )
                            }
                        }
                        is StreamingUpdate.Completion -> {
                            refreshConversation(identity)
                            _uiState.update { s ->
                                s.copy(
                                    partialContent = null,
                                    isStreaming = false,
                                    showStopButton = false,
                                    isComposerEnabled = true,
                                )
                            }
                        }
                        is StreamingUpdate.Interruption -> {
                            refreshConversation(identity)
                            _uiState.update { s ->
                                s.copy(
                                    partialContent = null,
                                    isStreaming = false,
                                    showStopButton = false,
                                    isComposerEnabled = true,
                                )
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                if (e is kotlinx.coroutines.CancellationException) throw e
                _uiState.update { s ->
                    s.copy(
                        partialContent = null,
                        isStreaming = false,
                        showStopButton = false,
                        isComposerEnabled = true,
                        error = e.message ?: "Generation failed",
                    )
                }
            }
        }
    }

    fun stageAttachments(candidates: List<AttachmentImportCandidate>) {
        val state = _uiState.value
        viewModelScope.launch(dependencies.dispatchers.default) {
            try {
                val staged = dependencies.attachmentService.stage(
                    candidates = candidates,
                    existing = state.draftAttachments,
                )
                _uiState.update {
                    it.copy(
                        draftAttachments = it.draftAttachments + staged,
                        attachmentIssue = null,
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(attachmentIssue = e.message ?: "Failed to add attachment")
                }
            }
        }
    }

    fun removeAttachment(attachment: com.omnia.domain.MessageAttachment) {
        _uiState.update {
            it.copy(draftAttachments = it.draftAttachments.filter { a -> a.identity != attachment.identity })
        }
        viewModelScope.launch(dependencies.dispatchers.default) {
            try { dependencies.attachmentService.remove(attachment) } catch (_: Exception) { }
        }
    }

    fun dismissAttachmentIssue() {
        _uiState.update { it.copy(attachmentIssue = null) }
    }

    fun stopGeneration() {
        val identity = _uiState.value.activeConversation ?: return
        generationCoordinator.stopGeneration(identity)
        streamingJob?.cancel()
        streamingJob = null
        viewModelScope.launch(dependencies.dispatchers.default) {
            refreshConversation(identity)
            _uiState.update { s ->
                s.copy(
                    partialContent = null,
                    isStreaming = false,
                    showStopButton = false,
                    isComposerEnabled = true,
                )
            }
        }
    }

    fun retryGeneration() {
        val state = _uiState.value
        val identity = state.activeConversation ?: return
        val lastUserMessage = state.messages.lastOrNull { it.role == MessageRole.user }
        if (lastUserMessage != null) {
            _uiState.update { it.copy(composerText = lastUserMessage.content) }
            sendMessage()
        }
    }

    fun continueGeneration() {
        val identity = _uiState.value.activeConversation ?: return

        _uiState.update {
            it.copy(
                isStreaming = true,
                showStopButton = true,
                isComposerEnabled = false,
            )
        }

        streamingJob = generationCoordinator.startGeneration(identity) { _ ->
            try {
                dependencies.sendMessageUseCase.resume(identity).collect { update ->
                    when (update) {
                        is StreamingUpdate.ContentDelta -> {
                            _uiState.update { s ->
                                s.copy(
                                    partialContent = (s.partialContent ?: "") + update.content,
                                )
                            }
                        }
                        is StreamingUpdate.Completion -> {
                            refreshConversation(identity)
                            _uiState.update { s ->
                                s.copy(
                                    partialContent = null,
                                    isStreaming = false,
                                    showStopButton = false,
                                    isComposerEnabled = true,
                                )
                            }
                        }
                        is StreamingUpdate.Interruption -> {
                            refreshConversation(identity)
                            _uiState.update { s ->
                                s.copy(
                                    partialContent = null,
                                    isStreaming = false,
                                    showStopButton = false,
                                    isComposerEnabled = true,
                                )
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                if (e is kotlinx.coroutines.CancellationException) throw e
                _uiState.update { s ->
                    s.copy(
                        partialContent = null,
                        isStreaming = false,
                        showStopButton = false,
                        isComposerEnabled = true,
                        error = e.message ?: "Resume failed",
                    )
                }
            }
        }
    }

    fun selectModel(selection: ProviderModelSelection) {
        val identity = _uiState.value.activeConversation ?: return
        viewModelScope.launch(dependencies.dispatchers.default) {
            try {
                val conversation = dependencies.conversationService.selectModel(selection, identity)
                _uiState.update { it.copy(currentModel = conversation.modelSelection) }
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.message ?: "Failed to select model") }
            }
        }
    }

    fun startSearch(query: String) {
        val normalized = query.trim()
        if (normalized.isEmpty()) {
            clearSearch()
            return
        }
        val results = _uiState.value.conversations.filter { item ->
            item.title.contains(normalized, ignoreCase = true) ||
                item.lastMessage.contains(normalized, ignoreCase = true)
        }
        _uiState.update {
            it.copy(
                isSearching = true,
                searchQuery = normalized,
                searchResults = results,
            )
        }
    }

    fun clearSearch() {
        _uiState.update {
            it.copy(
                isSearching = false,
                searchQuery = "",
                searchResults = emptyList(),
            )
        }
    }

    fun startRename() {
        val state = _uiState.value
        val identity = state.activeConversation ?: return
        viewModelScope.launch(dependencies.dispatchers.default) {
            try {
                val conversation = dependencies.conversationService.getConversation(identity)
                val currentTitle = conversation?.title ?: ""
                _uiState.update {
                    it.copy(
                        isRenaming = true,
                        renameText = currentTitle,
                    )
                }
            } catch (_: Exception) {
                _uiState.update {
                    it.copy(
                        isRenaming = true,
                        renameText = state.title,
                    )
                }
            }
        }
    }

    fun updateRenameText(text: String) {
        _uiState.update { it.copy(renameText = text) }
    }

    fun confirmRename() {
        val state = _uiState.value
        val identity = state.activeConversation ?: return
        val name = state.renameText.trim()
        if (name.isEmpty()) {
            _uiState.update { it.copy(isRenaming = false, renameText = "") }
            return
        }
        renameConversation(name, identity)
        _uiState.update { it.copy(isRenaming = false, renameText = "") }
    }

    fun dismissRename() {
        _uiState.update { it.copy(isRenaming = false, renameText = "") }
    }

    fun dismissError() {
        _uiState.update { it.copy(error = null) }
    }

    fun backToList() {
        val identity = _uiState.value.activeConversation
        if (identity != null && generationCoordinator.isGenerating(identity)) {
            generationCoordinator.stopGeneration(identity)
            streamingJob?.cancel()
            streamingJob = null
        }
        _uiState.update {
            it.copy(
                activeConversation = null,
                showConversationList = true,
                messages = emptyList(),
                partialContent = null,
                isStreaming = false,
                showStopButton = false,
                isComposerEnabled = true,
                composerText = "",
            )
        }
        loadConversations()
    }

    override fun onCleared() {
        super.onCleared()
        val identity = _uiState.value.activeConversation
        if (identity != null) {
            generationCoordinator.stopGeneration(identity)
        }
        streamingJob?.cancel()
    }

    private suspend fun refreshConversation(identity: ConversationIdentity) {
        try {
            val conversation = dependencies.conversationService.getConversation(identity)
            if (conversation != null) {
                val genState = generationCoordinator.generationState(identity)
                val isStreaming = genState is GenerationState.Streaming
                val partialContent = (genState as? GenerationState.Streaming)?.partialContent
                _uiState.update { s ->
                    s.copy(
                        messages = conversation.history,
                        partialContent = partialContent,
                        isStreaming = isStreaming,
                        title = conversation.title ?: s.title,
                        currentModel = conversation.modelSelection,
                        isInterrupted = conversation.isInterrupted,
                    )
                }
            }
        } catch (_: Exception) {
        }
    }

    private companion object {
        const val TAG = "ChatViewModel"
    }
}
