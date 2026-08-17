package com.omnia.network.openai

import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Custom serializer for OpenAI wire content format.
 * `content` is either:
 * - A plain string: `"Hello"`
 * - An array of parts: `[{"type":"text","text":"Hello"}, ...]`
 */
object OpenAIContentSerializer : KSerializer<OpenAIContent> {
    override val descriptor: SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("OpenAIContent")

    override fun deserialize(decoder: Decoder): OpenAIContent {
        val element = (decoder as JsonDecoder).decodeJsonElement()
        return when (element) {
            is JsonPrimitive -> OpenAIContent.Text(element.contentOrNull ?: "")
            is JsonArray -> {
                val parts = element.map { el ->
                    val obj = el.jsonObject
                    val type = obj["type"]?.jsonPrimitive?.contentOrNull ?: ""
                    when (type) {
                        "text" -> OpenAIContentPart(
                            type = "text",
                            text = obj["text"]?.jsonPrimitive?.contentOrNull
                        )
                        "image_url" -> {
                            val imageObj = obj["image_url"]?.jsonObject
                            val url = imageObj?.get("url")?.jsonPrimitive?.contentOrNull ?: ""
                            OpenAIContentPart(
                                type = "image_url",
                                imageUrl = OpenAIImageURL(url = url)
                            )
                        }
                        else -> OpenAIContentPart(type = type)
                    }
                }
                OpenAIContent.Parts(parts)
            }
            else -> OpenAIContent.Text("")
        }
    }

    override fun serialize(encoder: Encoder, value: OpenAIContent) {
        when (value) {
            is OpenAIContent.Text -> encoder.encodeString(value.text)
            is OpenAIContent.Parts -> {
                val jsonArray = kotlinx.serialization.json.buildJsonArray {
                    for (part in value.parts) {
                        add(kotlinx.serialization.json.buildJsonObject {
                            put("type", JsonPrimitive(part.type))
                            when (part.type) {
                                "text" -> put("text", JsonPrimitive(part.text ?: ""))
                                "image_url" -> put(
                                    "image_url",
                                    kotlinx.serialization.json.buildJsonObject {
                                        put("url", JsonPrimitive(part.imageUrl?.url ?: ""))
                                    }
                                )
                            }
                        })
                    }
                }
                (encoder as JsonEncoder).encodeJsonElement(jsonArray)
            }
        }
    }
}
