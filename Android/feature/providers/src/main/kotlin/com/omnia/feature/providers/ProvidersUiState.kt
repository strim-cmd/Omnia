package com.omnia.feature.providers

/**
 * Immutable state of the Providers destination. The M1 shell shows the empty
 * list; connection, credentials, and model discovery arrive in later
 * milestones.
 */
data class ProvidersUiState(
    val providers: List<ProviderListItem> = emptyList(),
    val isAddProviderEnabled: Boolean = false,
) {
    val isEmpty: Boolean get() = providers.isEmpty()
}

data class ProviderListItem(
    val id: String,
    val name: String,
)
