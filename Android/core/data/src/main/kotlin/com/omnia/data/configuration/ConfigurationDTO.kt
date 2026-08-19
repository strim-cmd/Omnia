package com.omnia.data.configuration

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*

@Serializable
internal data class ConfigurationEntrySchema(
    val key: String,
    val level: String,
    val payload: String,
    val typeName: String = "kotlin.String",
)

@Serializable
internal data class ConfigurationDTOSchema(
    val schemaVersion: Int = 1,
    val entries: List<ConfigurationEntrySchema> = emptyList(),
)

object ConfigurationSerializer {
    private val prettyJson = Json { encodeDefaults = true; prettyPrint = false }

    private val typeRegistry = mutableMapOf<kotlin.reflect.KClass<*>, Pair<(Any) -> String, (String) -> Any>>()

    fun <T : Any> registerType(
        type: kotlin.reflect.KClass<T>,
        encode: (T) -> String,
        decode: (String) -> T,
    ) {
        @Suppress("UNCHECKED_CAST")
        typeRegistry[type] = (encode as (Any) -> String) to (decode as (String) -> Any)
    }

    fun encodeEntry(value: Any): String {
        val converter = typeRegistry[value::class]
        val rawString = if (converter != null) {
            converter.first(value)
        } else {
            value.toString()
        }
        return prettyJson.encodeToString(JsonPrimitive(rawString))
    }

    fun typeNameFor(value: Any): String {
        return typeRegistry.keys.find { it == value::class }?.qualifiedName ?: value::class.qualifiedName ?: "kotlin.Any"
    }

    fun decodeEntry(payload: String, typeName: String): Any? {
        val element = prettyJson.parseToJsonElement(payload)
        val rawString = (element as JsonPrimitive).content
        val resolvedType = typeRegistry.keys.find { it.qualifiedName == typeName }
        val converter = if (resolvedType != null) typeRegistry[resolvedType] else null
        return if (converter != null) {
            converter.second(rawString)
        } else {
            when (typeName) {
                "kotlin.String" -> rawString
                "kotlin.Int" -> rawString.toIntOrNull()
                "kotlin.Boolean" -> rawString.toBooleanStrictOrNull()
                "kotlin.Long" -> rawString.toLongOrNull()
                "kotlin.Double" -> rawString.toDoubleOrNull()
                else -> throw IllegalStateException(
                    "Type '$typeName' is not registered in ConfigurationSerializer. " +
                        "Call ConfigurationBootstrap.ensureRegistered() before reading configuration."
                )
            }
        }
    }
}
