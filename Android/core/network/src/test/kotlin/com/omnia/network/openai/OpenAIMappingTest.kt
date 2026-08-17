package com.omnia.network.openai

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

class OpenAIMappingTest {

    @Test
    fun textGenerationRequestMapsCorrectly() {
        val result = OpenAIMapping.textGenerationRequest("gpt-4", "Hello world")
        assertEquals("gpt-4", result.model)
        assertEquals(false, result.stream)
        assertEquals(1, result.messages.size)
        assertEquals("user", result.messages[0].role)
        assertTrue(result.messages[0].content is OpenAIContent.Text)
        assertEquals("Hello world", (result.messages[0].content as OpenAIContent.Text).text)
    }

    @Test
    fun conversationRequestMapsCorrectly() {
        val history = listOf(
            Message(role = MessageRole.system, content = "You are helpful"),
            Message(role = MessageRole.user, content = "Hi"),
        )
        val result = OpenAIMapping.conversationRequest("gpt-4", history, emptyList())
        assertEquals("gpt-4", result.model)
        assertEquals(false, result.stream)
        assertEquals(2, result.messages.size)
        assertEquals("system", result.messages[0].role)
        assertEquals("user", result.messages[1].role)
    }

    @Test
    fun streamingRequestMapsCorrectly() {
        val history = listOf(Message(role = MessageRole.user, content = "Hi"))
        val result = OpenAIMapping.streamingRequest("gpt-4", history, emptyList())
        assertEquals(true, result.stream)
    }

    @Test
    fun textResponseExtractsContent() {
        val response = OpenAIChatCompletionResponse(
            id = "1",
            model = "gpt-4",
            choices = listOf(
                OpenAIChatCompletionChoice(
                    index = 0,
                    message = OpenAIChatCompletionResponseMessage(
                        role = "assistant",
                        content = "Hello there"
                    )
                )
            )
        )
        assertEquals("Hello there", OpenAIMapping.textResponse(response))
    }

    @Test(expected = CapabilityError.InvalidResponse::class)
    fun textResponseThrowsOnEmptyChoices() {
        val response = OpenAIChatCompletionResponse(
            id = "1",
            model = "gpt-4",
            choices = emptyList()
        )
        OpenAIMapping.textResponse(response)
    }

    @Test(expected = CapabilityError.InvalidResponse::class)
    fun textResponseThrowsOnNullContent() {
        val response = OpenAIChatCompletionResponse(
            id = "1",
            model = "gpt-4",
            choices = listOf(
                OpenAIChatCompletionChoice(
                    index = 0,
                    message = OpenAIChatCompletionResponseMessage(role = "assistant", content = null)
                )
            )
        )
        OpenAIMapping.textResponse(response)
    }

    @Test
    fun conversationResponseMessageMapsCorrectly() {
        val response = OpenAIChatCompletionResponse(
            id = "1",
            model = "gpt-4",
            choices = listOf(
                OpenAIChatCompletionChoice(
                    index = 0,
                    message = OpenAIChatCompletionResponseMessage(
                        role = "assistant",
                        content = "I am helpful"
                    )
                )
            )
        )
        val msg = OpenAIMapping.conversationResponseMessage(response)
        assertEquals(MessageRole.assistant, msg.role)
        assertEquals("I am helpful", msg.content)
    }

    @Test
    fun streamingUpdateExtractsContent() {
        val chunk = OpenAIChatCompletionChunk(
            id = "1",
            model = "gpt-4",
            choices = listOf(
                OpenAIChatCompletionChunkChoice(
                    index = 0,
                    delta = OpenAIChatCompletionChunkDelta(content = "Hello")
                )
            )
        )
        val identity = CapabilityRequestIdentity(id = "req-1")
        val update = OpenAIMapping.streamingUpdate(chunk, identity)
        assertNotNull(update)
        assertEquals("Hello", update!!.content)
        assertEquals("req-1", update.identity.id)
    }

