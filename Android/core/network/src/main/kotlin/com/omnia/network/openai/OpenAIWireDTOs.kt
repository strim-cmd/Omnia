package com.omnia.network.openai

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonContentPolymorphicSerializer
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

// --- Request DTOs ---

@Serializable
data class OpenAIChatCompletionRequest(
    val model: String,
    val messages: List<OpenAIChatMessage>,
    val stream: Boolean,
    val temperature: Double? = null,
    @SerialName("max_tokens") val maxTokens: Int? = null,
)

@Serializable
data class OpenAIChatMessage(
    val role: String,
    @Serializable(with = OpenAIContentSerializer::class)
    val content: OpenAIContent,
)

/**
 * Wire content: either a plain string or a list of typed parts.
 */
sealed class OpenAIContent {
    data class Text(val text: String) : OpenAIContent()
    data class Parts(val parts: List<OpenAIContentPart>) : OpenAIContent()
}

@Serializable
data class OpenAIContentPart(
    val type: String,
    val text: String? = null,
    @SerialName("image_url") val imageUrl: OpenAIImageURL? = null,
)

@Serializable
data class OpenAIImageURL(
    val url: String,
)

// --- Response DTOs ---

@Serializable
data class OpenAIChatCompletionResponse(
    val id: String,
    val model: String,
    val choices: List<OpenAIChatCompletionChoice>,
    val usage: OpenAIUsage? = null,
)

@Serializable
data class OpenAIChatCompletionChoice(
    val index: Int,
    val message: OpenAIChatCompletionResponseMessage,
    @SerialName("finish_reason") val finishReason: String? = null,
)

@Serializable
data class OpenAIChatCompletionResponseMessage(
    val role: String,
    val content: String? = null,
)

@Serializable
data class OpenAIUsage(
    @SerialName("prompt_tokens") val promptTokens: Int,
    @SerialName("completion_tokens") val completionTokens: Int,
    @SerialName("total_tokens") val totalTokens: Int,
)

// --- Streaming DTOs ---

@Serializable
data class OpenAIChatCompletionChunk(
    val id: String,
    val model: String,
    val choices: List<OpenAIChatCompletionChunkChoice>,
)

@Serializable
data class OpenAIChatCompletionChunkChoice(
    val index: Int,
    val delta: OpenAIChatCompletionChunkDelta,
    @SerialName("finish_reason") val finishReason: String? = null,
)

@Serializable
data class OpenAIChatCompletionChunkDelta(
    val role: String? = null,
    val content: String? = null,
)

// --- Model List DTOs ---

@Serializable
data class OpenAIModelListResponse(
    val data: List<OpenAIModelEntry>,
)

@Serializable
data class OpenAIModelEntry(
    val id: String,
)
