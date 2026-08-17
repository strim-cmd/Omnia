package com.omnia.domain

import com.omnia.common.SemanticVersion

/**
 * Provider API family. Unrecorded providers resolve to [openAICompatible]
 * (ARC-004: provider-specific concepts do not leak into Domain).
 */
enum class ProviderAPIKind {
    openAICompatible,
    gemini;

    companion object {
        val default = openAICompatible
    }
}

/**
 * Lifecycle states for a provider. Mirrors OmniaDomain.ProviderState exactly.
 */
enum class ProviderState {
    registered,
    validated,
    initializing,
    ready,
    unavailable,
    disabled,
    removed;

    companion object {
        /** Legal transition pairs — matching the iOS state machine. */
        val legalTransitions: Set<Pair<ProviderState, ProviderState>> = setOf(
            registered to validated,
            validated to initializing,
            initializing to ready,
            initializing to unavailable,
            ready to unavailable,
            unavailable to initializing,
            ready to disabled,
            unavailable to disabled,
            disabled to initializing,
            ready to removed,
            unavailable to removed,
            disabled to removed,
        )
    }
}

/**
 * Provider lifecycle errors. Carries typed diagnostic detail without leaking
 * transport or implementation specifics.
 */
sealed class ProviderLifecycleError(message: String) : Exception(message) {
    data class InvalidTransition(
        val from: ProviderState,
        val to: ProviderState,
    ) : ProviderLifecycleError("Invalid provider state transition from $from to $to")

    data class ProviderNotFound(val identity: ProviderIdentity) :
        ProviderLifecycleError("Provider '${identity.id}' not found")
}

/** Immutable value: declared capabilities of a provider. */
data class ProviderCapabilities(val capabilities: Set<Capability>) {
    fun contains(capability: Capability): Boolean = capability in capabilities
}

/** Immutable value: human-readable display name. */
data class ProviderMetadata(val displayName: String)

/** Immutable value: rate-limit and context constraints. */
data class ProviderLimits(
    val maxRequestsPerMinute: Int? = null,
    val maxTokensPerMinute: Int? = null,
    val maxContextTokens: Int? = null,
)

/**
 * Immutable connection declaration. Never holds credentials (ARC-004, ARC-005).
 */
data class ProviderConnection(
    val identity: ProviderIdentity,
    val capabilities: ProviderCapabilities,
    val metadata: ProviderMetadata,
    val limits: ProviderLimits,
    val version: SemanticVersion,
)

/**
 * Provider aggregate with lifecycle state machine. Thread-safe transition
 * enforcement; observers are a future extension point.
 */
class Provider private constructor(
    val connection: ProviderConnection,
    private var _state: ProviderState,
) {
    val identity: ProviderIdentity get() = connection.identity
    val state: ProviderState get() = _state

    constructor(connection: ProviderConnection) : this(connection, ProviderState.registered)

    fun canDeliver(capability: Capability): Boolean = connection.capabilities.contains(capability)

    /**
     * Attempts a lifecycle transition. Throws [ProviderLifecycleError.InvalidTransition]
     * if the transition is not in the legal set. Returns true on success.
     */
    @Throws(ProviderLifecycleError.InvalidTransition::class)
    fun transitionTo(newState: ProviderState): Boolean {
        val pair = _state to newState
        if (pair !in ProviderState.legalTransitions) {
            throw ProviderLifecycleError.InvalidTransition(from = _state, to = newState)
        }
        _state = newState
        return true
    }

    /**
     * Returns a new Provider with updated connection data, preserving
     * the current lifecycle state. Does not carry over any future observers.
     */
    fun replacingConnection(connection: ProviderConnection): Provider =
        Provider(connection, _state)

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is Provider) return false
        return identity == other.identity && _state == other._state && connection == other.connection
    }

    override fun hashCode(): Int = identity.hashCode()

    companion object {
        /** Restores a Provider at a specific state (for repository hydration). */
        fun atState(connection: ProviderConnection, state: ProviderState): Provider =
            Provider(connection, state)
    }
}
