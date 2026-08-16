package com.omnia.feature.chat

/**
 * Immutable state of the Chat destination. The M1 shell only shows the empty
 * state; message bubbles, composer, streaming, and actions arrive in later
 * milestones.
 */
data class ChatUiState(
    val hasMessages: Boolean = false,
    val isComposerEnabled: Boolean = false,
    val title: String = "",
)
