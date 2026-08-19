package com.omnia.data.configuration

import com.omnia.domain.CredentialReference
import com.omnia.domain.ModelCapabilityProfile
import com.omnia.domain.ModelReference
import com.omnia.domain.ProviderAPIKind
import com.omnia.domain.ProviderIdentity
import com.omnia.domain.ProviderModelSelection

/**
 * Production type registration for all non-primitive domain types persisted
 * through [ConfigurationRepository]. Must be called ONCE before any
 * configuration read or write.
 *
 * Backward compatibility: decode functions tolerate data written by the
 * pre-bootstrap build which used [Any.toString] as the encode fallback.
 */
object ConfigurationBootstrap {

    @Volatile
    private var registered = false

    fun ensureRegistered() {
        if (registered) return
        synchronized(this) {
            if (registered) return
            registerAll()
            registered = true
        }
    }

    fun resetForTesting() {
        synchronized(this) {
            registered = false
        }
    }

    private fun registerAll() {
        ConfigurationSerializer.registerType(
            CredentialReference::class,
            encode = { it.id },
            decode = { decodeCredentialReference(it) },
        )
        ConfigurationSerializer.registerType(
            ProviderAPIKind::class,
            encode = { it.name },
            decode = { ProviderAPIKind.valueOf(it) },
        )
        ConfigurationSerializer.registerType(
            ProviderModelSelection::class,
            encode = { "${it.provider.id}|${it.model.name}" },
            decode = { decodeProviderModelSelection(it) },
        )
        ConfigurationSerializer.registerType(
            ModelCapabilityProfile::class,
            encode = { encodeModelCapabilityProfile(it) },
            decode = { decodeModelCapabilityProfile(it) },
        )
    }

    private fun decodeCredentialReference(raw: String): CredentialReference {
        val id = extractValueClassPayload(raw, "CredentialReference")
            ?: raw
        return CredentialReference(id)
    }

    private fun decodeProviderModelSelection(raw: String): ProviderModelSelection {
        val pipe = raw.indexOf('|')
        if (pipe > 0) {
            val providerId = raw.substring(0, pipe)
            val modelName = raw.substring(pipe + 1)
            return ProviderModelSelection(
                provider = ProviderIdentity(providerId),
                model = ModelReference(modelName),
            )
        }
        val providerId = extractField(raw, "provider=", "ProviderIdentity", "id")
        val modelName = extractField(raw, "model=", "ModelReference", "name")
        if (providerId != null && modelName != null) {
            return ProviderModelSelection(
                provider = ProviderIdentity(providerId),
                model = ModelReference(modelName),
            )
        }
        throw IllegalArgumentException("Unrecognized ProviderModelSelection payload: $raw")
    }

    private fun encodeModelCapabilityProfile(profile: ModelCapabilityProfile): String {
        val supported = profile.supported.joinToString(",") { it.name }
        val unsupported = profile.unsupported.joinToString(",") { it.name }
        return "S:$supported|U:$unsupported"
    }

    private fun decodeModelCapabilityProfile(raw: String): ModelCapabilityProfile {
        if (raw.startsWith("S:") && raw.contains("|U:")) {
            val sep = raw.indexOf("|U:")
            val supportedPart = raw.substring(2, sep)
            val unsupportedPart = raw.substring(sep + 3)
            val supported = parseCapabilitySet(supportedPart)
            val unsupported = parseCapabilitySet(unsupportedPart)
            return ModelCapabilityProfile(supported = supported, unsupported = unsupported)
        }
        val supported = extractSetField(raw, "supported")
        val unsupported = extractSetField(raw, "unsupported")
        return ModelCapabilityProfile(
            supported = supported,
            unsupported = unsupported,
        )
    }

    private fun parseCapabilitySet(raw: String): Set<com.omnia.domain.Capability> {
        if (raw.isBlank()) return emptySet()
        return raw.split(",").map { com.omnia.domain.Capability.valueOf(it.trim()) }.toSet()
    }

    private fun extractValueClassPayload(raw: String, className: String): String? {
        val prefix = "$className(id="
        if (raw.startsWith(prefix) && raw.endsWith(")")) {
            return raw.substring(prefix.length, raw.length - 1)
        }
        return null
    }

    private fun extractField(raw: String, fieldPrefix: String, typeName: String, fieldName: String): String? {
        val idx = raw.indexOf(fieldPrefix)
        if (idx < 0) return null
        val rest = raw.substring(idx + fieldPrefix.length)
        val innerPrefix = "$typeName($fieldName="
        if (rest.startsWith(innerPrefix)) {
            val start = innerPrefix.length
            val end = rest.indexOf(')', start)
            if (end > start) {
                return rest.substring(start, end)
            }
        }
        return null
    }

    private fun extractSetField(raw: String, fieldName: String): Set<com.omnia.domain.Capability> {
        val prefix = "$fieldName=["
        val idx = raw.indexOf(prefix)
        if (idx < 0) return emptySet()
        val start = idx + prefix.length
        val end = raw.indexOf(']', start)
        if (end <= start) return emptySet()
        val content = raw.substring(start, end)
        if (content.isBlank()) return emptySet()
        return content.split(",").map {
            com.omnia.domain.Capability.valueOf(it.trim())
        }.toSet()
    }
}
