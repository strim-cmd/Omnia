package com.omnia.application

import com.omnia.common.DispatcherProvider
import com.omnia.domain.CapabilityRequestIdentity
import com.omnia.domain.ConversationIdentity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

sealed class GenerationState {
    data object Idle : GenerationState()
    data class Streaming(
        val partialContent: String,
        val requestId: CapabilityRequestIdentity,
    ) : GenerationState()
    data class Failed(val error: String) : GenerationState()
}

data class GenerationContext(
    val requestId: CapabilityRequestIdentity,
    val conversationIdentity: ConversationIdentity,
)

class ConversationGenerationCoordinator(private val dispatchers: DispatcherProvider) {

    private val scope = CoroutineScope(dispatchers.default)
    private val mutex = Mutex()
    private val jobs = mutableMapOf<ConversationIdentity, Job>()

    private val _activeGenerations = MutableStateFlow<Map<ConversationIdentity, GenerationState>>(
        emptyMap()
    )
    val activeGenerations: StateFlow<Map<ConversationIdentity, GenerationState>> =
        _activeGenerations.asStateFlow()

    fun startGeneration(
        identity: ConversationIdentity,
        block: suspend (GenerationContext) -> Unit,
    ): Job {
        val requestId = CapabilityRequestIdentity(id = java.util.UUID.randomUUID().toString())
        val context = GenerationContext(
            requestId = requestId,
            conversationIdentity = identity,
        )

        val job = scope.launch {
            try {
                updateGeneration(identity, GenerationState.Streaming("", requestId))
                block(context)
                onTerminal(identity, GenerationState.Idle)
            } catch (e: Exception) {
                if (e is kotlinx.coroutines.CancellationException) {
                    onTerminal(identity, GenerationState.Idle)
                } else {
                    onTerminal(identity, GenerationState.Failed(e.message ?: "Generation failed"))
                }
            }
        }

        synchronized(jobs) {
            jobs[identity]?.cancel()
            jobs[identity] = job
        }

        return job
    }

    fun stopGeneration(identity: ConversationIdentity) {
        val captured: Job?
        synchronized(jobs) { captured = jobs[identity] }
        captured?.cancel()
        synchronized(jobs) {
            val current = jobs[identity]
            if (current != null && current === captured) {
                jobs.remove(identity)
            }
        }
        updateGeneration(identity, GenerationState.Idle)
    }

    fun isGenerating(identity: ConversationIdentity): Boolean {
        val state = _activeGenerations.value[identity]
        return state is GenerationState.Streaming
    }

    fun cleanup(identity: ConversationIdentity) {
        val captured: Job?
        synchronized(jobs) { captured = jobs.remove(identity) }
        captured?.cancel()
        _activeGenerations.update { it - identity }
    }

    fun cleanupAll() {
        jobs.values.forEach { it.cancel() }
        jobs.clear()
        _activeGenerations.value = emptyMap()
    }

    fun generationState(identity: ConversationIdentity): GenerationState =
        _activeGenerations.value[identity] ?: GenerationState.Idle

    private suspend fun onTerminal(identity: ConversationIdentity, state: GenerationState) {
        mutex.withLock {
            val current = jobs[identity]
            if (current != null && !current.isActive) {
                jobs.remove(identity)
                updateGeneration(identity, state)
            }
        }
    }

    private fun updateGeneration(identity: ConversationIdentity, state: GenerationState) {
        _activeGenerations.update { current ->
            current + (identity to state)
        }
    }
}
