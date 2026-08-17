package com.omnia.data.provider

import com.omnia.data.JsonDocumentStore
import com.omnia.domain.Provider
import com.omnia.domain.ProviderIdentity
import com.omnia.domain.ProviderRepository
import com.omnia.domain.RepositoryError
import kotlinx.serialization.json.Json
import java.io.File

class FileProviderRepository internal constructor(
    private val store: JsonDocumentStore,
) : ProviderRepository {

    constructor(directory: File) : this(JsonDocumentStore(directory))

    private val json = Json { encodeDefaults = true; prettyPrint = false }

    override suspend fun save(provider: Provider) {
        val dto = ProviderSerializer.toDTO(provider)
        store.saveJson(json.encodeToString(ProviderDTOSchema.serializer(), dto), provider.identity.id)
    }

    override suspend fun provider(identity: ProviderIdentity): Provider? {
        val text = store.loadJson(identity.id) ?: return null
        return try {
            val dto = json.decodeFromString(ProviderDTOSchema.serializer(), text)
            ProviderSerializer.fromDTO(dto)
        } catch (e: Exception) {
            if (e is RepositoryError) throw e
            throw RepositoryError.StorageUnavailable
        }
    }

    override suspend fun allProviders(): List<Provider> {
        val keys = store.allKeys()
        val providers = mutableListOf<Provider>()
        for (key in keys) {
            val text = store.loadJsonRecoveringInvalid(key) ?: continue
            try {
                val dto = json.decodeFromString(ProviderDTOSchema.serializer(), text)
                providers.add(ProviderSerializer.fromDTO(dto))
            } catch (_: Exception) {
                continue
            }
        }
        return providers
    }

    override suspend fun delete(identity: ProviderIdentity) {
        store.delete(identity.id)
    }

    suspend fun removeAll() {
        store.deleteAll()
    }
}