    @Test
    fun streamingUpdateReturnsNullForEmptyContent() {
        val chunk = OpenAIChatCompletionChunk(
            id = "1",
            model = "gpt-4",
            choices = listOf(
                OpenAIChatCompletionChunkChoice(
                    index = 0,
                    delta = OpenAIChatCompletionChunkDelta(content = null)
                )
            )
        )
        val identity = CapabilityRequestIdentity(id = "req-1")
        assertNull(OpenAIMapping.streamingUpdate(chunk, identity))
    }

    @Test
    fun streamingUpdateReturnsNullForEmptyChoices() {
        val chunk = OpenAIChatCompletionChunk(id = "1", model = "gpt-4", choices = emptyList())
        val identity = CapabilityRequestIdentity(id = "req-1")
        assertNull(OpenAIMapping.streamingUpdate(chunk, identity))
    }

    @Test
    fun capabilityErrorInvalidRequest() {
        val result = OpenAIMapping.capabilityError(ProviderTransportError.invalidRequest)
        assertEquals(CapabilityError.InvalidRequest, result)
    }

    @Test
    fun capabilityErrorInvalidResponse() {
        val result = OpenAIMapping.capabilityError(ProviderTransportError.invalidResponse)
        assertEquals(CapabilityError.InvalidResponse, result)
    }

    @Test
    fun capabilityErrorNetworkFailure() {
        val result = OpenAIMapping.capabilityError(ProviderTransportError.networkFailure)
        assertEquals(CapabilityError.NetworkUnavailable, result)
    }

    @Test
    fun capabilityErrorTimedOut() {
        val result = OpenAIMapping.capabilityError(ProviderTransportError.timedOut)
        assertEquals(CapabilityError.TimedOut, result)
    }

    @Test
    fun capabilityErrorHttp401() {
        val result = OpenAIMapping.capabilityError(ProviderTransportError.httpStatus(401))
        assertEquals(CapabilityError.Unauthorized, result)
    }

    @Test
    fun capabilityErrorHttp403() {
        val result = OpenAIMapping.capabilityError(ProviderTransportError.httpStatus(403))
        assertEquals(CapabilityError.Unauthorized, result)
    }

    @Test
    fun capabilityErrorHttp404() {
        val result = OpenAIMapping.capabilityError(ProviderTransportError.httpStatus(404))
        assertEquals(CapabilityError.InvalidEndpoint, result)
    }

    @Test
    fun capabilityErrorHttp429() {
        val result = OpenAIMapping.capabilityError(ProviderTransportError.httpStatus(429))
        assertEquals(CapabilityError.RateLimited, result)
    }

    @Test
    fun capabilityErrorHttp500() {
        val result = OpenAIMapping.capabilityError(ProviderTransportError.httpStatus(500))
        assertEquals(CapabilityError.ServerFailure, result)
    }

    @Test
    fun capabilityErrorHttp400() {
        val result = OpenAIMapping.capabilityError(ProviderTransportError.httpStatus(400))
        assertEquals(CapabilityError.InvalidRequest, result)
    }

    @Test
    fun capabilityErrorHttp503() {
        val result = OpenAIMapping.capabilityError(ProviderTransportError.httpStatus(503))
        assertEquals(CapabilityError.ServerFailure, result)
    }

    @Test
    fun modelIdsFromResponse() {
        val response = OpenAIModelListResponse(
            data = listOf(
                OpenAIModelEntry(id = "gpt-4"),
                OpenAIModelEntry(id = "gpt-3.5-turbo"),
                OpenAIModelEntry(id = "gpt-4"),
                OpenAIModelEntry(id = ""),
            )
        )
        val ids = OpenAIMapping.modelIds(response)
        assertEquals(listOf("gpt-3.5-turbo", "gpt-4"), ids)
    }

    @Test
    fun modelIdsTrimsWhitespace() {
        val response = OpenAIModelListResponse(
            data = listOf(
                OpenAIModelEntry(id = "  gpt-4  "),
            )
        )
        val ids = OpenAIMapping.modelIds(response)
        assertEquals(listOf("gpt-4"), ids)
    }
}
