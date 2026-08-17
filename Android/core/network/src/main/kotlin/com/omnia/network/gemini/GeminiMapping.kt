package com.omnia.network.gemini

import com.omnia.domain.AttachmentKind
import com.omnia.domain.AttachmentPayload
import com.omnia.domain.CapabilityError
import com.omnia.domain.CapabilityRequestIdentity
import com.omnia.domain.Message
import com.omnia.domain.MessageRole
import com.omnia.domain.ResolvedAttachment
import com.omnia.domain.StreamingUpdate
import com.omnia.network.transport.ProviderTransportError

/**
 * Maps between Domain capability types and Gemini wire DTOs.
 * Mirrors the OpenAI mapping but uses Gemini wire shapes:
 * - System messages become top-level `systemInstruction` (no system role in contents)
 * - User/assistant roles become "user"/"model"
 * - Image attachments become base64 `inlineData` (not data URLs)
 * - Streaming flag lives in the URL action, not in the request body
 */
object GeminiMapping {

    fun textGenerationRequest(
        model: String,
        prompt: String,
    ): GeminiGenerateContentRequest = GeminiGenerateContentRequest(
        contents = listOf(
            GeminiContent(role = "user", parts = listOf(GeminiPart(text = prompt)))
        ),
        systemInstruction = null,
    )

    fun conversationRequest(
        model: String,
        history: List<Message>,
        resolvedAttachments: List<ResolvedAttachment>,
    ): GeminiGenerateContentRequest = buildRequest(history, resolvedAttachments)

    fun streamingRequest(
        model: String,
        history: List<Message>,
        resolvedAttachments: List<ResolvedAttachment>,
    ): GeminiGenerateContentRequest = buildRequest(history, resolvedAttachments)

    fun textResponse(response: GeminiGenerateContentResponse): String =
        assistantText(response)

    fun conversationResponseMessage(response: GeminiGenerateContentResponse): Message =
        Message(role = MessageRole.assistant, content = assistantText(response))

    fun streamingUpdate(
        response: GeminiGenerateContentResponse,
        identity: CapabilityRequestIdentity,
    ): StreamingUpdate.ContentDelta? {
        val text = candidateText(response)
        if (text.isEmpty()) return null
        return StreamingUpdate.ContentDelta(identity = identity, content = text)
    }

    fun capabilityError(error: ProviderTransportError): CapabilityError =
        when (error) {
            is ProviderTransportError.invalidRequest -> CapabilityError.InvalidRequest
            is ProviderTransportError.invalidResponse -> CapabilityError.InvalidResponse
            is ProviderTransportError.networkFailure -> CapabilityError.NetworkUnavailable
            is ProviderTransportError.timedOut -> CapabilityError.TimedOut
            is ProviderTransportError.httpStatus -> when {
                error.code in listOf(400, 409, 413, 415, 422) -> CapabilityError.InvalidRequest
                error.code in listOf(401, 403) -> CapabilityError.Unauthorized
                error.code in listOf(404, 405, 410) -> CapabilityError.InvalidEndpoint
                error.code == 408 -> CapabilityError.TimedOut
                error.code == 429 -> CapabilityError.RateLimited
                error.code in 500..599 -> CapabilityError.ServerFailure
                else -> CapabilityError.ProviderUnavailable
            }
        }

    fun modelIds(response: GeminiModelsResponse): List<String> =
        (response.models ?: emptyList())
            .mapNotNull { it.name }
            .map { normalizedModelName(it) }
            .filter { it.isNotEmpty() }
            .distinct()
            .sorted()

    fun normalizedModelName(name: String): String {
        val prefix = "models/"
        val trimmed = name.trim()
        val stripped = if (trimmed.startsWith(prefix)) trimmed.drop(prefix.length) else trimmed
        return stripped
    }

    fun buildEndpointUrl(
        endpoint: String,
        model: String,
        streaming: Boolean,
    ): String {
        val base = endpoint.trimEnd('/')
        val modelPath = normalizedModelName(model)
        val action = if (streaming) "streamGenerateContent" else "generateContent"
        val suffix = if (streaming) "?alt=sse" else ""
        return "$base/models/$modelPath:$action$suffix"
    }

    private fun buildRequest(
        history: List<Message>,
        resolvedAttachments: List<ResolvedAttachment>,
    ): GeminiGenerateContentRequest {
        val resolvedMap = resolvedAttachments.associateBy { it.attachment.identity }
        val contents = mutableListOf<GeminiContent>()
        val systemParts = mutableListOf<GeminiPart>()

        for (message in history) {
            when (message.role) {
                MessageRole.system -> {
                    if (message.content.isNotEmpty()) {
                        systemParts.add(GeminiPart(text = message.content))
                    }
                }
                MessageRole.user, MessageRole.assistant -> {
                    val role = if (message.role == MessageRole.assistant) "model" else "user"
                    contents.add(
                        GeminiContent(
                            role = role,
                            parts = messageParts(message, resolvedMap)
                        )
                    )
                }
            }
        }

        return GeminiGenerateContentRequest(
            contents = contents,
            systemInstruction = if (systemParts.isNotEmpty()) {
                GeminiSystemInstruction(parts = systemParts)
            } else null
        )
    }

    private fun messageParts(
        message: Message,
        resolvedMap: Map<com.omnia.domain.AttachmentIdentity, ResolvedAttachment>,
    ): List<GeminiPart> {
        if (message.attachments.isEmpty()) {
            return listOf(GeminiPart(text = message.content))
        }

        val parts = mutableListOf<GeminiPart>()
        if (message.content.isNotEmpty()) {
            parts.add(GeminiPart(text = message.content))
        }

        for (attachment in message.attachments) {
            val resolved = resolvedMap[attachment.identity]
                ?: throw CapabilityError.InvalidRequest

            when (val payload = resolved.payload) {
                is AttachmentPayload.Image -> {
                    require(attachment.kind == AttachmentKind.image)
                    require(payload.mediaType == attachment.mediaType)
                    require(payload.mediaType.startsWith("image/"))
                    parts.add(
                        GeminiPart(
                            inlineData = GeminiInlineData(
                                mimeType = payload.mediaType,
                                data = java.util.Base64.getEncoder().encodeToString(payload.data)
                            )
                        )
                    )
                }
                is AttachmentPayload.ExtractedText -> {
                    require(attachment.kind == AttachmentKind.pdf || attachment.kind == AttachmentKind.plainText)
                    parts.add(
                        GeminiPart(
                            text = "[Attachment: ${safeName(attachment.fileName)} (${attachment.mediaType})]\n${payload.text}"
                        )
                    )
                }
            }
        }

        require(parts.isNotEmpty()) { "Message must have at least one content part" }
        return parts
    }

    private fun candidateText(response: GeminiGenerateContentResponse): String {
        val content = response.candidates?.firstOrNull()?.content ?: return ""
        val parts = content.parts ?: return ""
        return parts.mapNotNull { it.text }.joinToString("")
    }

    private fun assistantText(response: GeminiGenerateContentResponse): String {
        val text = candidateText(response)
        if (text.isEmpty()) throw CapabilityError.InvalidResponse
        return text
    }

    private fun safeName(fileName: String): String =
        fileName.replace("\\", "/").split("/").lastOrNull() ?: "Attachment"
}
