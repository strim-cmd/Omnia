package com.omnia.domain

/**
 * Type-safe identity wrappers. Each domain entity kind gets its own wrapper
 * type to prevent accidental cross-entity ID misuse at compile time.
 *
 * Mirrors OmniaFoundation.Identifier<Kind> but uses String (not UUID) for
 * platform flexibility. Every identity carries a non-blank id invariant.
 */
@JvmInline
value class ProviderIdentity(val id: String) {
    init {
        require(id.isNotBlank()) { "ProviderIdentity id must not be blank" }
    }
}

@JvmInline
value class ConversationIdentity(val id: String) {
    init {
        require(id.isNotBlank()) { "ConversationIdentity id must not be blank" }
    }
}

@JvmInline
value class WorkspaceIdentity(val id: String) {
    init {
        require(id.isNotBlank()) { "WorkspaceIdentity id must not be blank" }
    }
}

@JvmInline
value class AttachmentIdentity(val id: String) {
    init {
        require(id.isNotBlank()) { "AttachmentIdentity id must not be blank" }
    }
}

@JvmInline
value class CapabilityRequestIdentity(val id: String) {
    init {
        require(id.isNotBlank()) { "CapabilityRequestIdentity id must not be blank" }
    }
}

/**
 * Opaque reference to a stored credential. Never holds the secret itself;
 * the credential storage backend resolves the reference.
 */
@JvmInline
value class CredentialReference(val id: String) {
    init {
        require(id.isNotBlank()) { "CredentialReference id must not be blank" }
    }
}

/**
 * Model name reference. A model is identified by its name string within a
 * provider. Distinct from identity types because models are not individually
 * addressable across provider boundaries.
 */
data class ModelReference(val name: String) {
    init {
        require(name.isNotBlank()) { "ModelReference name must not be blank" }
    }
}
