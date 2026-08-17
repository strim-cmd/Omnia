package com.omnia.data.provider

import com.omnia.common.SemanticVersion
import com.omnia.domain.*
import kotlinx.serialization.Serializable

@Serializable
internal data class ProviderCapabilitiesSchema(
    val capabilities: List<String> = emptyList(),
)

@Serializable
internal data class ProviderMetadataSchema(
    val displayName: String,
)

@Serializable
internal data class ProviderLimitsSchema(
    val maxRequestsPerMinute: Int? = null,
    val maxTokensPerMinute: Int? = null,
    val maxContextTokens: Int? = null,
)

@Serializable
internal data class SemanticVersionSchema(
    val major: Int,
    val minor: Int,
    val patch: Int,
)

@Serializable
internal data class ProviderConnectionSchema(
    val identity: String,
    val capabilities: ProviderCapabilitiesSchema = ProviderCapabilitiesSchema(),
    val metadata: ProviderMetadataSchema = ProviderMetadataSchema(displayName = ""),
    val limits: ProviderLimitsSchema = ProviderLimitsSchema(),
    val version: SemanticVersionSchema = SemanticVersionSchema(0, 0, 0),
)

@Serializable
internal data class ProviderDTOSchema(
    val schemaVersion: Int = 1,
    val connection: ProviderConnectionSchema,
    val state: String = "registered",
)

internal object ProviderSerializer {

    fun toDTO(provider: Provider): ProviderDTOSchema {
        val conn = provider.connection
        return ProviderDTOSchema(
            connection = ProviderConnectionSchema(
                identity = conn.identity.id,
                capabilities = ProviderCapabilitiesSchema(
                    capabilities = conn.capabilities.capabilities.map { it.serializedName }.sorted()
                ),
                metadata = ProviderMetadataSchema(displayName = conn.metadata.displayName),
                limits = ProviderLimitsSchema(
                    maxRequestsPerMinute = conn.limits.maxRequestsPerMinute,
                    maxTokensPerMinute = conn.limits.maxTokensPerMinute,
                    maxContextTokens = conn.limits.maxContextTokens,
                ),
                version = SemanticVersionSchema(
                    major = conn.version.major,
                    minor = conn.version.minor,
                    patch = conn.version.patch,
                ),
            ),
            state = provider.state.serializedName,
        )
    }

    fun fromDTO(dto: ProviderDTOSchema): Provider {
        val state = dto.state.toProviderState()
            ?: throw RepositoryError.StorageUnavailable

        val capabilities = dto.connection.capabilities.capabilities.map { name ->
            name.toCapability() ?: throw RepositoryError.StorageUnavailable
        }.toSet()

        val connection = ProviderConnection(
            identity = ProviderIdentity(dto.connection.identity),
            capabilities = ProviderCapabilities(capabilities),
            metadata = ProviderMetadata(displayName = dto.connection.metadata.displayName),
            limits = ProviderLimits(
                maxRequestsPerMinute = dto.connection.limits.maxRequestsPerMinute,
                maxTokensPerMinute = dto.connection.limits.maxTokensPerMinute,
                maxContextTokens = dto.connection.limits.maxContextTokens,
            ),
            version = SemanticVersion(
                major = dto.connection.version.major,
                minor = dto.connection.version.minor,
                patch = dto.connection.version.patch,
            ),
        )

        val provider = Provider.atState(connection, state)
        return provider
    }
}

private val ProviderState.serializedName: String
    get() = when (this) {
        ProviderState.registered -> "registered"
        ProviderState.validated -> "validated"
        ProviderState.initializing -> "initializing"
        ProviderState.ready -> "ready"
        ProviderState.unavailable -> "unavailable"
        ProviderState.disabled -> "disabled"
        ProviderState.removed -> "removed"
    }

private fun String.toProviderState(): ProviderState? = when (this) {
    "registered" -> ProviderState.registered
    "validated" -> ProviderState.validated
    "initializing" -> ProviderState.initializing
    "ready" -> ProviderState.ready
    "unavailable" -> ProviderState.unavailable
    "disabled" -> ProviderState.disabled
    "removed" -> ProviderState.removed
    else -> null
}

private val Capability.serializedName: String
    get() = when (this) {
        Capability.textGeneration -> "textGeneration"
        Capability.conversation -> "conversation"
        Capability.streaming -> "streaming"
        Capability.vision -> "vision"
        Capability.documentInput -> "documentInput"
        Capability.imageGeneration -> "imageGeneration"
        Capability.embeddings -> "embeddings"
        Capability.toolCalling -> "toolCalling"
        Capability.structuredOutput -> "structuredOutput"
        Capability.audio -> "audio"
        Capability.reasoning -> "reasoning"
    }

private fun String.toCapability(): Capability? = when (this) {
    "textGeneration" -> Capability.textGeneration
    "conversation" -> Capability.conversation
    "streaming" -> Capability.streaming
    "vision" -> Capability.vision
    "documentInput" -> Capability.documentInput
    "imageGeneration" -> Capability.imageGeneration
    "embeddings" -> Capability.embeddings
    "toolCalling" -> Capability.toolCalling
    "structuredOutput" -> Capability.structuredOutput
    "audio" -> Capability.audio
    "reasoning" -> Capability.reasoning
    else -> null
}
