package com.omnia.data

import com.omnia.domain.RepositoryError
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.Json
import java.io.File

internal class JsonDocumentStore(private val directory: File) {
    private val mutex = Mutex()
    private val json = Json {
        encodeDefaults = true
        prettyPrint = false
    }

    suspend fun saveJson(jsonText: String, key: String) = mutex.withLock {
        try {
            createDirectoryIfNeeded()
            val target = fileFor(key)
            val temp = File(directory, "${key}.${java.util.UUID.randomUUID()}.tmp")
            temp.writeText(jsonText, Charsets.UTF_8)
            if (!temp.renameTo(target)) {
                temp.delete()
                target.writeText(jsonText, Charsets.UTF_8)
            }
        } catch (e: Exception) {
            if (e is RepositoryError) throw e
            throw RepositoryError.StorageUnavailable
        }
    }

    suspend fun loadJson(key: String): String? = mutex.withLock {
        try {
            val file = fileFor(key)
            if (!file.exists()) return null
            file.readText(Charsets.UTF_8)
        } catch (e: Exception) {
            if (e is RepositoryError) throw e
            throw RepositoryError.StorageUnavailable
        }
    }

    suspend fun delete(key: String) = mutex.withLock {
        try {
            val file = fileFor(key)
            if (file.exists()) file.delete()
        } catch (e: Exception) {
            if (e is RepositoryError) throw e
            throw RepositoryError.StorageUnavailable
        }
    }

    suspend fun allKeys(): List<String> = mutex.withLock {
        try {
            if (!directory.exists()) return emptyList()
            directory.listFiles()
                ?.filter { it.isFile && it.extension == "json" }
                ?.map { it.nameWithoutExtension }
                ?.sorted()
                ?: emptyList()
        } catch (e: Exception) {
            if (e is RepositoryError) throw e
            throw RepositoryError.StorageUnavailable
        }
    }

    suspend fun loadJsonRecoveringInvalid(key: String): String? = mutex.withLock {
        try {
            val file = fileFor(key)
            if (!file.exists()) return null
            val text = file.readText(Charsets.UTF_8)
            // Validate it's parseable JSON by attempting to parse
            try {
                json.parseToJsonElement(text)
            } catch (_: Exception) {
                return null
            }
            text
        } catch (e: Exception) {
            if (e is RepositoryError) throw e
            throw RepositoryError.StorageUnavailable
        }
    }

    suspend fun deleteAll() = mutex.withLock {
        try {
            if (!directory.exists()) return@withLock
            directory.listFiles()
                ?.filter { it.isFile && it.extension == "json" }
                ?.forEach { it.delete() }
        } catch (e: Exception) {
            if (e is RepositoryError) throw e
            throw RepositoryError.StorageUnavailable
        }
    }

    private fun createDirectoryIfNeeded() {
        if (!directory.exists()) {
            directory.mkdirs()
        }
    }

    private fun fileFor(key: String): File {
        require(key.isNotEmpty()) { "key must not be empty" }
        require(!key.contains("/") && !key.contains("\\")) { "key must not contain path separators" }
        return File(directory, "$key.json")
    }
}
