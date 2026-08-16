package com.omnia.domain

/**
 * Selection vocabulary, mirroring the iOS runtime truth (G-01): a message is
 * sent with a (provider, model) pair, never the stale
 * `userSelection`/`workspacePreference`/`capabilityPreference` vocabulary.
 *
 * This is the minimal domain seed for the M1 foundation; providers, model
 * discovery, and repositories are introduced in later milestones.
 */
data class ProviderIdentity(val id: String)

data class ModelIdentity(val id: String)

data class ProviderModelSelection(
    val provider: ProviderIdentity,
    val model: ModelIdentity,
) {
    init {
        require(provider.id.isNotBlank()) { "provider id must not be blank" }
        require(model.id.isNotBlank()) { "model id must not be blank" }
    }
}
