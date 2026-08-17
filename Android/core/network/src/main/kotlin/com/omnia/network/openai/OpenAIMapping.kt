package com.omnia.network.openai

import com.omnia.domain.AttachmentKind
import com.omnia.domain.AttachmentPayload
import com.omnia.domain.CapabilityError
import com.omnia.domain.Message
import com.omnia.domain.MessageRole
import com.omnia.domain.ResolvedAttachment
import com.omnia.domain.StreamingUpdate
import com.omnia.domain.CapabilityRequestIdentity
import com.omnia.network.transport.ProviderTransportError

/**
 * Maps between Domain capability types and OpenAI wire DTOs.
 * Stateless and deterministic: translation depends only on the values
 * translated. No provider-specific shapes cross the boundary.
 */
object OpenAIMapping {

    fun textGenerationRequest(
        model: String,
        prompt: String,
    ): OpenAIChatCompletionRequest = OpenAIChatCompletionRequest(
        model = model,
        messages = listOf(
            OpenAIChatMessage(role = "user", content = OpenAIContent.Text(prompt))
        ),
        stream = false,
    )

    fun conversationRequest(
        model: String,
        history: List<Message>,
        resolvedAttachments: List<ResolvedAttachment>,
    ): OpenAIChatCompletionRequest = OpenAIChatCompletionRequest(
        model = model,
        messages = chatMessages(history, resolvedAttachments),
        stream = false,
    )

    fun streamingRequest(
        model: String,
        history: List<Message>,
        resolvedAttachments: List<ResolvedAttachment>,
    ): OpenAIChatCompletionRequest = OpenAIChatCompletionRequest(
        model = model,
        messages = chatMessages(history, resolvedAttachments),
        stream = true,
    )

    fun textResponse(response: OpenAIChatCompletionResponse): String =
        assistantContent(response)

    fun conversationResponseMessage(response: OpenAIChatCompletionResponse): Message =
        Message(role = MessageRole.assistant, content = assistantContent(response))

    fun streamingUpdate(
        chunk: OpenAIChatCompletionChunk,
        identity: CapabilityRequestIdentity,
    ): StreamingUpdate.ContentDelta? {
        val content = chunk.choices.firstOrNull()?.delta?.content ?: return null
        return StreamingUpdate.ContentDelta(identity = identity, content = content)
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

    fun modelIds(response: OpenAIModelListResponse): List<String> =
        response.data
            .map { it.id.trim() }
            .filter { it.isNotEmpty() }
            .distinct()
            .sorted()

    private fun assistantContent(response: OpenAIChatCompletionResponse): String =
        response.choices.firstOrNull()?.message?.content
            ?: throw CapabilityError.InvalidResponse

    private fun chatMessages(
        history: List<Message>,
        resolvedAttachments: List<ResolvedAttachment>,
    ): List<OpenAIChatMessage> {
        val resolvedMap = resolvedAttachments.associateBy { it.attachment.identity }

        return history.map { message ->
            if (message.attachments.isEmpty()) {
                OpenAIChatMessage(
                    role = wireRole(message.role),
                    content = OpenAIContent.Text(message.content)
                )
            } else {
                val parts = mutableListOf<OpenAIContentPart>()
                if (message.content.isNotEmpty()) {
                    parts.add(OpenAIContentPart(type = "text", text = message.content))
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
                                OpenAIContentPart(
                                    type = "image_url",
                                    imageUrl = OpenAIImageURL(
                                        url = "data:${payload.mediaType};base64,${java.util.Base64.getEncoder().encodeToString(payload.data)}"
                                    )
                                )
                            )
                        }
                        is AttachmentPayload.ExtractedText -> {
                            require(attachment.kind == AttachmentKind.pdf || attachment.kind == AttachmentKind.plainText)
                            parts.add(
                                OpenAIContentPart(
                                    type = "text",
                                    text = "[Attachment: ${safeName(attachment.fileName)} (${attachment.mediaType})]\n${payload.text}"
                                )
                            )
                        }
                    }
                }
                require(parts.isNotEmpty()) { "Message must have at least one content part" }
                OpenAIChatMessage(
                    role = wireRole(message.role),
                    content = OpenAIContent.Parts(parts)
                )
            }
        }
    }

    private fun wireRole(role: MessageRole): String = when (role) {
        MessageRole.system -> "system"
        MessageRole.user -> "user"
        MessageRole.assistant -> "assistant"
    }

    private fun safeName(fileName: String): String =
        fileName.replace("\\", "/").split("/").lastOrNull() ?: "Attachment"
}
