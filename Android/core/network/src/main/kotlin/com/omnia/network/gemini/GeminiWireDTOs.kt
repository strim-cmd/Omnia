package com.omnia.network.gemini

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// --- Request DTOs ---

@Serializable
data class GeminiGenerateContentRequest(
    val contents: List<GeminiContent>,
    @SerialName("systemInstruction") val systemInstruction: GeminiSystemInstruction? = null,
)

@Serializable
data class GeminiSystemInstruction(
    val parts: List<GeminiPart>,
)

@Serializable
data class GeminiContent(
    val role: String,
    val parts: List<GeminiPart>,
)

@Serializable
data class GeminiPart(
    val text: String? = null,
    @SerialName("inlineData") val inlineData: GeminiInlineData? = null,
)

@Serializable
data class GeminiInlineData(
    val mimeType: String,
    val data: String,
)

// --- Response DTOs ---

@Serializable
data class GeminiGenerateContentResponse(
    val candidates: List<GeminiCandidate>? = null,
    @SerialName("usageMetadata") val usageMetadata: GeminiUsageMetadata? = null,
)

@Serializable
data class GeminiCandidate(
    val index: Int? = null,
    val content: GeminiResponseContent? = null,
    @SerialName("finishReason") val finishReason: String? = null,
)

@Serializable
data class GeminiResponseContent(
    val parts: List<GeminiPart>? = null,
    val role: String? = null,
)

@Serializable
data class GeminiUsageMetadata(
    @SerialName("promptTokenCount") val promptTokenCount: Int? = null,
    @SerialName("candidatesTokenCount") val candidatesTokenCount: Int? = null,
    @SerialName("totalTokenCount") val totalTokenCount: Int? = null,
)

// --- Model List DTOs ---

@Serializable
data class GeminiModelsResponse(
    val models: List<GeminiModelRecord>? = null,
)

@Serializable
data class GeminiModelRecord(
    val name: String? = null,
)
