package com.omnia.data.configuration

import com.omnia.data.JsonDocumentStore
import com.omnia.domain.ConfigurationKey
import com.omnia.domain.ConfigurationLevel
import com.omnia.domain.ConfigurationRepository
import com.omnia.domain.RepositoryError
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import java.io.File

class FileConfigurationRepository internal constructor(
    private val store: JsonDocumentStore,
) : ConfigurationRepository {

    constructor(directory: File) : this(JsonDocumentStore(directory))

    private val json = Json { encodeDefaults = true; prettyPrint = false }

    fun <T : Any> registerType(
        type: kotlin.reflect.KClass<T>,
        encode: (T) -> String,
        decode: (String) -> T,
    ) {
        ConfigurationSerializer.registerType(type, encode, decode)
    }

    override suspend fun <T : Any> store(value: T, key: ConfigurationKey<T>, level: ConfigurationLevel) {
        val documentKey = documentKey(level, key.name)
        val payload = ConfigurationSerializer.encodeEntry(value)
        val entry = ConfigurationEntrySchema(
            key = key.name,
            level = level.serializedName,
            payload = payload,
            typeName = ConfigurationSerializer.typeNameFor(value),
        )
        store.saveJson(
            json.encodeToString(ConfigurationEntrySchema.serializer(), entry),
            documentKey,
        )
    }

    override suspend fun <T : Any> value(key: ConfigurationKey<T>, level: ConfigurationLevel): T? {
        val documentKey = documentKey(level, key.name)
        val text = store.loadJson(documentKey) ?: return null
        return try {
            val entry = json.decodeFromString(ConfigurationEntrySchema.serializer(), text)
            val decoded: Any? = ConfigurationSerializer.decodeEntry(entry.payload, entry.typeName)
            if (decoded == null) null else uncheckedCast(decoded)
        } catch (e: Exception) {
            if (e is RepositoryError) throw e
            throw RepositoryError.StorageUnavailable
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun <T : Any> uncheckedCast(value: Any): T = value as T

    override suspend fun <T : Any> remove(key: ConfigurationKey<T>, level: ConfigurationLevel) {
        store.delete(documentKey(level, key.name))
    }

    suspend fun removeAll() {
        store.deleteAll()
    }

    private fun documentKey(level: ConfigurationLevel, keyName: String): String {
        return "${level.serializedName}-$keyName"
    }
}

private val ConfigurationLevel.serializedName: String
    get() = when (this) {
        ConfigurationLevel.providerSettings -> "providerSettings"
        ConfigurationLevel.workspaceOverride -> "workspaceOverride"
        ConfigurationLevel.globalDefault -> "globalDefault"
        ConfigurationLevel.capabilityPreference -> "capabilityPreference"
    }
