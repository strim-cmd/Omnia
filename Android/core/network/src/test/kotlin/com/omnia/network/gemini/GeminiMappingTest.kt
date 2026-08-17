package com.omnia.network.gemini

import com.omnia.domain.CapabilityError
import com.omnia.domain.CapabilityRequestIdentity
import com.omnia.domain.Message
import com.omnia.domain.MessageRole
import com.omnia.domain.ModelReference
import com.omnia.domain.StreamingUpdate
import com.omnia.network.transport.ProviderTransportError
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class GeminiMappingTest {

    @Test
    fun textGenerationRequestMapsCorrectly() {
        val result = GeminiMapping.textGenerationRequest("gemini-pro", "Hello world")
        assertEquals(1, result.contents.size)
        assertEquals("user", result.contents[0].role)
        assertEquals(1, result.contents[0].parts.size)
        assertEquals("Hello world", result.contents[0].parts[0].text)
        assertNull(result.systemInstruction)
    }

    @Test
    fun conversationRequestWithSystemMessage() {
        val history = listOf(
            Message(role = MessageRole.system, content = "You are helpful"),
            Message(role = MessageRole.user, content = "Hi"),
            Message(role = MessageRole.assistant, content = "Hello!"),
            Message(role = MessageRole.user, content = "How are you?"),
        )
        val result = GeminiMapping.conversationRequest("gemini-pro", history, emptyList())

        assertNotNull(result.systemInstruction)
        assertEquals(1, result.systemInstruction!!.parts.size)
        assertEquals("You are helpful", result.systemInstruction!!.parts[0].text)

        assertEquals(3, result.contents.size)
        assertEquals("user", result.contents[0].role)
        assertEquals("model", result.contents[1].role)
        assertEquals("user", result.contents[2].role)
    }

    @Test
    fun conversationRequestWithoutSystemMessage() {
        val history = listOf(
            Message(role = MessageRole.user, content = "Hi"),
        )
        val result = GeminiMapping.conversationRequest("gemini-pro", history, emptyList())
        assertNull(result.systemInstruction)
        assertEquals(1, result.contents.size)
    }

    @Test
    fun streamingRequestSameAsConversation() {
        val history = listOf(
            Message(role = MessageRole.user, content = "Hi"),
        )
        val streaming = GeminiMapping.streamingRequest("gemini-pro", history, emptyList())
        val conversation = GeminiMapping.conversationRequest("gemini-pro", history, emptyList())
        assertEquals(conversation, streaming)
    }

    @Test
    fun textResponseExtractsContent() {
        val response = GeminiGenerateContentResponse(
            candidates = listOf(
                GeminiCandidate(
                    content = GeminiResponseContent(
                        parts = listOf(GeminiPart(text = "Hello there"))
                    )
                )
            )
        )
        assertEquals("Hello there", GeminiMapping.textResponse(response))
    }

    @Test
    fun textResponseJoinsMultipleParts() {
        val response = GeminiGenerateContentResponse(
            candidates = listOf(
                GeminiCandidate(
                    content = GeminiResponseContent(
                        parts = listOf(
                            GeminiPart(text = "Hello "),
                            GeminiPart(text = "world")
                        )
                    )
                )
            )
        )
        assertEquals("Hello world", GeminiMapping.textResponse(response))
    }

    @Test(expected = CapabilityError.InvalidResponse::class)
    fun textResponseThrowsOnEmptyCandidates() {
        GeminiMapping.textResponse(GeminiGenerateContentResponse(candidates = emptyList()))
    }

    @Test(expected = CapabilityError.InvalidResponse::class)
    fun textResponseThrowsOnNullText() {
        GeminiMapping.textResponse(
            GeminiGenerateContentResponse(
                candidates = listOf(
                    GeminiCandidate(content = GeminiResponseContent(parts = listOf(GeminiPart())))
                )
            )
        )
    }

    @Test
    fun conversationResponseMessage() {
        val response = GeminiGenerateContentResponse(
            candidates = listOf(
                GeminiCandidate(
                    content = GeminiResponseContent(
                        parts = listOf(GeminiPart(text = "I am helpful"))
                    )
                )
            )
        )
        val msg = GeminiMapping.conversationResponseMessage(response)
        assertEquals(MessageRole.assistant, msg.role)
        assertEquals("I am helpful", msg.content)
    }

    @Test
    fun streamingUpdateExtractsText() {
        val response = GeminiGenerateContentResponse(
            candidates = listOf(
                GeminiCandidate(
                    content = GeminiResponseContent(
                        parts = listOf(GeminiPart(text = "Hello"))
                    )
                )
            )
        )
        val identity = CapabilityRequestIdentity(id = "req-1")
        val update = GeminiMapping.streamingUpdate(response, identity)
        assertNotNull(update)
        assertEquals("Hello", update!!.content)
    }

    @Test
    fun streamingUpdateReturnsNullForEmptyText() {
        val response = GeminiGenerateContentResponse(
            candidates = listOf(
                GeminiCandidate(content = GeminiResponseContent(parts = listOf(GeminiPart())))
            )
        )
        assertNull(GeminiMapping.streamingUpdate(response, CapabilityRequestIdentity(id = "r1")))
    }

    @Test
    fun streamingUpdateReturnsNullForNoCandidates() {
        val response = GeminiGenerateContentResponse(candidates = null)
        assertNull(GeminiMapping.streamingUpdate(response, CapabilityRequestIdentity(id = "r1")))
    }

    @Test
    fun capabilityErrorMappingMatches() {
        assertEquals(CapabilityError.InvalidRequest, GeminiMapping.capabilityError(ProviderTransportError.invalidRequest))
        assertEquals(CapabilityError.InvalidResponse, GeminiMapping.capabilityError(ProviderTransportError.invalidResponse))
        assertEquals(CapabilityError.NetworkUnavailable, GeminiMapping.capabilityError(ProviderTransportError.networkFailure))
        assertEquals(CapabilityError.TimedOut, GeminiMapping.capabilityError(ProviderTransportError.timedOut))
        assertEquals(CapabilityError.Unauthorized, GeminiMapping.capabilityError(ProviderTransportError.httpStatus(401)))
        assertEquals(CapabilityError.RateLimited, GeminiMapping.capabilityError(ProviderTransportError.httpStatus(429)))
        assertEquals(CapabilityError.ServerFailure, GeminiMapping.capabilityError(ProviderTransportError.httpStatus(500)))
    }

    @Test
    fun normalizedModelName() {
        assertEquals("gemini-pro", GeminiMapping.normalizedModelName("models/gemini-pro"))
        assertEquals("gemini-pro", GeminiMapping.normalizedModelName("gemini-pro"))
        assertEquals("gemini-pro", GeminiMapping.normalizedModelName("  models/gemini-pro  "))
    }

    @Test
    fun modelIdsFromResponse() {
        val response = GeminiModelsResponse(
            models = listOf(
                GeminiModelRecord(name = "models/gemini-pro"),
                GeminiModelRecord(name = "models/gemini-flash"),
                GeminiModelRecord(name = "models/gemini-pro"),
                GeminiModelRecord(name = null),
            )
        )
        val ids = GeminiMapping.modelIds(response)
        assertEquals(listOf("gemini-flash", "gemini-pro"), ids)
    }

    @Test
    fun buildEndpointUrlNonStreaming() {
        val url = GeminiMapping.buildEndpointUrl("https://generativelanguage.googleapis.com/v1", "gemini-pro", streaming = false)
        assertEquals("https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent", url)
    }

    @Test
    fun buildEndpointUrlStreaming() {
        val url = GeminiMapping.buildEndpointUrl("https://generativelanguage.googleapis.com/v1", "models/gemini-pro", streaming = true)
        assertEquals("https://generativelanguage.googleapis.com/v1/models/gemini-pro:streamGenerateContent?alt=sse", url)
    }

    @Test
    fun imageAttachmentMapsToInlineData() {
        val attachment = com.omnia.domain.MessageAttachment(
            identity = com.omnia.domain.AttachmentIdentity(id = "att-1"),
            kind = com.omnia.domain.AttachmentKind.image,
            fileName = "photo.jpg",
            mediaType = "image/jpeg",
            byteCount = 2,
            storageKey = "key-1",
        )
        val resolved = com.omnia.domain.ResolvedAttachment(
            attachment = attachment,
            payload = com.omnia.domain.AttachmentPayload.Image(
                mediaType = "image/jpeg",
                data = byteArrayOf(0xFF.toByte(), 0xD8.toByte()),
            ),
        )
        val history = listOf(
            Message(role = MessageRole.user, content = "Describe this", attachments = listOf(attachment)),
        )
        val request = GeminiMapping.conversationRequest("gemini-pro", history, listOf(resolved))

        val parts = request.contents[0].parts
        assertEquals(2, parts.size)
        assertEquals("Describe this", parts[0].text)
        assertNotNull(parts[1].inlineData)
        assertEquals("image/jpeg", parts[1].inlineData!!.mimeType)
        assertTrue(parts[1].inlineData!!.data.isNotEmpty())
    }

    @Test
    fun pdfAttachmentMapsToTextPart() {
        val attachment = com.omnia.domain.MessageAttachment(
            identity = com.omnia.domain.AttachmentIdentity(id = "att-2"),
            kind = com.omnia.domain.AttachmentKind.pdf,
            fileName = "report.pdf",
            mediaType = "application/pdf",
            byteCount = 100,
            storageKey = "key-2",
        )
        val resolved = com.omnia.domain.ResolvedAttachment(
            attachment = attachment,
            payload = com.omnia.domain.AttachmentPayload.ExtractedText(text = "PDF text content"),
        )
        val history = listOf(
            Message(role = MessageRole.user, content = "Summarize", attachments = listOf(attachment)),
        )
        val request = GeminiMapping.conversationRequest("gemini-pro", history, listOf(resolved))

        val parts = request.contents[0].parts
        assertEquals(2, parts.size)
        assertEquals("Summarize", parts[0].text)
        assertNull(parts[1].inlineData)
        assertTrue(parts[1].text!!.contains("PDF text content"))
        assertTrue(parts[1].text!!.contains("report.pdf"))
    }

    @Test
    fun systemMessagesNeverAppearInContents() {
        val history = listOf(
            Message(role = MessageRole.system, content = "Be helpful"),
            Message(role = MessageRole.user, content = "Hi"),
        )
        val request = GeminiMapping.conversationRequest("gemini-pro", history, emptyList())

        assertNotNull(request.systemInstruction)
        assertEquals(1, request.contents.size)
        assertEquals("user", request.contents[0].role)
    }

    @Test
    fun capabilityErrorHttp408() {
        assertEquals(CapabilityError.TimedOut, GeminiMapping.capabilityError(ProviderTransportError.httpStatus(408)))
    }

    @Test
    fun capabilityErrorHttp404() {
        assertEquals(CapabilityError.InvalidEndpoint, GeminiMapping.capabilityError(ProviderTransportError.httpStatus(404)))
    }

    @Test
    fun capabilityErrorOtherStatus() {
        assertEquals(CapabilityError.ProviderUnavailable, GeminiMapping.capabilityError(ProviderTransportError.httpStatus(418)))
    }
}
