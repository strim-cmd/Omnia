package com.omnia.domain

/**
 * Message role in a conversation. Tool role is a future extension point,
 * not part of v1.0.0.
 */
enum class MessageRole {
    system,
    user,
    assistant,
}

/**
 * Immutable value object representing a single message. No identity — the
 * Conversation aggregate owns its message history.
 */
data class Message(
    val role: MessageRole,
    val content: String,
    val attachments: List<MessageAttachment> = emptyList(),
)
