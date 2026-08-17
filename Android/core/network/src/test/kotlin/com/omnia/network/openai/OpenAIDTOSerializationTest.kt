package com.omnia.network.openai

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OpenAIDTOSerializationTest {

    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun contentAsTextSerializesAsString() {
        val msg = OpenAIChatMessage(role = "user", content = OpenAIContent.Text("Hello"))
        val serialized = json.encodeToString(OpenAIChatMessage.serializer(), msg)
        assertTrue(serialized.contains("\"content\":\"Hello\""))
    }

    @Test
    fun contentAsTextDeserializesFromString() {
        val jsonStr = """{"role":"user","content":"Hello"}"""
        val msg = json.decodeFromString<OpenAIChatMessage>(jsonStr)
        assertTrue(msg.content is OpenAIContent.Text)
        assertEquals("Hello", (msg.content as OpenAIContent.Text).text)
    }

    @Test
    fun contentAsPartsDeserializesFromObjectArray() {
        val jsonStr = """{"role":"user","content":[{"type":"text","text":"Hi"}]}"""
        val msg = json.decodeFromString<OpenAIChatMessage>(jsonStr)
        assertTrue(msg.content is OpenAIContent.Parts)
        val parts = (msg.content as OpenAIContent.Parts).parts
        assertEquals(1, parts.size)
        assertEquals("text", parts[0].type)
        assertEquals("Hi", parts[0].text)
    }

    @Test
    fun contentAsImagePartsDeserializes() {
        val jsonStr = """{"role":"user","content":[{"type":"image_url","image_url":{"url":"data:image/png;base64,abc"}}]}"""
        val msg = json.decodeFromString<OpenAIChatMessage>(jsonStr)
        assertTrue(msg.content is OpenAIContent.Parts)
        val part = (msg.content as OpenAIContent.Parts).parts[0]
        assertEquals("image_url", part.type)
        assertNotNull(part.imageUrl)
        assertEquals("data:image/png;base64,abc", part.imageUrl!!.url)
    }

    @Test
    fun chatCompletionResponseDeserialization() {
        val jsonStr = """{"id":"chatcmpl-1","model":"gpt-4","choices":[{"index":0,"message":{"role":"assistant","content":"Hi"},"finish_reason":"stop"}]}"""
        val response = json.decodeFromString<OpenAIChatCompletionResponse>(jsonStr)
        assertEquals("chatcmpl-1", response.id)
        assertEquals("gpt-4", response.model)
        assertEquals(1, response.choices.size)
        assertEquals("Hi", response.choices[0].message.content)
        assertEquals("stop", response.choices[0].finishReason)
    }

    @Test
    fun chatCompletionChunkDeserialization() {
        val jsonStr = """{"id":"chatcmpl-1","model":"gpt-4","choices":[{"index":0,"delta":{"content":"Hello"},"finish_reason":null}]}"""
        val chunk = json.decodeFromString<OpenAIChatCompletionChunk>(jsonStr)
        assertEquals("chatcmpl-1", chunk.id)
        assertEquals("Hello", chunk.choices[0].delta.content)
    }

    @Test
    fun modelListResponseDeserialization() {
        val jsonStr = """{"data":[{"id":"gpt-4"},{"id":"gpt-3.5-turbo"}]}"""
        val response = json.decodeFromString<OpenAIModelListResponse>(jsonStr)
        assertEquals(2, response.data.size)
        assertEquals("gpt-4", response.data[0].id)
    }

    @Test
    fun usageDeserialization() {
        val jsonStr = """{"id":"1","model":"gpt-4","choices":[],"usage":{"prompt_tokens":10,"completion_tokens":20,"total_tokens":30}}"""
        val response = json.decodeFromString<OpenAIChatCompletionResponse>(jsonStr)
        assertNotNull(response.usage)
        assertEquals(10, response.usage!!.promptTokens)
        assertEquals(20, response.usage!!.completionTokens)
        assertEquals(30, response.usage!!.totalTokens)
    }
}
