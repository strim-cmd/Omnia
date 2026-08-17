package com.omnia.application

import com.omnia.domain.Capability
import com.omnia.domain.CapabilityRequestIdentity
import com.omnia.domain.Conversation
import com.omnia.domain.ConversationIdentity
import com.omnia.domain.ConversationRepository
import com.omnia.domain.Message
import com.omnia.domain.ProviderCandidate
import com.omnia.domain.ProviderModelSelection
import com.omnia.domain.ProviderSelectionPolicy
import com.omnia.domain.ProviderSelectionResult
import com.omnia.domain.ResolvedAttachment
import com.omnia.domain.StreamingContract
import com.omnia.domain.StreamingRequest
import com.omnia.domain.StreamingUpdate
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.onCompletion
import kotlinx.coroutines.flow.onEach

class SendMessageUseCase(
    private val streamingContract: StreamingContract,
    private val selectionPolicy: ProviderSelectionPolicy,
    private val conversationRepository: ConversationRepository,
    private val candidatesFor: suspend (capability: Capability) -> List<ProviderCandidate> = { emptyList() },
    private val resolveAttachments: suspend (List<Message>, ProviderModelSelection) -> List<ResolvedAttachment> = { _, _ -> emptyList() },
    private val now: () -> Long = { System.currentTimeMillis() },
) {
    suspend fun send(request: SendMessageRequest): Flow<StreamingUpdate> {
        val validatedRequest = validateRequest(request)
        val (conversation, selection) = prepareSend(validatedRequest)
        return consume(conversation, selection)
    }

    suspend fun resume(conversationIdentity: ConversationIdentity): Flow<StreamingUpdate> {
        val conversation = loadConversation(conversationIdentity)
        require(conversation.isInterrupted) { "Conversation is not in interrupted state" }
        val selection = resolveSelection(conversation, null)
        val prepared = prepareResume(conversation)
        return consume(prepared, selection)
    }

    private fun validateRequest(request: SendMessageRequest): SendMessageRequest {
        val hasContent = request.message.content.isNotBlank()
        val hasAttachments = request.message.attachments.isNotEmpty()
        require(hasContent || hasAttachments) {
            throw ApplicationValidationError.Invalid("Message must have content or attachments")
        }
        return request
    }

    private suspend fun loadConversation(identity: ConversationIdentity): Conversation {
        return conversationRepository.conversation(identity)
            ?: throw ApplicationValidationError.Invalid("Conversation not found: ${identity.id}")
    }

    private suspend fun resolveSelection(
        conversation: Conversation,
        explicitSelection: ProviderModelSelection?,
    ): ProviderModelSelection {
        val candidates = candidatesFor(Capability.streaming)
        val result = selectionPolicy.select(
            candidates = candidates,
            explicitSelection = explicitSelection ?: conversation.modelSelection,
        )
        return when (result) {
            is ProviderSelectionResult.Selected -> ProviderModelSelection(
                provider = result.provider,
                model = result.model,
            )
            is ProviderSelectionResult.ModelUnavailable -> {
                throw com.omnia.domain.CapabilityError.ModelUnavailable(result.selection.model)
            }
            is ProviderSelectionResult.Failure -> {
                throw com.omnia.domain.CapabilityError.ProviderUnavailable
            }
        }
    }

    private suspend fun prepareSend(request: SendMessageRequest): Pair<Conversation, ProviderModelSelection> {
        val conversation = loadConversation(request.conversation)
        val selection = resolveSelection(conversation, request.modelSelection)
        val updated = conversation.append(request.message, timestampMillis = now())
        conversationRepository.save(updated)
        return updated to selection
    }

    private suspend fun prepareResume(conversation: Conversation): Conversation {
        val streaming = conversation.beginStreaming()
        conversationRepository.save(streaming)
        return streaming
    }

    private suspend fun consume(
        conversation: Conversation,
        selection: ProviderModelSelection,
    ): Flow<StreamingUpdate> {
        val resolvedAttachments = try {
            resolveAttachments(conversation.history, selection)
        } catch (_: Exception) {
            emptyList()
        }

        val requestId = CapabilityRequestIdentity(id = generateId())

        val streamingRequest = StreamingRequest(
            identity = requestId,
            history = conversation.history,
            model = selection.model,
            provider = selection.provider,
            resolvedAttachments = resolvedAttachments,
        )

        var currentConversation = conversation
        var hasReceivedTerminal = false

        return streamingContract.stream(streamingRequest)
            .onEach { update ->
                when (update) {
                    is StreamingUpdate.ContentDelta -> {
                        if (update.identity == requestId) {
                            currentConversation = currentConversation.appendPartial(update.content)
                            conversationRepository.save(currentConversation)
                        }
                    }
                    is StreamingUpdate.Completion -> {
                        if (update.identity == requestId && !hasReceivedTerminal) {
                            hasReceivedTerminal = true
                            val delta = reconcilePartial(
                                currentConversation.partialContent ?: "",
                                update.message.content,
                            )
                            if (delta.isNotEmpty()) {
                                currentConversation = currentConversation.appendPartial(delta)
                            }
                            currentConversation = currentConversation.completeStreaming(timestampMillis = now())
                            savePreservingMetadata(currentConversation)
                        }
                    }
                    is StreamingUpdate.Interruption -> {
                        if (update.identity == requestId && !hasReceivedTerminal) {
                            hasReceivedTerminal = true
                            val delta = reconcilePartial(
                                currentConversation.partialContent ?: "",
                                update.partialContent,
                            )
                            if (delta.isNotEmpty()) {
                                currentConversation = currentConversation.appendPartial(delta)
                            }
                            currentConversation = currentConversation.interruptStreaming()
                            savePreservingMetadata(currentConversation)
                        }
                    }
                }
            }
            .onCompletion { cause ->
                if (!hasReceivedTerminal) {
                    val partial = currentConversation.partialContent
                    if (!partial.isNullOrEmpty()) {
                        currentConversation = currentConversation.interruptStreaming()
                        savePreservingMetadata(currentConversation)
                    }
                }
            }
    }

    private suspend fun savePreservingMetadata(conversation: Conversation) {
        val stored = conversationRepository.conversation(conversation.identity)
        if (stored != null) {
            conversationRepository.save(conversation.mergeMetadata(stored))
        } else {
            conversationRepository.save(conversation)
        }
    }

    private fun reconcilePartial(accumulated: String, incoming: String): String {
        if (incoming.isEmpty()) return ""
        if (accumulated.isEmpty()) return incoming
        if (incoming.startsWith(accumulated)) {
            return incoming.substring(accumulated.length)
        }
        return ""
    }

    private fun generateId(): String = java.util.UUID.randomUUID().toString()
}
